# generate_testbench.py

Generates a complete `testbench.cpp` for cross-language verification.

## Usage

```python
from src.generate_testbench import generate_testbench

cpp_code = generate_testbench(
    json_file="ports.json",           # or ref_verilog_file="ref.sv"
    dut_verilog_file="dut.sv",        # optional
    dut_cxxrtl_file="dut.cc",         # optional
    dut_python_file="dut.py",         # optional
)
```

Only the DUT files you provide are included.

## `generate_testbench(...) -> str`

| Parameter | Type | Description |
|---|---|---|
| `json_file` | `str \| None` | JSON port description |
| `ref_verilog_file` | `str \| None` | Reference Verilog (alternative to JSON) |
| `dut_verilog_file` | `str \| None` | Verilator DUT (inline) |
| `dut_cxxrtl_file` | `str \| None` | CXXRTL DUT (inline) |
| `dut_python_file` | `str \| None` | Python DUT (batch) |
| `dut_systemc_file` | `str \| None` | Reserved |
| `dut_rust_file` | `str \| None` | Reserved |

Must provide either `json_file` or `ref_verilog_file`.

## DUT execution models

| Model | DUTs | How it works |
|---|---|---|
| **Inline** | `VerilogDUT`, `CxxrtlDUT` | Set inputs, eval, compare inside the C++ loop |
| **Batch** | `PythonDUT` | Collect inputs during loop, run + compare after |

- No batch DUTs active → `all_inputs`/`ref_outputs` vectors omitted entirely
- No inline DUTs active → loop still runs ref for warmup and collection

## Generated testbench structure

```
1. Includes       — standard headers + each DUT's include_code()
2. Helpers        — each DUT's helper_code() + wide_to_string if needed
3. main()
   a. Model init  — VRefModule + each DUT's init_code()
   b. Warmup      — 20 cycles, reset active, no comparison
   c. Test loop   — inline DUTs eval+compare; batch DUTs collect
   d. Post-loop   — each batch DUT's post_loop_compare()
   e. Results     — per-DUT PASS/FAIL
```

## Error reporting

Each DUT reports independently, no `total_errors`:

```
RESULTS
Total: 500
DUT:     PASS
CXXRTL:  FAIL (3 errors)
Python:  PASS
```

Return code: `1` if any DUT has errors, `0` if all pass.

## Dependencies

```
src/generate_testbench.py
├── tools/extract_ports.py
├── tools/clk.py
├── tools/reset.py
├── tools/dut.py
├── tools/signal_gen.py
└── tools/cpp_helpers.py
```

## Internal functions

| Function | Description |
|---|---|
| `_gen_includes(...)` | C++ `#include` block |
| `_gen_main_opening(...)` | `main()` opening: init, RNG, declarations |
| `_eval_block(sig, inline_duts)` | Ref + inline DUTs: set inputs + eval |
| `_compare_block(sig, inline_duts)` | Inline DUTs vs ref comparison |
| `_collect_block(sig, has_batch)` | Batch DUT collection code (or empty) |
| `_dut_eval_block(sig, inline_duts)` | Inline DUTs only: set + eval (no ref) |
| `_fixed_reset_str(sig)` | Reset-inactive override string |
| `_banner(label, count_var)` | Test banner output |
| `_gen_warmup(...)` | Warmup phase |
| `_gen_combinational_loop(...)` | Main loop for combinational circuits |
| `_gen_sequential_loop(...)` | Main loop for sequential circuits |
| `_gen_results(duts, ...)` | Per-DUT PASS/FAIL summary |
