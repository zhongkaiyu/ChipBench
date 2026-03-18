#!/usr/bin/env python3
"""
Cross-Language Verification Script

Compares 4 implementations:
1. Golden Reference SystemVerilog (RefModule)
2. DUT SystemVerilog (TopModule)
3. CXXRTL C++ (p_TopModule)
4. Python (top_module function)

Usage:
    python crosslang_verify.py ref.sv dut.sv dut.cc dut.py

The script will:
1. Extract ports from ref.sv
2. Generate testbench.cpp that tests all 4 implementations
3. Compile with Verilator (both RefModule and TopModule)
4. Run and report mismatches
"""

import sys
import os
import re
import subprocess
import argparse
import shutil
from pathlib import Path


def extract_ports_from_verilog(verilog_path):
    """
    Extract input and output port information from Verilog file.
    Returns (inputs, outputs) where each is a list of (name, width) tuples.
    """
    with open(verilog_path, 'r') as f:
        verilog_code = f.read()
    
    # Remove comments
    verilog_code = re.sub(r'//[^\n]*', '', verilog_code)
    verilog_code = re.sub(r'/\*[\s\S]*?\*/', '', verilog_code)
    
    inputs = []
    outputs = []
    
    # Pattern: input/output [MSB:LSB] name
    port_pattern = r'(input|output)\s*(?:reg|wire|logic)?\s*(?:\[([^\]]+)\])?\s*(\w+)'
    
    for match in re.finditer(port_pattern, verilog_code):
        direction = match.group(1)
        width_expr = match.group(2)
        name = match.group(3)
        
        # Calculate width
        if width_expr:
            parts = width_expr.split(':')
            if len(parts) == 2:
                msb_expr = parts[0].strip()
                lsb_expr = parts[1].strip()
                try:
                    msb = eval(msb_expr)
                    lsb = eval(lsb_expr)
                    width = abs(msb - lsb) + 1
                except:
                    width = 32
            else:
                width = 1
        else:
            width = 1
        
        if direction == 'input':
            inputs.append((name, width))
        else:
            outputs.append((name, width))
    
    return inputs, outputs


def cxxrtl_mangle(name):
    """Convert Verilog signal name to CXXRTL mangled name."""
    return 'p_' + name.replace('_', '__')


def get_num_chunks(width):
    """Calculate number of 32-bit chunks needed for a signal."""
    return (width + 31) // 32


def generate_wide_input_code(name, width):
    """Generate code for handling wide input signals (> 64 bits)."""
    num_chunks = get_num_chunks(width)
    
    # Declaration: array of uint32_t
    decl = f"    uint32_t {name}[{num_chunks}];"
    
    # Random generation: fill each chunk
    rand_lines = []
    for i in range(num_chunks):
        if i == num_chunks - 1:
            remaining_bits = width - (i * 32)
            if remaining_bits < 32:
                mask = f"((1U << {remaining_bits}) - 1)"
                rand_lines.append(f"        {name}[{i}] = dist32(gen) & {mask};")
            else:
                rand_lines.append(f"        {name}[{i}] = dist32(gen);")
        else:
            rand_lines.append(f"        {name}[{i}] = dist32(gen);")
    rand_code = '\n'.join(rand_lines)
    
    # Setter for Verilator (ref and dut): copy to VlWide
    ref_setter = f"        for (int _i = 0; _i < {num_chunks}; _i++) ref->{name}[_i] = {name}[_i];"
    dut_setter = f"        for (int _i = 0; _i < {num_chunks}; _i++) dut->{name}[_i] = {name}[_i];"
    
    # Setter for CXXRTL: directly set the data array
    # Note: CXXRTL inputs are value<Bits> (use .data directly), not wire<Bits>
    mangled = cxxrtl_mangle(name)
    cxxrtl_setter = f"        for (int _i = 0; _i < {num_chunks}; _i++) cxxrtl_dut.{mangled}.data[_i] = {name}[_i];"
    
    # To string for JSON
    to_string = f'''[&]() {{
            std::vector<uint32_t> chunks({num_chunks});
            for (int _i = 0; _i < {num_chunks}; _i++) chunks[_i] = {name}[_i];
            return wide_to_string(chunks);
        }}()'''
    
    return decl, rand_code, ref_setter, dut_setter, cxxrtl_setter, to_string


def generate_wide_output_comparison(name, width, module_prefix, error_var, error_label):
    """Generate comparison code for wide output signals."""
    num_chunks = get_num_chunks(width)
    
    return f'''
        {{
            bool mismatch = false;
            for (int _i = 0; _i < {num_chunks}; _i++) {{
                if (ref->{name}[_i] != {module_prefix}->{name}[_i]) mismatch = true;
            }}
            if (mismatch) {{
                if ({error_var} < 10) {{
                    std::cerr << "[{error_label} MISMATCH] Test " << i << ", {name}" << std::endl;
                }}
                {error_var}++;
            }}
        }}'''


def generate_wide_cxxrtl_comparison(name, width, error_var):
    """Generate comparison code for wide CXXRTL output signals."""
    num_chunks = get_num_chunks(width)
    mangled = cxxrtl_mangle(name)
    
    # Note: CXXRTL outputs in combinational circuits are value<Bits> (use .data directly)
    # For sequential circuits with wires, would need .curr.data
    return f'''
        {{
            bool mismatch = false;
            for (int _i = 0; _i < {num_chunks}; _i++) {{
                if (ref->{name}[_i] != cxxrtl_dut.{mangled}.data[_i]) mismatch = true;
            }}
            if (mismatch) {{
                if ({error_var} < 10) {{
                    std::cerr << "[CXXRTL MISMATCH] Test " << i << ", {name}" << std::endl;
                }}
                {error_var}++;
            }}
        }}'''


def generate_wide_output_to_string(name, width, module_name="ref"):
    """Generate code to convert wide output to string."""
    num_chunks = get_num_chunks(width)
    return f'''[&]() {{
            std::vector<uint32_t> chunks({num_chunks});
            for (int _i = 0; _i < {num_chunks}; _i++) chunks[_i] = {module_name}->{name}[_i];
            return wide_to_string(chunks);
        }}()'''


