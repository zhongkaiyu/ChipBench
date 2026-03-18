#!/usr/bin/env python3
"""
Cross-Language Verification CLI.

Compare a golden-reference Verilog model against any combination of DUT implementations.

Examples:
    # All three DUTs
    python main.py ref.sv --dut-sv dut.sv --dut-cc dut.cc --dut-py dut.py

    # Only Verilog DUT
    python main.py ref.sv --dut-sv dut.sv

    # Only CXXRTL + Python
    python main.py ref.sv --dut-cc dut.cc --dut-py dut.py

    # With JSON port description instead of parsing ref.sv
    python main.py ref.sv --dut-sv dut.sv --json ports.json

Module naming conventions:
    ref.sv:  module RefModule
    dut.sv:  module TopModule (can contain multiple modules)
    dut.cc:  cxxrtl_design::p_TopModule
    dut.py:  class TopModule with eval() method (can contain multiple classes)
"""

import sys
import os
import argparse

from src.run_verification import run_verification


def main():
    parser = argparse.ArgumentParser(
        description="Cross-Language Verification",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("ref_sv", help="Golden reference Verilog (module RefModule)")
    parser.add_argument("--dut-sv", help="DUT Verilog file (module TopModule)")
    parser.add_argument("--dut-cc", help="CXXRTL C++ file")
    parser.add_argument("--dut-py", help="Python DUT file (class TopModule)")
    parser.add_argument("--json", help="JSON port description (alternative to parsing ref.sv)")
    parser.add_argument("-w", "--work-dir", default="work", help="Working directory (default: work)")

    args = parser.parse_args()

    # Validate all provided files exist
    for path in filter(None, [args.ref_sv, args.dut_sv, args.dut_cc, args.dut_py, args.json]):
        if not os.path.exists(path):
            print(f"Error: file not found: {path}")
            sys.exit(1)

    ret = run_verification(
        ref_sv=args.ref_sv,
        dut_sv=args.dut_sv,
        dut_cc=args.dut_cc,
        dut_py=args.dut_py,
        json_file=args.json,
        work_dir=args.work_dir,
    )
    sys.exit(ret)


if __name__ == "__main__":
    main()
