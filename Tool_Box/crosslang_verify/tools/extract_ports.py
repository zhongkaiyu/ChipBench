import re
import json


def extract_ports_from_verilog(verilog_path):
    """Extract ports from Verilog. Returns (inputs, outputs) as [(name, width)]."""
    with open(verilog_path, 'r') as f:
        code = f.read()

    # Strip single-line and multi-line comments
    code = re.sub(r'//.*?$|/\*.*?\*/', '', code, flags=re.DOTALL | re.MULTILINE)

    inputs, outputs = [], []

    for line in code.splitlines():
        line = line.strip().rstrip(',')
        m = re.match(r'(input|output)\s+(?:reg|wire|logic)?\s*(?:\[(\d+):(\d+)\])?\s*(\w+)', line)
        if not m:
            continue
        direction, msb, lsb, name = m.groups()
        width = abs(int(msb) - int(lsb)) + 1 if msb is not None else 1
        (inputs if direction == 'input' else outputs).append((name, width))

    return inputs, outputs

def extract_ports_from_json(json_path):
    """Extract ports from JSON. Returns (inputs, outputs) as [(name, width)]."""
    with open(json_path, 'r') as f:
        data = json.load(f)

    inputs = [(port['name'], port['width']) for port in data.get('inputs', [])]
    outputs = [(port['name'], port['width']) for port in data.get('outputs', [])]

    return inputs, outputs
