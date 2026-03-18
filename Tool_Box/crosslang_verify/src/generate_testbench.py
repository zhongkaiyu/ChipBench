import os
import tools.extract_ports as extract_ports
from tools.reset import is_reset_signal
from tools.clk import is_clk_signal
from tools.dut import VerilogDUT, CxxrtlDUT, PythonDUT
from tools.signal_gen import generate_signal_code
from tools.cpp_helpers import gen_all_helpers


def _gen_includes(is_sequential, duts):
    circuit = "SEQUENTIAL CIRCUIT (with clock)" if is_sequential else "COMBINATIONAL CIRCUIT (no clock)"
    dut_names = ["RefModule (SV)"] + [d.label for d in duts]
    code = f'''// Auto-generated Cross-Language Verification Testbench
// {circuit}
// Tests: {', '.join(dut_names)}

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

// Verilator headers (ref)
#include "VRefModule.h"
#include "verilated.h"

'''
    for dut in duts:
        inc = dut.include_code()
        if inc:
            code += f"// {dut.label}\n{inc}\n\n"
    return code


def _gen_main_opening(sig, duts, is_sequential, has_batch):
    decls = '\n'.join(sig['declarations'])
    clk_decl = "\n    int clk = 0;" if is_sequential else ""
    error_decls = '\n'.join(f"    int {d.error_var} = 0;" for d in duts)
    init_lines = '\n'.join(d.init_code() for d in duts if d.init_code())
    batch_decls = ""
    if has_batch:
        batch_decls = """
    std::vector<std::map<std::string, std::string>> all_inputs;
    std::vector<std::map<std::string, std::string>> ref_outputs;"""

    return f'''
int main(int argc, char** argv) {{
    Verilated::commandArgs(argc, argv);

    VRefModule* ref = new VRefModule;
{init_lines}

    std::mt19937_64 gen(12345);
    std::uniform_int_distribution<uint64_t> dist(0, UINT64_MAX);
    std::uniform_int_distribution<uint32_t> dist32(0, UINT32_MAX);

{decls}{clk_decl}

{error_decls}{batch_decls}
'''


def _eval_block(sig, inline_duts):
    """Set inputs + eval for ref and all inline DUTs."""
    lines = ['\n'.join(sig['ref_setters']), "        ref->eval();"]
    for dut in inline_duts:
        lines.append(f"\n        // {dut.label}")
        lines.append('\n'.join(sig['dut_setters'][dut]))
        lines.append(dut.eval_code())
    return '\n'.join(lines)


def _compare_block(sig, inline_duts):
    parts = []
    for dut in inline_duts:
        parts.append(f"\n        // Compare {dut.label} vs REF")
        parts.extend(sig['dut_checks'][dut])
    return ''.join(parts)


def _collect_block(sig, has_batch):
    """Input/output collection for batch DUTs, or empty strings."""
    if not has_batch:
        return "", ""
    in_str = '\n'.join(f'        input_obj["{n}"] = {e};' for n, e in sig['input_to_string'])
    out_str = '\n'.join(f'        ref_out["{n}"] = {e};' for n, e in sig['output_to_string'])
    return (
        f"        std::map<std::string, std::string> input_obj;\n{in_str}\n        all_inputs.push_back(input_obj);",
        f"        std::map<std::string, std::string> ref_out;\n{out_str}\n        ref_outputs.push_back(ref_out);",
    )


def _dut_eval_block(sig, inline_duts):
    """Setter + eval for inline DUTs only (no ref)."""
    parts = []
    for d in inline_duts:
        parts.append(f"        // {d.label}")
        parts.extend(sig['dut_setters'][d])
        parts.append(d.eval_code())
    return '\n'.join(parts)


def _fixed_reset_str(sig):
    return '\n'.join(sig['fixed_reset']) if sig['fixed_reset'] else '        // No reset signals'


def _gen_warmup(sig, inline_duts, is_sequential, has_reset, has_batch):
    warmup_reset = '\n'.join(sig['warmup_reset']) if sig['warmup_reset'] else '            // No reset signals'
    rand_str = '\n'.join(sig['random_generators'])
    collect_in, collect_out = _collect_block(sig, has_batch)

    seq_init = ''.join(d.sequential_init() + "\n\n" for d in inline_duts if d.sequential_init())

    if is_sequential:
        eval_section = f"""
        clk = 1;
{_eval_block(sig, inline_duts)}
{collect_out}
        clk = 0;
{_eval_block(sig, inline_duts)}"""
    else:
        eval_section = f"""
{_eval_block(sig, inline_duts)}
{collect_out}"""

    return f'''{seq_init}
    const int WARMUP_CYCLES = {'20' if has_reset else '0'};
    std::cout << "Running " << WARMUP_CYCLES << " warmup cycles with reset active..." << std::endl;
    for (int warmup = 0; warmup < WARMUP_CYCLES; warmup++) {{
{rand_str}
{warmup_reset}
{collect_in}
{eval_section}
    }}
'''