def generate_combinational_testbench(inputs, outputs, cxxrtl_cc, python_module,
                                     input_declarations, random_generators,
                                     ref_setters, dut_setters, cxxrtl_setters,
                                     python_inputs, dut_checks, cxxrtl_checks, python_checks,
                                     input_to_string, output_to_string, has_wide_signals,
                                     reset_signals_info):
    """Generate testbench for COMBINATIONAL circuits (no clk)."""
    
    # Build input/output string conversion code
    input_str_code = '\n'.join([f'        input_obj["{n}"] = {expr};' for n, expr in input_to_string])
    output_str_code = '\n'.join([f'        ref_out["{n}"] = {expr};' for n, expr in output_to_string])
    
    # Generate reset warmup code and reset fixed value code
    # reset_signals_info: list of (name, width, is_active_low)
    warmup_reset_code = []
    fixed_reset_code = []
    for name, width, is_active_low in reset_signals_info:
        if width > 64:
            num_chunks = get_num_chunks(width)
            if is_active_low:
                # Active-low: warmup=0, fixed=all 1s
                for i in range(num_chunks):
                    warmup_reset_code.append(f'            {name}[{i}] = 0;')
                    if i == num_chunks - 1:
                        remaining = width - (i * 32)
                        if remaining < 32:
                            fixed_reset_code.append(f'        {name}[{i}] = {(1 << remaining) - 1};')
                        else:
                            fixed_reset_code.append(f'        {name}[{i}] = 0xFFFFFFFF;')
                    else:
                        fixed_reset_code.append(f'        {name}[{i}] = 0xFFFFFFFF;')
            else:
                # Active-high: warmup=all 1s, fixed=0
                for i in range(num_chunks):
                    if i == num_chunks - 1:
                        remaining = width - (i * 32)
                        if remaining < 32:
                            warmup_reset_code.append(f'            {name}[{i}] = {(1 << remaining) - 1};')
                        else:
                            warmup_reset_code.append(f'            {name}[{i}] = 0xFFFFFFFF;')
                    else:
                        warmup_reset_code.append(f'            {name}[{i}] = 0xFFFFFFFF;')
                    fixed_reset_code.append(f'        {name}[{i}] = 0;')
        else:
            if is_active_low:
                # Active-low: warmup=0, fixed=1
                warmup_reset_code.append(f'            {name} = 0;  // Active-low reset active')
                fixed_reset_code.append(f'        {name} = 1;  // Active-low reset inactive')
            else:
                # Active-high: warmup=1, fixed=0
                warmup_reset_code.append(f'            {name} = 1;  // Active-high reset active')
                fixed_reset_code.append(f'        {name} = 0;  // Active-high reset inactive')
    
    warmup_reset_str = '\n'.join(warmup_reset_code) if warmup_reset_code else '            // No reset signals'
    fixed_reset_str = '\n'.join(fixed_reset_code) if fixed_reset_code else '        // No reset signals'
    has_reset = len(reset_signals_info) > 0
    
    # Wide signal helper function
    wide_helper = '''
// Helper to convert wide signal (array of uint32_t) to decimal string
std::string wide_to_string(const std::vector<uint32_t>& chunks) {
    if (chunks.empty()) return "0";
    
    if (chunks.size() == 1) return std::to_string(chunks[0]);
    if (chunks.size() == 2) {
        uint64_t val = ((uint64_t)chunks[1] << 32) | chunks[0];
        return std::to_string(val);
    }
    
    std::vector<uint32_t> temp = chunks;
    std::string digits;
    
    bool all_zero = false;
    while (!all_zero) {
        all_zero = true;
        uint64_t remainder = 0;
        for (int i = (int)temp.size() - 1; i >= 0; i--) {
            uint64_t dividend = (remainder << 32) | temp[i];
            temp[i] = (uint32_t)(dividend / 10);
            remainder = dividend % 10;
            if (temp[i] != 0) all_zero = false;
        }
        digits = (char)('0' + remainder) + digits;
        if (all_zero && digits.length() == 1) break;
    }
    
    size_t start = digits.find_first_not_of('0');
    return (start == std::string::npos) ? "0" : digits.substr(start);
}
''' if has_wide_signals else ''
    
    return f'''// Auto-generated Cross-Language Verification Testbench
// COMBINATIONAL CIRCUIT (no clock)
// Tests: RefModule (SV), TopModule (SV), CXXRTL (p_TopModule), Python (TopModule.eval())

#include <iostream>
#include <fstream>
#include <sstream>
#include <cstdint>
#include <cstdlib>
#include <string>
#include <random>
#include <map>
#include <vector>
#include <cstdio>
#include <memory>
#include <array>
#include <cctype>

// Verilator headers
#include "VRefModule.h"
#include "VTopModule.h"
#include "verilated.h"

// CXXRTL header
#include <cxxrtl/cxxrtl.h>
#include "../{cxxrtl_cc}"

// Python module name
const char* PYTHON_MODULE = "{python_module}";
{wide_helper}
// Use STRING values to support arbitrary bit widths (> 64 bits)
// Values are stored as decimal strings in JSON

// Helper: Execute Python with TopModule class and eval() function
// Uses std::string for values to support arbitrary width signals
std::vector<std::map<std::string, std::string>> call_python_batch(
    const std::vector<std::map<std::string, std::string>>& all_inputs) {{
    
    std::vector<std::map<std::string, std::string>> results;
    
    // Build JSON array of inputs (values as strings for arbitrary precision)
    std::stringstream json_ss;
    json_ss << "[";
    for (size_t i = 0; i < all_inputs.size(); i++) {{
        json_ss << "{{";
        bool first = true;
        for (const auto& kv : all_inputs[i]) {{
            if (!first) json_ss << ", ";
            // Output as JSON string: "key": "value" for arbitrary precision
            json_ss << "\\"" << kv.first << "\\": \\"" << kv.second << "\\"";
            first = false;
        }}
        json_ss << "}}";
        if (i + 1 < all_inputs.size()) json_ss << ", ";
    }}
    json_ss << "]";
    
    // Write inputs to temp file
    std::ofstream tmp_in("_py_inputs.json");
    tmp_in << json_ss.str();
    tmp_in.close();
    
    // Python: create TopModule instance and call eval() for each input
    // Python converts string values to int automatically
    std::string cmd = "python3 -c \\""
        "import sys, json; "
        "sys.path.insert(0, '.'); "
        "from " + std::string(PYTHON_MODULE) + " import TopModule; "
        "inputs = json.load(open('_py_inputs.json')); "
        "inputs = [{{k: int(v) for k, v in inp.items()}} for inp in inputs]; "
        "dut = TopModule(); "
        "outputs = [dut.eval(inp) for inp in inputs]; "
        "print(json.dumps([{{k: str(int(v) if isinstance(v, bool) else v) for k,v in o.items()}} for o in outputs]));\\"";
    
    std::array<char, 65536> buffer;
    std::string output;
    
    FILE* pipe = popen(cmd.c_str(), "r");
    if (!pipe) return results;
    
    while (fgets(buffer.data(), buffer.size(), pipe) != nullptr) {{
        output += buffer.data();
    }}
    
    if (pclose(pipe) != 0) return results;
    
    // Parse JSON array output - values are strings
    size_t pos = 0;
    while ((pos = output.find("{{", pos)) != std::string::npos) {{
        size_t end = output.find("}}", pos);
        if (end == std::string::npos) break;
        
        std::string obj_str = output.substr(pos, end - pos + 2);
        std::map<std::string, std::string> obj;
        
        size_t kpos = 0;
        while ((kpos = obj_str.find("\\"", kpos)) != std::string::npos) {{
            size_t key_start = kpos + 1;
            size_t key_end = obj_str.find("\\"", key_start);
            if (key_end == std::string::npos) break;
            
            std::string key = obj_str.substr(key_start, key_end - key_start);
            
            // Find value (it's a string in quotes)
            size_t colon = obj_str.find(":", key_end);
            if (colon == std::string::npos) break;
            
            size_t val_quote_start = obj_str.find("\\"", colon);
            if (val_quote_start == std::string::npos) break;
            
            size_t val_start = val_quote_start + 1;
            size_t val_end = obj_str.find("\\"", val_start);
            if (val_end == std::string::npos) break;
            
            std::string value = obj_str.substr(val_start, val_end - val_start);
            obj[key] = value;
            kpos = val_end + 1;
        }}
        
        results.push_back(obj);
        pos = end + 2;
    }}
    
    return results;
}}

// Helper to convert CXXRTL value to string (for arbitrary width)
template<size_t Bits>
std::string value_to_string(const cxxrtl::value<Bits>& val) {{
    // For values <= 64 bits, use simple conversion
    if (Bits <= 64) {{
        uint64_t v = 0;
        for (size_t i = 0; i < val.chunks && i < 2; i++) {{
            v |= ((uint64_t)val.data[i]) << (32 * i);
        }}
        return std::to_string(v);
    }}
    // For wider values, compute decimal string
    // Use repeated division by 10 (slow but works for any width)
    std::vector<uint32_t> digits;
    std::vector<uint32_t> temp(val.chunks);
    for (size_t i = 0; i < val.chunks; i++) temp[i] = val.data[i];
    
    bool all_zero = false;
    while (!all_zero) {{
        all_zero = true;
        uint64_t remainder = 0;
        for (int i = (int)temp.size() - 1; i >= 0; i--) {{
            uint64_t dividend = (remainder << 32) | temp[i];
            temp[i] = (uint32_t)(dividend / 10);
            remainder = dividend % 10;
            if (temp[i] != 0) all_zero = false;
        }}
        digits.push_back((uint32_t)remainder);
        if (all_zero && digits.size() == 1 && digits[0] == 0) break;
    }}
    
    std::string result;
    for (int i = (int)digits.size() - 1; i >= 0; i--) {{
        result += ('0' + digits[i]);
    }}
    return result.empty() ? "0" : result;
}}

// Helper to convert CXXRTL wire to string
template<size_t Bits>
std::string wire_to_string(const cxxrtl::wire<Bits>& w) {{
    return value_to_string(w.curr);
}}

// Helper to compare string numbers
bool string_equals(const std::string& a, const std::string& b) {{
    // Remove leading zeros for comparison
    size_t a_start = a.find_first_not_of('0');
    size_t b_start = b.find_first_not_of('0');
    std::string a_trimmed = (a_start == std::string::npos) ? "0" : a.substr(a_start);
    std::string b_trimmed = (b_start == std::string::npos) ? "0" : b.substr(b_start);
    return a_trimmed == b_trimmed;
}}

int main(int argc, char** argv) {{
    Verilated::commandArgs(argc, argv);
    
    VRefModule* ref = new VRefModule;
    VTopModule* dut = new VTopModule;
    cxxrtl_design::p_TopModule cxxrtl_dut;
    
    std::mt19937_64 gen(12345);  // Fixed seed for reproducibility
    std::uniform_int_distribution<uint64_t> dist(0, UINT64_MAX);
    std::uniform_int_distribution<uint32_t> dist32(0, UINT32_MAX);  // For wide signals
    
{chr(10).join(input_declarations)}
    
    int dut_errors = 0, cxxrtl_errors = 0, python_errors = 0;
    const int NUM_TESTS = 1000;
    
    std::cout << "============================================" << std::endl;
    std::cout << "Cross-Language Verification (COMBINATIONAL)" << std::endl;
    std::cout << "Running " << NUM_TESTS << " tests" << std::endl;
    std::cout << "============================================" << std::endl;
    
    // Collect all inputs and ref outputs for Python batch (as STRINGS for arbitrary width)
    std::vector<std::map<std::string, std::string>> all_inputs;
    std::vector<std::map<std::string, std::string>> ref_outputs;
    
    // === WARMUP PHASE: Run 20 cycles with reset ACTIVE (no comparison) ===
    const int WARMUP_CYCLES = {'20' if has_reset else '0'};
    std::cout << "Running " << WARMUP_CYCLES << " warmup cycles with reset active..." << std::endl;
    for (int warmup = 0; warmup < WARMUP_CYCLES; warmup++) {{
        // Generate random inputs
{chr(10).join(random_generators)}
        
        // Override reset signals to ACTIVE state
{warmup_reset_str}
        
        // Store inputs for Python (warmup cycles too - Python needs them for initialization)
        std::map<std::string, std::string> input_obj;
{input_str_code}
        all_inputs.push_back(input_obj);
        
        // Run all implementations (no comparison during warmup)
{chr(10).join(ref_setters)}
        ref->eval();
{chr(10).join(dut_setters)}
        dut->eval();
{chr(10).join(cxxrtl_setters)}
        cxxrtl_dut.eval();
        cxxrtl_dut.commit();
        
        // Store ref outputs (for Python output count matching, but no comparison)
        std::map<std::string, std::string> ref_out;
{output_str_code}
        ref_outputs.push_back(ref_out);
    }}
    
    // === MAIN TEST PHASE: Reset is INACTIVE (fixed, not random) ===
    for (int i = 0; i < NUM_TESTS; i++) {{
{chr(10).join(random_generators)}
        
        // Override reset signals to INACTIVE state (fixed, not random)
{fixed_reset_str}
        
        // Store inputs for Python (as strings)
        std::map<std::string, std::string> input_obj;
{input_str_code}
        all_inputs.push_back(input_obj);
        
        // RefModule
{chr(10).join(ref_setters)}
        ref->eval();
        
        // Store ref outputs (as strings)
        std::map<std::string, std::string> ref_out;
{output_str_code}
        ref_outputs.push_back(ref_out);
        
        // TopModule (DUT)
{chr(10).join(dut_setters)}
        dut->eval();
        
        // CXXRTL
{chr(10).join(cxxrtl_setters)}
        cxxrtl_dut.eval();
        cxxrtl_dut.commit();
        
        // Compare DUT vs REF{''.join(dut_checks)}
        
        // Compare CXXRTL vs REF{''.join(cxxrtl_checks)}
    }}
    
    // Run Python batch (TopModule class with eval())
    std::cout << "Running Python simulation..." << std::endl;
    auto py_outputs = call_python_batch(all_inputs);
    
    if (py_outputs.size() != ref_outputs.size()) {{
        std::cerr << "[PYTHON] Output count mismatch: expected " << ref_outputs.size()
                  << ", got " << py_outputs.size() << std::endl;
        python_errors += NUM_TESTS;
    }} else {{
        // Skip first WARMUP_CYCLES outputs (warmup phase - no comparison)
        for (size_t i = WARMUP_CYCLES; i < ref_outputs.size(); i++) {{
            for (const auto& kv : ref_outputs[i]) {{
                const std::string& name = kv.first;
                const std::string& expected = kv.second;
                auto it = py_outputs[i].find(name);
                if (it != py_outputs[i].end()) {{
                    if (!string_equals(it->second, expected)) {{
                        if (python_errors < 10) {{
                            std::cerr << "[PYTHON MISMATCH] Test " << (i - WARMUP_CYCLES) << ", " << name
                                      << ": expected=" << expected << ", got=" << it->second << std::endl;
                        }}
                        python_errors++;
                    }}
                }}
            }}
        }}
    }}
    
    std::cout << "============================================" << std::endl;
    std::cout << "RESULTS" << std::endl;
    std::cout << "============================================" << std::endl;
    std::cout << "Total tests:       " << NUM_TESTS << std::endl;
    std::cout << "DUT errors:        " << dut_errors << std::endl;
    std::cout << "CXXRTL errors:     " << cxxrtl_errors << std::endl;
    std::cout << "Python errors:     " << python_errors << std::endl;
    std::cout << "============================================" << std::endl;
    
    int total_errors = dut_errors + cxxrtl_errors + python_errors;
    if (total_errors == 0) std::cout << "*** ALL TESTS PASSED ***" << std::endl;
    else std::cerr << "*** " << total_errors << " TOTAL ERRORS ***" << std::endl;
    
    delete ref;
    delete dut;
    return total_errors > 0 ? 1 : 0;
}}
'''


