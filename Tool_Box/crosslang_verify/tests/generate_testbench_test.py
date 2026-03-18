import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from tools.extract_ports import extract_ports_from_verilog, extract_ports_from_json
from tools.reset import is_reset_signal, is_active_low_reset


def test_extract_ports_from_verilog():
    inputs, outputs = extract_ports_from_verilog("/workspace/verilogeval/Tool_Box/verilog/dut.sv")
    assert inputs == [("clk", 1), ("rst_n", 1)]
    assert outputs == [("Q", 4)]

def test_extract_ports_from_json():
    inputs, outputs = extract_ports_from_json("/workspace/verilogeval/Tool_Box/verilog/ports.json")
    assert inputs == [("clk", 1), ("rst_n", 1)]
    assert outputs == [("Q", 4)]

def test_is_reset_signal():
    assert is_reset_signal("reset") == (True, False)
    assert is_reset_signal("rst") == (True, False)
    assert is_reset_signal("areset") == (True, False)
    assert is_reset_signal("async_reset") == (True, False)
    assert is_reset_signal("reset_n") == (True, True)
    assert is_reset_signal("rst_n") == (True, True)
    assert is_reset_signal("nreset") == (True, True)
    assert is_reset_signal("nreset_n") == (True, True)
    assert is_reset_signal("nreset_b") == (True, True)
    assert is_reset_signal("nreset_l") == (True, True)


# ---------------------------------------------------------------------------
# DUT classes
# ---------------------------------------------------------------------------
from tools.dut import VerilogDUT, CxxrtlDUT, PythonDUT


def test_verilog_dut_setter_any_width():
    dut = VerilogDUT()
    assert not dut.is_batch
    assert "dut->a = a;" in dut.input_setter("a", 1)
    assert "dut->b = b;" in dut.input_setter("b", 32)
    assert "dut->c = c;" in dut.input_setter("c", 64)
    s = dut.input_setter("d", 128)
    assert "for (int _i" in s
    assert "dut->d[_i]" in s


def test_cxxrtl_dut_mangle():
    assert CxxrtlDUT.mangle("clk") == "p_clk"
    assert CxxrtlDUT.mangle("rst_n") == "p_rst__n"
    assert CxxrtlDUT.mangle("data_in") == "p_data__in"


def test_cxxrtl_dut_setter_any_width():
    dut = CxxrtlDUT("dut.cc")
    assert not dut.is_batch
    assert ".set(a)" in dut.input_setter("a", 8)
    assert ".set(b)" in dut.input_setter("b", 64)
    s = dut.input_setter("c", 128)
    assert ".data[_i]" in s


def test_cxxrtl_helper_code():
    dut = CxxrtlDUT()
    code = dut.helper_code(is_sequential=False)
    assert "value_to_string" in code
    assert "wire_to_string" in code


def test_dut_output_compare():
    vdut = VerilogDUT()
    cdut = CxxrtlDUT()
    assert "dut_errors" in vdut.output_compare("Q", 4)
    assert "cxxrtl_errors" in cdut.output_compare("Q", 4)
    assert "mismatch" in vdut.output_compare("wide", 128)
    assert "mismatch" in cdut.output_compare("wide", 128)


def test_python_dut_is_batch():
    dut = PythonDUT("dut.py")
    assert dut.is_batch
    assert dut.label == "Python"
    assert dut.error_var == "python_errors"
    assert dut.python_module == "dut"


def test_python_dut_include():
    dut = PythonDUT("my_module.py")
    assert 'PYTHON_MODULE' in dut.include_code()
    assert 'my_module' in dut.include_code()


def test_python_dut_helper_code():
    dut = PythonDUT("dut.py")
    code = dut.helper_code(is_sequential=True)
    assert "string_equals" in code
    assert "call_python_sequential" in code
    code = dut.helper_code(is_sequential=False)
    assert "call_python_batch" in code


def test_python_dut_post_loop():
    dut = PythonDUT("dut.py")
    code = dut.post_loop_compare(is_sequential=True)
    assert "call_python_sequential" in code
    assert "python_errors" in code
    assert "Python MISMATCH" in code
    code = dut.post_loop_compare(is_sequential=False)
    assert "call_python_batch" in code


def test_python_dut_no_inline_methods():
    """Batch DUTs return empty for inline methods."""
    dut = PythonDUT("dut.py")
    assert dut.init_code() == ""
    assert dut.clk_setter("clk") == ""
    assert dut.input_setter("a", 8) == ""
    assert dut.eval_code() == ""
    assert dut.output_compare("Q", 4) == ""


# ---------------------------------------------------------------------------
# Signal generation (unified width)
# ---------------------------------------------------------------------------
from tools.signal_gen import (
    get_num_chunks, gen_declaration, gen_random, gen_ref_setter,
    gen_to_string, gen_reset_override, generate_signal_code,
)


