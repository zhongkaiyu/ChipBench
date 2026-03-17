# Tool Box

Cross‑language verification utilities for checking that multiple implementations of the same hardware design (SystemVerilog, Python, CXXRTL) produce identical results.

## Directory Structure

```
Tool Box/
├── crosslang_verify.py      # Main verification script
├── README.md
├── verilog/
│   ├── ref.sv               # Reference SystemVerilog (module RefModule)
│   └── dut.sv               # Design under test (module TopModule)
├── python/
│   └── dut.py               # Python reference model
├── cxxrtl/
│   └── dut.cc               # CXXRTL C++ reference model
└── systemc/
    └── dut.cc               # SystemC reference model (placeholder)
```

## Supported Languages

| Language | File | Notes |
|----------|------|-------|
| SystemVerilog (reference) | `verilog/ref.sv` | Golden reference, module name must be `RefModule` |
| SystemVerilog (DUT) | `verilog/dut.sv` | Device under test, module name must be `TopModule` |
| CXXRTL (C++) | `cxxrtl/dut.cc` | Struct name must be `p_TopModule` |
| Python | `python/dut.py` | Must export a `TopModule` class with an `eval(inputs_dict)` method |

> **Note:** SystemC support is planned for the future but is not yet wired into the verification flow. Rust and other high‑level languages may be added later.

## How `crosslang_verify.py` Works

The script automates an end‑to‑end comparison across all supported implementations:

```
Extract inputs / outputs from Verilog
            │
            ▼
Generate testbench (1000 random test vectors)
            │
            ▼
Run Verilator to simulate & compare results
```

### Step 1 — Port Extraction

`crosslang_verify.py` parses the SystemVerilog source files to automatically extract input and output port declarations (names, widths, directions). It supports arbitrary bit widths, including signals wider than 64 bits.

### Step 2 — Testbench Generation

A C++ testbench (`testbench.cpp`) is auto‑generated that:

- Instantiates all four models (RefModule via Verilator, TopModule via Verilator, CXXRTL `p_TopModule`, and the Python `TopModule`).
- Drives them with the **same random inputs** using a fixed seed (`12345`) for reproducibility.
- For **combinational** circuits: applies 1000 random input vectors.
- For **sequential** circuits: runs 500 clock cycles with proper reset handling.

### Step 3 — Simulation & Comparison

The testbench is compiled and run via Verilator + YOSYS (for CXXRTL). Outputs from all implementations are compared cycle‑by‑cycle; the first 10 mismatches are reported.

## Limitations

- The testbench **only supports the rising edge of clock** for sequential circuits.
- Currently only **SystemVerilog, Python, and CXXRTL** are fully integrated; SystemC is not yet supported in the verification flow.

## Usage

```bash
python crosslang_verify.py verilog/ref.sv verilog/dut.sv cxxrtl/dut.cc python/dut.py [--work-dir work]
```

### Arguments

| Argument | Description |
|----------|-------------|
| `ref.sv` | Path to the reference SystemVerilog file (`RefModule`) |
| `dut.sv` | Path to the DUT SystemVerilog file (`TopModule`) |
| `dut.cc` | Path to the CXXRTL C++ implementation |
| `dut.py` | Path to the Python implementation |
| `--work-dir` | Working directory for build artifacts (default: `work`) |