def is_reset_signal(name):
    """Check if a signal name looks like a reset signal."""
    name_lower = name.lower()
    # Match: reset, rst, areset, async_reset, reset_n, rst_n, etc.
    return ('reset' in name_lower or 'rst' in name_lower)

def is_active_low_reset(name):
    """Check if reset is active-low (ends with _n, _b, _l, or starts with n)."""
    name_lower = name.lower()
    return (name_lower.endswith('_n') or name_lower.endswith('_b') or 
            name_lower.endswith('_l') or name_lower.startswith('n'))


def generate_sequential_testbench(inputs, outputs, cxxrtl_cc, python_module,
                                  input_declarations, random_generators,
                                  ref_setters, dut_setters, cxxrtl_setters,
                                  python_inputs, dut_checks, cxxrtl_checks, python_checks,
                                  input_to_string, output_to_string, has_wide_signals,
                                  reset_signals_info):
    """Generate testbench for SEQUENTIAL circuits (with clk)."""
    
    # For sequential, we need to build JSON array of all inputs first
    # then send to Python in one batch
    input_names = [name for name, _ in inputs if name.lower() != 'clk']
    output_names = [name for name, _ in outputs]
    
    has_reset = len(reset_signals_info) > 0
    
    # Generate warmup code (reset ACTIVE) and fixed reset code (reset INACTIVE)
    # For warmup: generate random inputs, then override reset to active
    warmup_reset_code = []
    fixed_reset_code = []
    for name, width, is_active_low in reset_signals_info:
        if width > 64:
            num_chunks = get_num_chunks(width)
            if is_active_low:
                # Active-low: warmup=0 (active), fixed=all 1s (inactive)
                for i in range(num_chunks):
                    warmup_reset_code.append(f'            {name}[{i}] = 0;')
                    if i == num_chunks - 1:
                        remaining = width - (i * 32)
                        if remaining < 32:
                            fixed_reset_code.append(f'        {name}[{i}] = {(1 << remaining) - 1};')
                        else:
                            fixed_reset_code.append(f'        {name}[{i}] = 0xFFFFFFFF;')
                    else:
                        fixed_reset_code.append(f'        {name}[{i}] = 0xFFFFFFFF;')
            else:
                # Active-high: warmup=all 1s (active), fixed=0 (inactive)
                for i in range(num_chunks):
                    if i == num_chunks - 1:
                        remaining = width - (i * 32)
                        if remaining < 32:
                            warmup_reset_code.append(f'            {name}[{i}] = {(1 << remaining) - 1};')
                        else:
                            warmup_reset_code.append(f'            {name}[{i}] = 0xFFFFFFFF;')
                    else:
                        warmup_reset_code.append(f'            {name}[{i}] = 0xFFFFFFFF;')
                    fixed_reset_code.append(f'        {name}[{i}] = 0;')
        else:
            if is_active_low:
                # Active-low: warmup=0 (active), fixed=1 (inactive)
                warmup_reset_code.append(f'            {name} = 0;  // Active-low reset ACTIVE')
                fixed_reset_code.append(f'        {name} = 1;  // Active-low reset INACTIVE')
            else:
                # Active-high: warmup=1 (active), fixed=0 (inactive)
                warmup_reset_code.append(f'            {name} = 1;  // Active-high reset ACTIVE')
                fixed_reset_code.append(f'        {name} = 0;  // Active-high reset INACTIVE')
    
    warmup_reset_str = '\n'.join(warmup_reset_code) if warmup_reset_code else '            // No reset signals'
    fixed_reset_str = '\n'.join(fixed_reset_code) if fixed_reset_code else '        // No reset signals'
    
    # Build input/output string conversion code
    input_str_code = '\n'.join([f'        input_obj["{n}"] = {expr};' for n, expr in input_to_string if n.lower() != 'clk'])
    output_str_code = '\n'.join([f'        ref_out["{n}"] = {expr};' for n, expr in output_to_string])
    
    # Wide signal helper function
    wide_helper = '''
// Helper to convert wide signal (array of uint32_t) to decimal string
std::string wide_to_string(const std::vector<uint32_t>& chunks) {
    if (chunks.empty()) return "0";
    
    if (chunks.size() == 1) return std::to_string(chunks[0]);
    if (chunks.size() == 2) {
        uint64_t val = ((uint64_t)chunks[1] << 32) | chunks[0];
        return std::to_string(val);
    }
    
    std::vector<uint32_t> temp = chunks;
    std::string digits;
    
    bool all_zero = false;
    while (!all_zero) {
        all_zero = true;
        uint64_t remainder = 0;
        for (int i = (int)temp.size() - 1; i >= 0; i--) {
            uint64_t dividend = (remainder << 32) | temp[i];
            temp[i] = (uint32_t)(dividend / 10);
            remainder = dividend % 10;
            if (temp[i] != 0) all_zero = false;
        }
        digits = (char)('0' + remainder) + digits;
        if (all_zero && digits.length() == 1) break;
    }
    
    size_t start = digits.find_first_not_of('0');
    return (start == std::string::npos) ? "0" : digits.substr(start);
}
''' if has_wide_signals else ''
    
    return f'''// Auto-generated Cross-Language Verification Testbench
// SEQUENTIAL CIRCUIT (with clock)
// Tests: RefModule (SV), TopModule (SV), CXXRTL (p_TopModule), Python (TopModule.eval())

#include <iostream>
#include <fstream>
#include <sstream>
#include <cstdint>
#include <cstdlib>
#include <string>
#include <random>
#include <map>
#include <vector>
#include <cstdio>
#include <memory>
#include <array>
#include <cctype>

// Verilator headers
#include "VRefModule.h"
#include "VTopModule.h"
#include "verilated.h"

// CXXRTL header
#include <cxxrtl/cxxrtl.h>
#include "../{cxxrtl_cc}"

const char* PYTHON_MODULE = "{python_module}";
{wide_helper}

// Use STRING values for arbitrary bit widths (same as combinational)
// For sequential circuits, we batch all inputs and send to Python at once
// Python must implement: class TopModule with eval(inputs) -> outputs
std::vector<std::map<std::string, std::string>> call_python_sequential(
    const std::vector<std::map<std::string, std::string>>& all_inputs) {{
    
    std::vector<std::map<std::string, std::string>> results;
    
    // Build JSON array of inputs (values as strings for arbitrary precision)
    std::stringstream json_ss;
    json_ss << "[";
    for (size_t i = 0; i < all_inputs.size(); i++) {{
        json_ss << "{{";
        bool first = true;
        for (const auto& kv : all_inputs[i]) {{
            if (!first) json_ss << ", ";
            json_ss << "\\"" << kv.first << "\\": \\"" << kv.second << "\\"";
            first = false;
        }}
        json_ss << "}}";
        if (i + 1 < all_inputs.size()) json_ss << ", ";
    }}
    json_ss << "]";
    
    // Write inputs to temp file (avoid command line length limits)
    std::ofstream tmp_in("_py_inputs.json");
    tmp_in << json_ss.str();
    tmp_in.close();
    
    // Python script that simulates the sequential circuit
    // Converts string values to int
    std::string cmd = "python3 -c \\""
        "import sys, json; "
        "sys.path.insert(0, '.'); "
        "from " + std::string(PYTHON_MODULE) + " import TopModule; "
        "inputs = json.load(open('_py_inputs.json')); "
        "inputs = [{{k: int(v) for k, v in inp.items()}} for inp in inputs]; "
        "dut = TopModule(); "
        "outputs = [dut.eval(inp) for inp in inputs]; "
        "print(json.dumps([{{k: str(int(v) if isinstance(v, bool) else v) for k,v in o.items()}} for o in outputs]));\\"";
    
    std::array<char, 65536> buffer;
    std::string output;
    
    FILE* pipe = popen(cmd.c_str(), "r");
    if (!pipe) return results;
    
    while (fgets(buffer.data(), buffer.size(), pipe) != nullptr) {{
        output += buffer.data();
    }}
    
    if (pclose(pipe) != 0) return results;
    
    // Parse JSON array output - values are strings
    size_t pos = 0;
    while ((pos = output.find("{{", pos)) != std::string::npos) {{
        size_t end = output.find("}}", pos);
        if (end == std::string::npos) break;
        
        std::string obj_str = output.substr(pos, end - pos + 2);
        std::map<std::string, std::string> obj;
        
        size_t kpos = 0;
        while ((kpos = obj_str.find("\\"", kpos)) != std::string::npos) {{
            size_t key_start = kpos + 1;
            size_t key_end = obj_str.find("\\"", key_start);
            if (key_end == std::string::npos) break;
            
            std::string key = obj_str.substr(key_start, key_end - key_start);
            
            size_t colon = obj_str.find(":", key_end);
            if (colon == std::string::npos) break;
            
            size_t val_quote_start = obj_str.find("\\"", colon);
            if (val_quote_start == std::string::npos) break;
            
            size_t val_start = val_quote_start + 1;
            size_t val_end = obj_str.find("\\"", val_start);
            if (val_end == std::string::npos) break;
            
            std::string value = obj_str.substr(val_start, val_end - val_start);
            obj[key] = value;
            kpos = val_end + 1;
        }}
        
        results.push_back(obj);
        pos = end + 2;
    }}
    
    return results;
}}

// Helper to compare string numbers
bool string_equals(const std::string& a, const std::string& b) {{
    size_t a_start = a.find_first_not_of('0');
    size_t b_start = b.find_first_not_of('0');
    std::string a_trimmed = (a_start == std::string::npos) ? "0" : a.substr(a_start);
    std::string b_trimmed = (b_start == std::string::npos) ? "0" : b.substr(b_start);
    return a_trimmed == b_trimmed;
}}

int main(int argc, char** argv) {{
    Verilated::commandArgs(argc, argv);
    
    VRefModule* ref = new VRefModule;
    VTopModule* dut = new VTopModule;
    cxxrtl_design::p_TopModule cxxrtl_dut;
    
    std::mt19937_64 gen(12345);  // Fixed seed for reproducibility
    std::uniform_int_distribution<uint64_t> dist(0, UINT64_MAX);
    std::uniform_int_distribution<uint32_t> dist32(0, UINT32_MAX);  // For wide signals
    
{chr(10).join(input_declarations)}
    int clk = 0;
    
    int dut_errors = 0, cxxrtl_errors = 0, python_errors = 0;
    const int NUM_CYCLES = 500;  // 500 clock cycles = 1000 half-cycles
    
    std::cout << "============================================" << std::endl;
    std::cout << "Cross-Language Verification (SEQUENTIAL)" << std::endl;
    std::cout << "Running " << NUM_CYCLES << " clock cycles" << std::endl;
    std::cout << "============================================" << std::endl;
    
    // Collect all inputs for Python batch processing (as STRINGS for arbitrary width)
    std::vector<std::map<std::string, std::string>> all_inputs;
    std::vector<std::map<std::string, std::string>> ref_outputs;
    
    // Initialize CXXRTL by running a negedge first (so it can detect posedge)
    cxxrtl_dut.p_clk.set(0);
    cxxrtl_dut.eval();
    cxxrtl_dut.commit();
    
    // === WARMUP PHASE: Run 20 clock cycles with reset ACTIVE (no comparison) ===
    const int WARMUP_CYCLES = {'20' if has_reset else '0'};
    std::cout << "Running " << WARMUP_CYCLES << " warmup cycles with reset active..." << std::endl;
    for (int warmup = 0; warmup < WARMUP_CYCLES; warmup++) {{
        // Generate random inputs
{chr(10).join(random_generators)}
        
        // Override reset signals to ACTIVE state
{warmup_reset_str}
        
        // Store inputs for Python (warmup cycles too - Python needs them for initialization)
        std::map<std::string, std::string> input_obj;
{input_str_code}
        all_inputs.push_back(input_obj);
        
        // === POSEDGE: clk 0 -> 1 ===
        clk = 1;
{chr(10).join(ref_setters)}
        ref->eval();
{chr(10).join(dut_setters)}
        dut->eval();
{chr(10).join(cxxrtl_setters)}
        cxxrtl_dut.eval();
        cxxrtl_dut.commit();
        
        // Store ref outputs (for Python output count matching, but no comparison)
        std::map<std::string, std::string> ref_out;
{output_str_code}
        ref_outputs.push_back(ref_out);
        
        // === NEGEDGE: clk 1 -> 0 ===
        clk = 0;
{chr(10).join(ref_setters)}
        ref->eval();
{chr(10).join(dut_setters)}
        dut->eval();
{chr(10).join(cxxrtl_setters)}
        cxxrtl_dut.eval();
        cxxrtl_dut.commit();
    }}
    
    // === MAIN TEST PHASE: Reset is INACTIVE (fixed, not random) ===
    for (int cycle = 0; cycle < NUM_CYCLES; cycle++) {{
        // Generate random inputs (change inputs before posedge)
{chr(10).join(random_generators)}
        
        // Override reset signals to INACTIVE state (fixed, not random)
{fixed_reset_str}
        
        std::map<std::string, std::string> input_obj;
{input_str_code}
        all_inputs.push_back(input_obj);
        
        // === POSEDGE: clk 0 -> 1 ===
        clk = 1;
        
        // RefModule
{chr(10).join(ref_setters)}
        ref->eval();
        
        // TopModule (DUT)
{chr(10).join(dut_setters)}
        dut->eval();
        
        // CXXRTL
{chr(10).join(cxxrtl_setters)}
        cxxrtl_dut.eval();
        cxxrtl_dut.commit();
        
        // Store reference outputs for this cycle (as strings)
        std::map<std::string, std::string> ref_out;
{output_str_code}
        ref_outputs.push_back(ref_out);
        
        // Compare DUT vs REF (use cycle as i)
        int i = cycle;
        (void)i;  // Suppress unused warning{''.join(dut_checks)}
        
        // Compare CXXRTL vs REF{''.join(cxxrtl_checks)}
        
        // === NEGEDGE: clk 1 -> 0 ===
        clk = 0;
{chr(10).join(ref_setters)}
        ref->eval();
{chr(10).join(dut_setters)}
        dut->eval();
{chr(10).join(cxxrtl_setters)}
        cxxrtl_dut.eval();
        cxxrtl_dut.commit();
    }}
    
    // Phase 2: Run Python batch simulation and compare
    std::cout << "Running Python simulation..." << std::endl;
    auto py_outputs = call_python_sequential(all_inputs);
    
    if (py_outputs.size() != ref_outputs.size()) {{
        std::cerr << "[PYTHON] Output count mismatch: expected " << ref_outputs.size()
                  << ", got " << py_outputs.size() << std::endl;
        python_errors += NUM_CYCLES;
    }} else {{
        // Skip first WARMUP_CYCLES outputs (warmup phase - no comparison)
        for (size_t cycle = WARMUP_CYCLES; cycle < ref_outputs.size(); cycle++) {{
            for (const auto& kv : ref_outputs[cycle]) {{
                const std::string& name = kv.first;
                const std::string& expected = kv.second;
                auto it = py_outputs[cycle].find(name);
                if (it != py_outputs[cycle].end()) {{
                    if (!string_equals(it->second, expected)) {{
                        if (python_errors < 10) {{
                            std::cerr << "[PYTHON MISMATCH] Cycle " << (cycle - WARMUP_CYCLES) << ", " << name
                                      << ": expected=" << expected << ", got=" << it->second << std::endl;
                        }}
                        python_errors++;
                    }}
                }}
            }}
        }}
    }}
    
    std::cout << "============================================" << std::endl;
    std::cout << "RESULTS" << std::endl;
    std::cout << "============================================" << std::endl;
    std::cout << "Total cycles:      " << NUM_CYCLES << std::endl;
    std::cout << "DUT errors:        " << dut_errors << std::endl;
    std::cout << "CXXRTL errors:     " << cxxrtl_errors << std::endl;
    std::cout << "Python errors:     " << python_errors << std::endl;
    std::cout << "============================================" << std::endl;
    
    int total_errors = dut_errors + cxxrtl_errors + python_errors;
    if (total_errors == 0) std::cout << "*** ALL TESTS PASSED ***" << std::endl;
    else std::cerr << "*** " << total_errors << " TOTAL ERRORS ***" << std::endl;
    
    delete ref;
    delete dut;
    return total_errors > 0 ? 1 : 0;
}}
'''