def test_get_num_chunks():
    assert get_num_chunks(1) == 1
    assert get_num_chunks(32) == 1
    assert get_num_chunks(33) == 2
    assert get_num_chunks(64) == 2
    assert get_num_chunks(65) == 3
    assert get_num_chunks(128) == 4


def test_gen_declaration_any_width():
    assert "uint32_t a;" in gen_declaration("a", 1)
    assert "uint32_t b;" in gen_declaration("b", 32)
    assert "uint64_t c;" in gen_declaration("c", 33)
    assert "uint64_t d;" in gen_declaration("d", 64)
    assert "uint32_t e[3];" in gen_declaration("e", 65)
    assert "uint32_t f[4];" in gen_declaration("f", 128)


def test_gen_random_any_width():
    r = gen_random("a", 8)
    assert "dist(gen)" in r
    assert "1ULL << 8" in r
    assert "UINT64_MAX" in gen_random("b", 64)
    r = gen_random("c", 65)
    assert "dist32(gen)" in r
    assert "c[0]" in r
    assert "c[2]" in r


def test_gen_to_string_any_width():
    assert "std::to_string(a)" in gen_to_string("a", 32)
    assert "wide_to_string" in gen_to_string("b", 128)


def test_gen_reset_override_any_width():
    assert "= 0;" in gen_reset_override("rst_n", 1, True, active=True)
    assert "= 1;" in gen_reset_override("rst_n", 1, True, active=False)
    r = gen_reset_override("wide_rst", 128, False, active=True)
    assert "wide_rst[0]" in r


def test_generate_signal_code():
    inputs = [("clk", 1), ("d", 8)]
    outputs = [("Q", 4)]
    # Only inline DUTs go into signal_code
    duts = [VerilogDUT(), CxxrtlDUT()]
    sig = generate_signal_code(inputs, outputs, duts, [])
    assert len(sig['declarations']) == 1
    assert "d" in sig['declarations'][0]
    for dut in duts:
        assert len(sig['dut_setters'][dut]) == 2  # clk + d
        assert len(sig['dut_checks'][dut]) == 1   # Q


# ---------------------------------------------------------------------------
# Full testbench generation
# ---------------------------------------------------------------------------
from src.generate_testbench import generate_testbench


def test_generate_testbench_all_duts():
    """Full testbench: clk + rst_n + Q[4], with Verilog + CXXRTL + Python."""
    code = generate_testbench(
        json_file="/workspace/verilogeval/Tool_Box/verilog/ports.json",
        dut_verilog_file="dut.sv",
        dut_cxxrtl_file="dut.cc",
        dut_python_file="dut.py",
    )
    # Includes
    assert "#include" in code
    assert "VRefModule" in code
    assert "VTopModule" in code
    assert "cxxrtl" in code
    assert "PYTHON_MODULE" in code

    # Sequential structure
    assert "SEQUENTIAL" in code
    assert "NUM_CYCLES" in code
    assert "clk = 1;" in code
    assert "clk = 0;" in code

    # Reset handling
    assert "rst_n = 0;" in code
    assert "rst_n = 1;" in code

    # Per-DUT error reporting (no total_errors)
    assert "DUT:" in code and "PASS" in code
    assert "CXXRTL:" in code
    assert "Python:" in code
    assert "total_errors" not in code

    # Python batch (from PythonDUT.post_loop_compare)
    assert "call_python_sequential" in code

    # Batch collection (all_inputs/ref_outputs present because Python is batch)
    assert "all_inputs" in code
    assert "ref_outputs" in code


def test_generate_testbench_no_batch():
    """Only inline DUTs — no batch collection vectors."""
    code = generate_testbench(
        json_file="/workspace/verilogeval/Tool_Box/verilog/ports.json",
        dut_verilog_file="dut.sv",
        dut_cxxrtl_file="dut.cc",
    )
    assert "VTopModule" in code
    assert "cxxrtl_design" in code
    assert "python_errors" not in code
    assert "all_inputs" not in code
    assert "call_python" not in code


def test_generate_testbench_only_python():
    """Only Python DUT — no inline eval/compare in loop."""
    code = generate_testbench(
        json_file="/workspace/verilogeval/Tool_Box/verilog/ports.json",
        dut_python_file="dut.py",
    )
    assert "VTopModule" not in code
    assert "cxxrtl_design" not in code
    assert "PYTHON_MODULE" in code
    assert "call_python_sequential" in code
    assert "python_errors" in code
    assert "Python:" in code and "PASS" in code


def test_generate_testbench_only_cxxrtl():
    """Only CXXRTL, no Verilog DUT or Python."""
    code = generate_testbench(
        json_file="/workspace/verilogeval/Tool_Box/verilog/ports.json",
        dut_cxxrtl_file="dut.cc",
    )
    assert "VTopModule" not in code
    assert "cxxrtl_design" in code
    assert "python_errors" not in code
    assert "CXXRTL:" in code and "PASS" in code
