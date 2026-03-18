"""
DUT (Device Under Test) abstraction for testbench generation.

Two execution models:
- Inline (is_batch=False): set inputs, eval, compare inside the C++ loop
- Batch  (is_batch=True):  collect inputs during the loop, run + compare after
"""

import os


def _mismatch_block(error_var, label, name, width, get_ref, get_dut):
    """Generate C++ comparison block for any width."""
    if width <= 64:
        return f'''
        if ({get_ref} != {get_dut}) {{
            if ({error_var} < 10) {{
                std::cerr << "[{label} MISMATCH] Test " << i << ", {name}: "
                          << "expected=" << (uint64_t){get_ref}
                          << ", got=" << (uint64_t){get_dut} << std::endl;
            }}
            {error_var}++;
        }}'''
    n = (width + 31) // 32
    return f'''
        {{
            bool mismatch = false;
            for (int _i = 0; _i < {n}; _i++) {{
                if ({get_ref}[_i] != {get_dut}[_i]) mismatch = true;
            }}
            if (mismatch) {{
                if ({error_var} < 10) {{
                    std::cerr << "[{label} MISMATCH] Test " << i << ", {name}" << std::endl;
                }}
                {error_var}++;
            }}
        }}'''


class DUT:
    """Base class for all DUT implementations."""
    is_batch = False

    def __init__(self, var_name, error_var, label):
        self.var_name = var_name
        self.error_var = error_var
        self.label = label

    def include_code(self):        return ""
    def init_code(self):            return ""
    def clk_setter(self, name):     return ""
    def input_setter(self, name, width): return ""
    def eval_code(self):            return ""
    def output_compare(self, name, width): return ""
    def cleanup_code(self):         return ""
    def sequential_init(self):      return ""
    def helper_code(self, is_sequential): return ""
    def post_loop_compare(self, is_sequential): return ""


class VerilogDUT(DUT):
    """Verilator-compiled DUT (VTopModule)."""

    def __init__(self):
        super().__init__("dut", "dut_errors", "DUT")

    def include_code(self):
        return '#include "VTopModule.h"'

    def init_code(self):
        return "    VTopModule* dut = new VTopModule;"

    def clk_setter(self, name):
        return f"        dut->{name} = clk;"

    def input_setter(self, name, width):
        if width <= 64:
            return f"        dut->{name} = {name};"
        n = (width + 31) // 32
        return f"        for (int _i = 0; _i < {n}; _i++) dut->{name}[_i] = {name}[_i];"

    def eval_code(self):
        return "        dut->eval();"

    def output_compare(self, name, width):
        return _mismatch_block(self.error_var, self.label, name, width,
                               f"ref->{name}", f"dut->{name}")

    def cleanup_code(self):
        return "    delete dut;"


class CxxrtlDUT(DUT):
    """CXXRTL-based DUT."""

    def __init__(self, cxxrtl_file="dut.cc"):
        super().__init__("cxxrtl_dut", "cxxrtl_errors", "CXXRTL")
        self.cxxrtl_file = cxxrtl_file

    @staticmethod
    def mangle(name):
        return 'p_' + name.replace('_', '__')

    def include_code(self):
        return f'#include <cxxrtl/cxxrtl.h>\n#include "../{self.cxxrtl_file}"'

    def init_code(self):
        return "    cxxrtl_design::p_TopModule cxxrtl_dut;"

    def clk_setter(self, name):
        return f"        cxxrtl_dut.{self.mangle(name)}.set(clk);"

    def input_setter(self, name, width):
        m = self.mangle(name)
        if width <= 64:
            return f"        cxxrtl_dut.{m}.set({name});"
        n = (width + 31) // 32
        return f"        for (int _i = 0; _i < {n}; _i++) cxxrtl_dut.{m}.data[_i] = {name}[_i];"

    def eval_code(self):
        return "        cxxrtl_dut.eval();\n        cxxrtl_dut.commit();"

    def output_compare(self, name, width):
        m = self.mangle(name)
        ev = self.error_var
        if width <= 64:
            dtype = "uint64_t" if width > 32 else "uint32_t"
            return f'''
        {{
            {dtype} cxxrtl_val = cxxrtl_dut.{m}.get<{dtype}>();
            if (({dtype})ref->{name} != cxxrtl_val) {{
                if ({ev} < 10) {{
                    std::cerr << "[{self.label} MISMATCH] Test " << i << ", {name}: "
                              << "expected=" << ({dtype})ref->{name}
                              << ", got=" << cxxrtl_val << std::endl;
                }}
                {ev}++;
            }}
        }}'''
        n = (width + 31) // 32
        return _mismatch_block(ev, self.label, name, width,
                               f"ref->{name}", f"cxxrtl_dut.{m}.data")

    def sequential_init(self):
        return """    cxxrtl_dut.p_clk.set(0);
    cxxrtl_dut.eval();
    cxxrtl_dut.commit();"""

    def helper_code(self, is_sequential):
        from tools.cpp_helpers import gen_value_to_string
        return gen_value_to_string()


class PythonDUT(DUT):
    """Python DUT — runs all inputs via subprocess in one batch."""
    is_batch = True

    def __init__(self, python_file):
        module = os.path.splitext(os.path.basename(python_file))[0]
        super().__init__("python", "python_errors", "Python")
        self.python_module = module

    def include_code(self):
        return f'const char* PYTHON_MODULE = "{self.python_module}";'

    def helper_code(self, is_sequential):
        from tools.cpp_helpers import gen_string_equals, gen_call_python
        return gen_string_equals() + gen_call_python(is_sequential)

    def post_loop_compare(self, is_sequential):
        func = "call_python_sequential" if is_sequential else "call_python_batch"
        count = "NUM_CYCLES" if is_sequential else "NUM_TESTS"
        label = "Cycle" if is_sequential else "Test"
        ev = self.error_var
        return f'''
    std::cout << "Running {self.label} simulation..." << std::endl;
    auto py_outputs = {func}(all_inputs);

    if (py_outputs.size() != ref_outputs.size()) {{
        std::cerr << "[{self.label}] Output count mismatch: expected " << ref_outputs.size()
                  << ", got " << py_outputs.size() << std::endl;
        {ev} += {count};
    }} else {{
        for (size_t i = WARMUP_CYCLES; i < ref_outputs.size(); i++) {{
            for (const auto& kv : ref_outputs[i]) {{
                const std::string& name = kv.first;
                const std::string& expected = kv.second;
                auto it = py_outputs[i].find(name);
                if (it != py_outputs[i].end()) {{
                    if (!string_equals(it->second, expected)) {{
                        if ({ev} < 10) {{
                            std::cerr << "[{self.label} MISMATCH] {label} " << (i - WARMUP_CYCLES) << ", " << name
                                      << ": expected=" << expected << ", got=" << it->second << std::endl;
                        }}
                        {ev}++;
                    }}
                }}
            }}
        }}
    }}
'''