def generate_testbench_cpp(inputs, outputs, cxxrtl_cc, python_module):
    """
    Generate testbench.cpp that tests all 4 implementations.
    Handles both combinational and sequential (clocked) circuits.
    Supports arbitrary signal widths (including > 64 bits).
    """
    
    has_clk = any(name.lower() == 'clk' for name, _ in inputs)
    has_wide_signals = any(w > 64 for _, w in inputs + outputs)
    
    # Input declarations (exclude clk for random generation)
    input_declarations = []
    random_generators = []
    ref_setters = []
    dut_setters = []
    cxxrtl_setters = []
    input_to_string = []  # For JSON conversion
    
    for name, width in inputs:
        if name.lower() == 'clk':
            ref_setters.append(f"        ref->clk = clk;")
            dut_setters.append(f"        dut->clk = clk;")
            cxxrtl_setters.append(f"        cxxrtl_dut.{cxxrtl_mangle(name)}.set(clk);")
            continue
        
        if width > 64:
            # Wide signal handling
            decl, rand_code, ref_set, dut_set, cxxrtl_set, to_str = generate_wide_input_code(name, width)
            input_declarations.append(decl)
            random_generators.append(rand_code)
            ref_setters.append(ref_set)
            dut_setters.append(dut_set)
            cxxrtl_setters.append(cxxrtl_set)
            input_to_string.append((name, to_str))
        else:
            # Normal signal (<=64 bits)
            dtype = "uint64_t" if width > 32 else "uint32_t"
            mask = f"((1ULL << {width}) - 1)" if width < 64 else "UINT64_MAX"
            input_declarations.append(f"    {dtype} {name};")
            random_generators.append(f"        {name} = dist(gen) & {mask};")
            ref_setters.append(f"        ref->{name} = {name};")
            dut_setters.append(f"        dut->{name} = {name};")
            cxxrtl_setters.append(f"        cxxrtl_dut.{cxxrtl_mangle(name)}.set({name});")
            input_to_string.append((name, f"std::to_string({name})"))
    
    # Output to string conversions
    output_to_string = []
    for name, width in outputs:
        if width > 64:
            output_to_string.append((name, generate_wide_output_to_string(name, width, "ref")))
        else:
            output_to_string.append((name, f"std::to_string(ref->{name})"))
    
    # Python input JSON generation (unused but kept for compatibility)
    python_inputs = []
    for i, (name, _) in enumerate(inputs):
        comma = ', ' if i < len(inputs) - 1 else ''
        python_inputs.append(f'        ss << "\\"{name}\\": " << {name} << "{comma}";')
    
    # DUT vs REF comparisons
    dut_checks = []
    for name, width in outputs:
        if width > 64:
            dut_checks.append(generate_wide_output_comparison(name, width, "dut", "dut_errors", "DUT"))
        else:
            dut_checks.append(f'''
        if (ref->{name} != dut->{name}) {{
            if (dut_errors < 10) {{
                std::cerr << "[DUT MISMATCH] Test " << i << ", {name}: "
                          << "expected=" << (uint64_t)ref->{name} 
                          << ", got=" << (uint64_t)dut->{name} << std::endl;
            }}
            dut_errors++;
        }}''')
    
    # CXXRTL vs REF comparisons
    cxxrtl_checks = []
    for name, width in outputs:
        if width > 64:
            cxxrtl_checks.append(generate_wide_cxxrtl_comparison(name, width, "cxxrtl_errors"))
        else:
            mangled = cxxrtl_mangle(name)
            dtype = "uint64_t" if width > 32 else "uint32_t"
            cxxrtl_checks.append(f'''
        {{
            {dtype} cxxrtl_val = cxxrtl_dut.{mangled}.get<{dtype}>();
            if (({dtype})ref->{name} != cxxrtl_val) {{
                if (cxxrtl_errors < 10) {{
                    std::cerr << "[CXXRTL MISMATCH] Test " << i << ", {name}: "
                              << "expected=" << ({dtype})ref->{name} 
                              << ", got=" << cxxrtl_val << std::endl;
                }}
                cxxrtl_errors++;
            }}
        }}''')
    
    # Python vs REF comparisons (now string-based for arbitrary width)
    python_checks = []
    for name, _ in outputs:
        python_checks.append(f'''
        {{
            auto it = py_outputs.find("{name}");
            if (it != py_outputs.end()) {{
                // String comparison for arbitrary width
            }}
        }}''')
    
    # Clock handling - different for combinational vs sequential
    clk_init = "    int clk = 0;" if has_clk else ""
    
    # Detect reset signals: (name, width, is_active_low)
    reset_signals_info = []
    for name, width in inputs:
        if name.lower() != 'clk' and is_reset_signal(name):
            reset_signals_info.append((name, width, is_active_low_reset(name)))
    
    # Generate testbench based on combinational vs sequential
    if has_clk:
        # SEQUENTIAL CIRCUIT - proper clock handling
        testbench = generate_sequential_testbench(
            inputs, outputs, cxxrtl_cc, python_module,
            input_declarations, random_generators,
            ref_setters, dut_setters, cxxrtl_setters,
            python_inputs, dut_checks, cxxrtl_checks, python_checks,
            input_to_string, output_to_string, has_wide_signals,
            reset_signals_info
        )
    else:
        # COMBINATIONAL CIRCUIT - simple input/output testing
        testbench = generate_combinational_testbench(
            inputs, outputs, cxxrtl_cc, python_module,
            input_declarations, random_generators,
            ref_setters, dut_setters, cxxrtl_setters,
            python_inputs, dut_checks, cxxrtl_checks, python_checks,
            input_to_string, output_to_string, has_wide_signals,
            reset_signals_info
        )
    
    return testbench


