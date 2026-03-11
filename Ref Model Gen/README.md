# Ref Model Gen

Cross-language functional reference model generation for ChipBench.

## Overview

This component generates **functional reference models** from hardware specifications using LLM APIs. Given a Verilog problem description, it produces equivalent implementations in multiple backends:

- **Python** (`gen_python_prompt.txt`) — Python class with `TopModule.eval()` interface
- **CXXRTL** (`gen_cxxrtl_prompt.txt`) — C++ using Yosys CXXRTL API (`cxxrtl_design::p_TopModule`)
- **SystemC** (`gen_systemc_prompt.txt`) — SystemC module (`SC_MODULE(TopModule)`)

## Files

| File | Description |
|------|-------------|
| `gen.py` | Main generation script — calls LLM API, runs tests, supports iterative fixing |
| `data.jsonl` | Input dataset with problem specifications and ground-truth Verilog |
| `gen_python_prompt.txt` | System prompt for Python reference model generation |
| `gen_cxxrtl_prompt.txt` | System prompt for CXXRTL C++ reference model generation |
| `gen_systemc_prompt.txt` | System prompt for SystemC reference model generation |
| `key.cfg` | API key configuration (one key per line, do not commit real keys) |

## Usage

```bash
# Generate Python reference models (default: 3 iterative turns)
python gen.py --input data.jsonl --samples 100 --turns 3

# Use all data with default settings
python gen.py --input data.jsonl

# Resume from a previous run
python gen.py --input data.jsonl --resume

# Customize parallelism and API keys
python gen.py --input data.jsonl --workers 8 --key-config my_keys.cfg
```

### Arguments

| Flag | Default | Description |
|------|---------|-------------|
| `--input, -i` | (required) | Input JSONL file |
| `--samples, -s` | all | Number of samples to process |
| `--turns, -t` | 3 | Max iterative fix turns |
| `--output-dir, -o` | `<input>_output/` | Output directory |
| `--key-config, -k` | `key.cfg` | API key config file |
| `--workers, -w` | 24 | Max parallel workers |
| `--seed` | 42 | Random seed for sampling |
| `--resume` | false | Resume from previous run |

## Output

Results are saved to `<input>_output/`:
- `*_results.csv` — per-turn pass rate and cost statistics
- `*_summary.csv` — per-problem pass/fail summary
- `*_passed.jsonl` — entries that passed verification
- `*_results.pdf` — pass rate and cost plot
- `logs/` — detailed per-turn, per-problem logs

## Verification

Generated reference models can be cross-checked against Verilog using the verification tools in `../Tool Box/`:
- `crosslang_verify.py` — compares Python, CXXRTL, and Verilog implementations
