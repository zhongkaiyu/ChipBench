# Tool Box

Cross‑language verification utilities for checking that multiple implementations of the same hardware design (SystemVerilog, Python, CXXRTL) produce identical results.

## Directory Structure

```
Tool Box/
├── README.md
├── crosslang_verify/           # Main verification package
│   ├── main.py                 # CLI entry point
│   ├── src/
│   │   ├── generate_testbench.py   # Generates testbench.cpp
│   │   └── run_verification.py     # Build pipeline & execution
│   ├── tools/
│   │   ├── extract_ports.py    # Verilog/JSON port parser
│   │   ├── dut.py              # DUT abstraction classes
│   │   ├── clk.py              # Clock signal detection
│   │   ├── reset.py            # Reset signal detection
│   │   ├── signal_gen.py       # C++ signal code generation
│   │   └── cpp_helpers.py      # C++ helper function generators
│   ├── tests/
│   │   └── generate_testbench_test.py
│   └── docs/
├── verilog/
│   ├── ref.sv                  # Reference SystemVerilog (module RefModule)
│   └── dut.sv                  # Design under test (module TopModule)
├── python/
│   └── dut.py                  # Python reference model
├── cxxrtl/
│   └── dut.cc                  # CXXRTL C++ reference model
└── systemc/
    └── dut.cc                  # SystemC reference model (placeholder)
```

## Supported Languages

| Language | File | Notes |
|----------|------|-------|
| SystemVerilog (reference) | `verilog/ref.sv` | Golden reference, module name must be `RefModule` |
| SystemVerilog (DUT) | `verilog/dut.sv` | Device under test, module name must be `TopModule` |
| CXXRTL (C++) | `cxxrtl/dut.cc` | Struct name must be `p_TopModule` |
| Python | `python/dut.py` | Must export a `TopModule` class with an `eval(inputs_dict)` method |

> **Note:** SystemC support is planned for the future but is not yet wired into the verification flow. Rust and other high‑level languages may be added later. 

## How It Works

The `crosslang_verify` package automates an end‑to‑end comparison across all supported implementations:

```
Extract inputs / outputs from Verilog (or JSON)
            │
            ▼
Generate testbench (C++ testbench.cpp)
            │
            ▼
Compile & run via Verilator (+ YOSYS for CXXRTL)
            │
            ▼
Compare outputs cycle‑by‑cycle across all DUTs
```

### Step 1 — Port Extraction

`tools/extract_ports.py` parses SystemVerilog source files (or a JSON port description) to automatically extract input and output port declarations (names, widths, directions). It supports arbitrary bit widths, including signals wider than 64 bits.

### Step 2 — Testbench Generation

`src/generate_testbench.py` auto‑generates a C++ testbench (`testbench.cpp`) that:

- Instantiates the reference model and any combination of DUTs (Verilog, CXXRTL, Python).
- Drives them with the **same random inputs** using a fixed seed (`12345`) for reproducibility.
- For **combinational** circuits: applies 1000 random input vectors.
- For **sequential** circuits: runs 500 clock cycles with a 20‑cycle warmup/reset phase.
- Inline DUTs (Verilog, CXXRTL) are compared inside the loop; batch DUTs (Python) are compared after.

### Step 3 — Simulation & Comparison

`src/run_verification.py` orchestrates compilation via Verilator + YOSYS (for CXXRTL), runs the simulation, and reports per‑DUT PASS/FAIL results. The first 10 mismatches per DUT are reported.

## Limitations

- The testbench **only supports the rising edge of clock** for sequential circuits.
- Currently only **SystemVerilog, Python, and CXXRTL** are fully integrated; SystemC is not yet supported in the verification flow.

## Usage

```bash
cd crosslang_verify
python main.py <ref_sv> [--dut-sv FILE] [--dut-cc FILE] [--dut-py FILE] [--json FILE] [-w DIR]
```

At least one DUT (`--dut-sv`, `--dut-cc`, or `--dut-py`) must be provided. You can mix and match any combination.

### Arguments

| Argument | Description |
|----------|-------------|
| `ref_sv` | Path to the reference SystemVerilog file (`RefModule`) |
| `--dut-sv` | Path to the DUT SystemVerilog file (`TopModule`) |
| `--dut-cc` | Path to the CXXRTL C++ implementation |
| `--dut-py` | Path to the Python implementation |
| `--json` | JSON file describing ports (alternative to parsing ref.sv) |
| `-w, --work-dir` | Working directory for build artifacts (default: `work`) |

### Examples

```bash
# All three DUTs
python main.py ref.sv --dut-sv dut.sv --dut-cc dut.cc --dut-py dut.py

# Only Verilog DUT
python main.py ref.sv --dut-sv dut.sv

# CXXRTL + Python
python main.py ref.sv --dut-cc dut.cc --dut-py dut.py

# With JSON port description
python main.py ref.sv --dut-sv dut.sv --json ports.json
```

### Programmatic API

```python
from src.run_verification import run_verification

ret = run_verification(
    ref_sv="ref.sv",
    dut_sv="dut.sv",
    dut_cc="dut.cc",
    dut_py="dut.py",
    work_dir="build"
)
# ret == 0: all DUTs pass, ret == 1: at least one mismatch
```

### TODO
- [ ] Support SystemC.
- [ ] Support Rust.
- [x] Support not self-contained verilog code.