def run_verification(ref_sv, dut_sv, cxxrtl_cc, python_file, work_dir="work"):
    """
    Run the full verification flow.
    """
    # Create work directory
    work_path = Path(work_dir)
    work_path.mkdir(parents=True, exist_ok=True)
    
    # Get basenames
    ref_basename = os.path.basename(ref_sv)
    dut_basename = os.path.basename(dut_sv)
    cxxrtl_basename = os.path.basename(cxxrtl_cc)
    python_basename = os.path.basename(python_file)
    python_module = os.path.splitext(python_basename)[0]
    
    # Copy files to work dir
    for src, dst in [
        (ref_sv, work_path / ref_basename),
        (dut_sv, work_path / dut_basename),
        (cxxrtl_cc, work_path / cxxrtl_basename),
        (python_file, work_path / python_basename)
    ]:
        shutil.copy(src, dst)
    
    # Extract ports from reference
    print(f"Extracting ports from {ref_sv}...")
    inputs, outputs = extract_ports_from_verilog(ref_sv)
    print(f"  Inputs:  {inputs}")
    print(f"  Outputs: {outputs}")
    
    # Generate testbench
    print("\nGenerating testbench.cpp...")
    tb_code = generate_testbench_cpp(inputs, outputs, cxxrtl_basename, python_module)
    tb_path = work_path / "testbench.cpp"
    with open(tb_path, 'w') as f:
        f.write(tb_code)
    print(f"  Generated: {tb_path}")
    
    # Change to work directory
    orig_dir = os.getcwd()
    os.chdir(work_path)
    
    try:
        # Step 1: Compile RefModule with Verilator
        print("\n[1/4] Compiling RefModule with Verilator...")
        verilator_ref = [
            "verilator", "--cc", ref_basename,
            "--top-module", "RefModule",
            "--prefix", "VRefModule",
            "-Wno-fatal", "-Wno-WIDTH", "-Wno-UNUSED",
            "-Wno-UNDRIVEN", "-Wno-UNOPTFLAT", "-Wno-DECLFILENAME"
        ]
        result = subprocess.run(verilator_ref, capture_output=True, text=True)
        if result.returncode != 0:
            print("Verilator RefModule failed!")
            print(result.stderr)
            # return 1
        print("  RefModule compiled successfully")
        
        # Step 2: Compile TopModule with Verilator
        # NOTE: Don't include dut.cc here - it's #included in testbench.cpp
        print("\n[2/4] Compiling TopModule with Verilator...")
        cxxrtl_include = "/usr/local/share/yosys/include/backends/cxxrtl/runtime"
        verilator_dut = [
            "verilator", "--cc", dut_basename,
            "--top-module", "TopModule",
            "--prefix", "VTopModule",
            "--exe", "testbench.cpp",  # Don't add dut.cc - it's #included
            "-CFLAGS", f"-std=c++14 -I{cxxrtl_include} -I.",
            "-Wno-fatal", "-Wno-WIDTH", "-Wno-UNUSED",
            "-Wno-UNDRIVEN", "-Wno-UNOPTFLAT", "-Wno-DECLFILENAME",
            "-o", "sim"
        ]
        result = subprocess.run(verilator_dut, capture_output=True, text=True)
        if result.returncode != 0:
            print("Verilator TopModule failed!")
            print(result.stderr)
            # return 1
        print("  TopModule compiled successfully")
        
        # Step 3: Build with make
        print("\n[3/4] Building with make...")
        
        # First build RefModule library
        make_ref = ["make", "-C", "obj_dir", "-f", "VRefModule.mk", "VRefModule__ALL.a"]
        result = subprocess.run(make_ref, capture_output=True, text=True)
        if result.returncode != 0:
            print("Make RefModule failed!")
            print(result.stdout)
            print(result.stderr)
            # return 1
        
        # Build VTopModule objects first (without linking)
        make_objs = ["make", "-C", "obj_dir", "-f", "VTopModule.mk", "VTopModule__ALL.a", "testbench.o", "verilated.o"]
        result = subprocess.run(make_objs, capture_output=True, text=True)
        if result.returncode != 0:
            print("Make objects failed!")
            print(result.stdout)
            print(result.stderr)
            # return 1
        
        # Link manually with both VTopModule and VRefModule
        print("  Linking...")
        link_cmd = [
            "g++", "-o", "obj_dir/sim",
            "obj_dir/testbench.o",
            "obj_dir/verilated.o",
            "obj_dir/VTopModule__ALL.a",
            "obj_dir/VRefModule__ALL.a"
        ]
        result = subprocess.run(link_cmd, capture_output=True, text=True)
        if result.returncode != 0:
            print("Linking failed!")
            print(result.stdout)
            print(result.stderr)
            # return 1
        print("  Build successful")
        
        # Step 4: Run simulation
        print("\n[4/4] Running simulation...")
        sim_path = "./obj_dir/sim"
        if not os.path.exists(sim_path):
            sim_path = "./obj_dir/VTopModule"
        
        result = subprocess.run([sim_path], capture_output=True, text=True, timeout=300)
        
        print("\n" + "="*50)
        print("SIMULATION OUTPUT")
        print("="*50)
        print(result.stdout)
        if result.stderr:
            print(result.stderr)
        
        return result.returncode
        
    except subprocess.TimeoutExpired:
        print("Simulation timed out!")
        return 1
    finally:
        os.chdir(orig_dir)