def _gen_combinational_loop(sig, inline_duts, has_batch):
    rand_str = '\n'.join(sig['random_generators'])
    ref_set = '\n'.join(sig['ref_setters'])
    collect_in, collect_out = _collect_block(sig, has_batch)

    return f'''
    for (int i = 0; i < NUM_TESTS; i++) {{
{rand_str}
{_fixed_reset_str(sig)}
{collect_in}
{ref_set}
        ref->eval();
{collect_out}
{_dut_eval_block(sig, inline_duts)}
{_compare_block(sig, inline_duts)}
    }}
'''


def _gen_sequential_loop(sig, inline_duts, has_batch):
    rand_str = '\n'.join(sig['random_generators'])
    collect_in, collect_out = _collect_block(sig, has_batch)

    return f'''
    for (int cycle = 0; cycle < NUM_CYCLES; cycle++) {{
{rand_str}
{_fixed_reset_str(sig)}
{collect_in}
        clk = 1;
{_eval_block(sig, inline_duts)}
{collect_out}
        int i = cycle;
        (void)i;
{_compare_block(sig, inline_duts)}
        clk = 0;
{_eval_block(sig, inline_duts)}
    }}
'''


def _gen_results(duts, is_sequential):
    count_var = "NUM_CYCLES" if is_sequential else "NUM_TESTS"
    lines = [
        '    std::cout << "============================================" << std::endl;',
        '    std::cout << "RESULTS" << std::endl;',
        '    std::cout << "============================================" << std::endl;',
        f'    std::cout << "Total: " << {count_var} << std::endl;',
    ]
    all_evs = []
    for dut in duts:
        ev, pad = dut.error_var, " " * max(1, 8 - len(dut.label))
        all_evs.append(ev)
        lines.append(f'    if ({ev} == 0) std::cout << "{dut.label}:{pad}PASS" << std::endl;')
        lines.append(f'    else std::cerr << "{dut.label}:{pad}FAIL (" << {ev} << " errors)" << std::endl;')
    lines.append('')
    lines.append('    delete ref;')
    lines.extend(d.cleanup_code() for d in duts if d.cleanup_code())
    lines.append(f'    return ({" || ".join(f"{ev} > 0" for ev in all_evs)}) ? 1 : 0;')
    lines.append('}')
    return '\n'.join(lines) + '\n'


def _banner(label, count_var):
    return f'''
    std::cout << "============================================" << std::endl;
    std::cout << "Cross-Language Verification ({label})" << std::endl;
    std::cout << "Running " << {count_var} << " {'clock cycles' if label == 'SEQUENTIAL' else 'tests'}" << std::endl;
    std::cout << "============================================" << std::endl;
'''


def generate_testbench(json_file=None, ref_verilog_file=None, dut_verilog_file=None,
                       dut_python_file=None, dut_cxxrtl_file=None, dut_systemc_file=None,
                       dut_rust_file=None, work_dir="work"):
    """Generate a complete testbench.cpp string."""

    # Extract ports
    if json_file is not None:
        inputs, outputs = extract_ports.extract_ports_from_json(json_file)
    elif ref_verilog_file is not None:
        inputs, outputs = extract_ports.extract_ports_from_verilog(ref_verilog_file)
    else:
        raise ValueError("provide either a json file or a ref verilog file")

    # Detect clk / reset
    is_sequential = is_clk_signal(inputs)
    reset_signals = [(n, w, is_reset_signal(n)[1]) for n, w in inputs if is_reset_signal(n)[0]]
    has_reset = len(reset_signals) > 0
    has_wide = any(w > 64 for _, w in inputs + outputs)

    # Build DUT list
    duts = []
    if dut_verilog_file: duts.append(VerilogDUT())
    if dut_cxxrtl_file:  duts.append(CxxrtlDUT(os.path.basename(dut_cxxrtl_file)))
    if dut_python_file:  duts.append(PythonDUT(dut_python_file))

    inline_duts = [d for d in duts if not d.is_batch]
    batch_duts = [d for d in duts if d.is_batch]
    has_batch = len(batch_duts) > 0

    # Generate signal code (only inline DUTs need setters/checks)
    sig = generate_signal_code(inputs, outputs, inline_duts, reset_signals)

    # Assemble C++ file
    code = _gen_includes(is_sequential, duts)
    code += gen_all_helpers(has_wide, duts, is_sequential)
    code += _gen_main_opening(sig, duts, is_sequential, has_batch)

    if is_sequential:
        code += "    const int NUM_CYCLES = 500;\n"
        code += _banner("SEQUENTIAL", "NUM_CYCLES")
        code += _gen_warmup(sig, inline_duts, True, has_reset, has_batch)
        code += _gen_sequential_loop(sig, inline_duts, has_batch)
    else:
        code += "    const int NUM_TESTS = 1000;\n"
        code += _banner("COMBINATIONAL", "NUM_TESTS")
        code += _gen_warmup(sig, inline_duts, False, has_reset, has_batch)
        code += _gen_combinational_loop(sig, inline_duts, has_batch)

    for dut in batch_duts:
        code += dut.post_loop_compare(is_sequential)

    code += _gen_results(duts, is_sequential)
    return code