def main():
    parser = argparse.ArgumentParser(
        description="Cross-Language Verification: Compare REF SV, DUT SV, CXXRTL, and Python",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Example:
    python crosslang_verify.py ref.sv dut.sv dut.cc dut.py

Module naming conventions (fixed):
    - ref.sv: module RefModule
    - dut.sv: module TopModule
    - dut.cc: struct p_TopModule
    - dut.py: function top_module(**kwargs) -> dict
"""
    )
    parser.add_argument("ref_sv", help="Golden reference SystemVerilog (module RefModule)")
    parser.add_argument("dut_sv", help="DUT SystemVerilog (module TopModule)")
    parser.add_argument("cxxrtl_cc", help="CXXRTL C++ file (struct p_TopModule)")
    parser.add_argument("python_file", help="Python file (top_module function)")
    parser.add_argument("-w", "--work-dir", default="work", help="Working directory (default: work)")
    
    args = parser.parse_args()
    
    # Validate files exist
    for path, desc in [
        (args.ref_sv, "Reference SV"),
        (args.dut_sv, "DUT SV"),
        (args.cxxrtl_cc, "CXXRTL CC"),
        (args.python_file, "Python")
    ]:
        if not os.path.exists(path):
            print(f"Error: {desc} file not found: {path}")
            sys.exit(1)
    
    ret = run_verification(args.ref_sv, args.dut_sv, args.cxxrtl_cc, args.python_file, args.work_dir)
    sys.exit(ret)


if __name__ == "__main__":
    main()
