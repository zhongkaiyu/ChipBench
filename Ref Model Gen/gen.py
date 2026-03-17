#!/usr/bin/env python3
"""
Unified test generation script combining iterative_test.py and parallel_gen.py functionality.

Features:
- Read data from JSONL datasets
- Call DeepSeek API to generate Python code
- Run test verification
- Iterative repair (retry with error messages on failure)
- Resume from interruption
- Parallel processing
- Output CSV statistics and PDF charts
- Save passing cases to _passed.jsonl

Usage:
    python gen.py --input data.jsonl --samples 100 --turns 3
    python gen.py --input data.jsonl  # use all data, default 3 turns
"""

import argparse
import json
import random
import os
import re
import subprocess
import time
import threading
import requests
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Any
import csv
import matplotlib.pyplot as plt
import matplotlib
matplotlib.use('Agg')  # Use non-interactive backend
from concurrent.futures import ThreadPoolExecutor, as_completed

try:
    from tqdm import tqdm
    HAS_TQDM = True
except ImportError:
    HAS_TQDM = False

# ===================== Configuration =====================

DEEPSEEK_API_URL = "https://api.deepseek.com/v1/chat/completions"
MODEL_NAME = "deepseek-reasoner"

# Max concurrent threads
MAX_WORKERS = 24

# API call retries
MAX_RETRIES = 5
REQUEST_TIMEOUT = 180

# QPS control (dynamically adjusted based on number of keys)
KEY_COOLDOWN_SECONDS = 30

# Cost per million tokens (DeepSeek Reasoner pricing)
COST_INPUT_PER_MILLION = 0.55
COST_OUTPUT_PER_MILLION = 2.19

# ===================== Prompt =====================

SYSTEM_PROMPT = open("gen_python_prompt.txt", "r").read()

# ===================== Key Management =====================

@dataclass
class APIKey:
    key: str
    state: str = "ACTIVE"  # ACTIVE / COOLDOWN / DEAD
    cooldown_until: float = 0.0


class APIKeyPool:
    def __init__(self, keys: List[str]):
        self.keys = [APIKey(k) for k in keys]
        self.lock = threading.Lock()
        self.idx = 0

    def get_key(self) -> Optional[APIKey]:
        with self.lock:
            now = time.time()
            for _ in range(len(self.keys)):
                k = self.keys[self.idx]
                self.idx = (self.idx + 1) % len(self.keys)

                if k.state == "ACTIVE":
                    return k
                if k.state == "COOLDOWN" and now >= k.cooldown_until:
                    k.state = "ACTIVE"
                    return k
            return None

    def mark_dead(self, k: APIKey):
        with self.lock:
            if k.state != "DEAD":
                print(f"[KEY DEAD] {k.key[:8]}**** quota exhausted")
            k.state = "DEAD"

    def cooldown(self, k: APIKey, seconds: int):
        with self.lock:
            if k.state != "COOLDOWN":
                print(f"[KEY COOLDOWN] {k.key[:8]}**** {seconds}s")
            k.state = "COOLDOWN"
            k.cooldown_until = time.time() + seconds

    def has_active_key(self) -> bool:
        return any(k.state != "DEAD" for k in self.keys)

    def active_count(self) -> int:
        return sum(1 for k in self.keys if k.state != "DEAD")


def load_api_keys(config_path: str = "key.cfg") -> List[str]:
    """Load API keys from config file"""
    keys = []
    config_file = Path(config_path)
    
    if not config_file.exists():
        print(f"[ERROR] Key config file not found: {config_path}")
        print("Please create key.cfg with one API key per line")
        raise FileNotFoundError(f"Key config file not found: {config_path}")
    
    with open(config_file, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            # Skip empty lines and comments
            if line and not line.startswith('#'):
                keys.append(line)
    
    if not keys:
        raise ValueError("No API keys found in key.cfg")
    
    print(f"[INFO] Loaded {len(keys)} API keys from {config_path}")
    return keys


# ===================== QPS Limiter =====================

class QPSLimiter:
    def __init__(self, qps: int):
        self.interval = 1.0 / qps if qps > 0 else 1.0
        self.lock = threading.Lock()
        self.last_time = 0.0

    def wait(self):
        with self.lock:
            now = time.time()
            delta = now - self.last_time
            if delta < self.interval:
                time.sleep(self.interval - delta)
            self.last_time = time.time()

    def update_qps(self, qps: int):
        with self.lock:
            self.interval = 1.0 / qps if qps > 0 else 1.0


# ===================== Globals (initialized in main) =====================

key_pool: Optional[APIKeyPool] = None
qps_limiter: Optional[QPSLimiter] = None
write_lock = threading.Lock()
dir_lock = threading.Lock()

# ===================== Utility Functions =====================

def extract_python_code(content: str) -> str:
    """Extract Python code from markdown code blocks"""
    match = re.search(r'```(?:python)?\s*\n(.*?)```', content, re.DOTALL)
    if match:
        return match.group(1).strip()
    return content.strip()


def extract_ports_from_verilog(verilog_code: str):
    """Extract input/output port information from Verilog code"""
    verilog_code = re.sub(r'//[^\n]*', '', verilog_code)
    verilog_code = re.sub(r'/\*[\s\S]*?\*/', '', verilog_code)
    
    inputs = []
    outputs = []
    
    port_pattern = r'(input|output)\s*(?:reg|wire|logic)?\s*(?:\[([^\]]+)\])?\s*(\w+)'
    
    for match in re.finditer(port_pattern, verilog_code):
        direction = match.group(1)
        width_expr = match.group(2)
        name = match.group(3)
        
        if width_expr:
            parts = width_expr.split(':')
            if len(parts) == 2:
                try:
                    msb = eval(parts[0].strip())
                    lsb = eval(parts[1].strip())
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


def rename_module_to_refmodule(verilog_code: str) -> str:
    """Rename the module to RefModule"""
    module_name_match = re.search(r'module\s+(\w+)', verilog_code)
    if module_name_match:
        module_name = module_name_match.group(1)
        if module_name != 'RefModule':
            verilog_code = re.sub(
                r'module\s+' + re.escape(module_name),
                'module RefModule',
                verilog_code,
                count=1
            )
    return verilog_code


def save_log(log_dir: str, filename: str, content: str):
    """Save log file (thread-safe)"""
    with dir_lock:
        os.makedirs(log_dir, exist_ok=True)
    
    filepath = os.path.join(log_dir, filename)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)


def append_jsonl(path: str, obj: dict):
    """Append to JSONL file (thread-safe)"""
    with write_lock:
        with open(path, "a", encoding="utf-8") as f:
            f.write(json.dumps(obj, ensure_ascii=False) + "\n")


# ===================== API Calls =====================

def call_deepseek(system_prompt: str, user_prompt: str) -> dict:
    """
    Call DeepSeek API, return content and token usage.
    Returns: {"content": str, "prompt_tokens": int, "completion_tokens": int,
              "total_tokens": int, "reasoning_content": str}
    """
    global key_pool, qps_limiter
    
    for attempt in range(MAX_RETRIES):
        api_key = key_pool.get_key()
        if api_key is None:
            raise RuntimeError("No available API keys")

        try:
            qps_limiter.wait()

            headers = {
                "Authorization": f"Bearer {api_key.key}",
                "Content-Type": "application/json",
            }

            payload = {
                "model": MODEL_NAME,
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
                "stream": True,
            }

            resp = requests.post(
                DEEPSEEK_API_URL,
                headers=headers,
                json=payload,
                timeout=REQUEST_TIMEOUT,
                stream=True,
            )

            if resp.status_code == 200:
                reasoning_content = ""
                content = ""
                prompt_tokens = 0
                completion_tokens = 0
                
                for line in resp.iter_lines():
                    if not line:
                        continue
                    
                    line_str = line.decode('utf-8')
                    if line_str.startswith('data: '):
                        data_str = line_str[6:]
                        if data_str == '[DONE]':
                            break
                        
                        try:
                            data = json.loads(data_str)
                            delta = data.get("choices", [{}])[0].get("delta", {})
                            
                            if "reasoning_content" in delta and delta["reasoning_content"] is not None:
                                reasoning_content += str(delta["reasoning_content"])
                            
                            if "content" in delta and delta["content"] is not None:
                                content += str(delta["content"])
                            
                            usage = data.get("usage", {})
                            if usage:
                                prompt_tokens = usage.get("prompt_tokens", prompt_tokens)
                                completion_tokens = usage.get("completion_tokens", completion_tokens)
                                
                        except json.JSONDecodeError:
                            continue
                        except Exception:
                            continue
                
                return {
                    "content": content or "",
                    "reasoning_content": reasoning_content or "",
                    "prompt_tokens": prompt_tokens,
                    "completion_tokens": completion_tokens,
                    "total_tokens": prompt_tokens + completion_tokens,
                }

            if resp.status_code == 402 or "insufficient_quota" in resp.text:
                key_pool.mark_dead(api_key)
                raise RuntimeError("Quota exhausted")

            if resp.status_code == 429:
                key_pool.cooldown(api_key, KEY_COOLDOWN_SECONDS)
                raise RuntimeError("Rate limited")

            if resp.status_code >= 500:
                raise RuntimeError(f"Server error {resp.status_code}")

            resp.raise_for_status()

        except Exception as e:
            if attempt == MAX_RETRIES - 1:
                raise
            time.sleep(2 ** attempt)


# ===================== Test Functions =====================

def run_test_detailed(entry_data: dict, python_code: str, work_dir: str):
    """
    Run test and return detailed error information.
    Returns: (success: bool, error_details: dict)
    """
    import sys
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from test_sft_python import generate_testbench_ref_vs_python
    
    problem_id = entry_data.get('problem_id', 'unknown')
    entry_work_dir = os.path.join(work_dir, f"problem_{problem_id}")
    
    with dir_lock:
        os.makedirs(entry_work_dir, exist_ok=True)

    error_details = {
        "error_type": None,
        "error_message": "",
        "stdout": "",
        "stderr": "",
        "test_log": "",
        "mismatch_details": []
    }

    try:
        # Extract ground truth (Verilog)
        gt = entry_data.get('ground_truth', [])
        if not gt:
            error_details["error_type"] = "NO_GROUND_TRUTH"
            error_details["error_message"] = "No ground_truth found in entry"
            return False, error_details
        
        verilog_code = gt[0].get('content', '')
        if not verilog_code.strip():
            error_details["error_type"] = "EMPTY_GROUND_TRUTH"
            error_details["error_message"] = "Empty ground_truth content"
            return False, error_details
        
        verilog_code = rename_module_to_refmodule(verilog_code)
        
        # Check if Python code is valid
        if not python_code or not python_code.strip():
            error_details["error_type"] = "EMPTY_PYTHON_CODE"
            error_details["error_message"] = "Empty or invalid Python code generated"
            return False, error_details
        
        # Check if TopModule class is present
        if 'class TopModule' not in python_code:
            error_details["error_type"] = "MISSING_TOPMODULE"
            error_details["error_message"] = "Generated code does not contain 'class TopModule'"
            return False, error_details
        
        # Extract ports
        inputs, outputs = extract_ports_from_verilog(verilog_code)
        if not inputs and not outputs:
            error_details["error_type"] = "NO_PORTS"
            error_details["error_message"] = "Could not extract ports from Verilog"
            return False, error_details
        
        # Write files
        ref_sv_path = os.path.join(entry_work_dir, "ref.sv")
        dut_py_path = os.path.join(entry_work_dir, "dut.py")
        
        with open(ref_sv_path, 'w') as f:
            f.write(verilog_code)
        
        with open(dut_py_path, 'w') as f:
            f.write(python_code)
        
        # Syntax-check the Python code
        try:
            compile(python_code, '<string>', 'exec')
        except SyntaxError as e:
            error_details["error_type"] = "PYTHON_SYNTAX_ERROR"
            error_details["error_message"] = f"Python syntax error at line {e.lineno}: {e.msg}"
            return False, error_details
        
        # Generate testbench
        tb_code = generate_testbench_ref_vs_python(inputs, outputs, "dut")
        tb_path = os.path.join(entry_work_dir, "testbench.cpp")
        with open(tb_path, 'w') as f:
            f.write(tb_code)
        
        # Compile RefModule
        verilator_cmd = [
            "verilator", "--cc", "ref.sv",
            "--top-module", "RefModule",
            "--prefix", "VRefModule",
            "--exe", "testbench.cpp",
            "-CFLAGS", "-std=c++14",
            "-Wno-fatal", "-Wno-WIDTH", "-Wno-UNUSED",
            "-Wno-UNDRIVEN", "-Wno-UNOPTFLAT", "-Wno-DECLFILENAME",
            "-o", "sim"
        ]
        result = subprocess.run(verilator_cmd, capture_output=True, text=True, timeout=60, cwd=entry_work_dir)
        if result.returncode != 0:
            error_details["error_type"] = "VERILATOR_ERROR"
            error_details["error_message"] = f"Verilator compilation failed"
            error_details["stderr"] = result.stderr[:2000]
            error_details["stdout"] = result.stdout[:2000]
            return False, error_details
        
        # Build
        make_cmd = ["make", "-C", "obj_dir", "-f", "VRefModule.mk", "sim"]
        result = subprocess.run(make_cmd, capture_output=True, text=True, timeout=120, cwd=entry_work_dir)
        if result.returncode != 0:
            error_details["error_type"] = "MAKE_ERROR"
            error_details["error_message"] = f"Make compilation failed"
            error_details["stderr"] = result.stderr[:2000]
            error_details["stdout"] = result.stdout[:2000]
            return False, error_details
        
        # Run simulation
        result = subprocess.run(["./obj_dir/sim"], capture_output=True, text=True, timeout=300, cwd=entry_work_dir)
        
        error_details["stdout"] = result.stdout
        error_details["stderr"] = result.stderr
        
        # Read test log
        test_log_path = os.path.join(entry_work_dir, "test_log.txt")
        if os.path.exists(test_log_path):
            with open(test_log_path, 'r') as f:
                error_details["test_log"] = f.read()
        
        if result.returncode == 0:
            return True, error_details
        else:
            error_details["error_type"] = "TEST_MISMATCH"
            
            # Extract failed test cases from test_log
            failed_tests = []
            test_log = error_details.get("test_log", "")
            
            if test_log:
                current_test = []
                in_test = False
                
                for line in test_log.split('\n'):
                    if line.startswith('--- Test ') or line.startswith('--- Cycle '):
                        if current_test and any('FAIL' in l or 'MISMATCH' in l for l in current_test):
                            failed_tests.append('\n'.join(current_test))
                        current_test = [line]
                        in_test = True
                    elif in_test:
                        current_test.append(line)
                        if line.startswith('Result:'):
                            in_test = False
                
                if current_test and any('FAIL' in l or 'MISMATCH' in l for l in current_test):
                    failed_tests.append('\n'.join(current_test))
            
            error_details["mismatch_details"] = failed_tests[:10]
            
            if failed_tests:
                error_msg = f"Test failed. Found {len(failed_tests)} failing test cases.\n\n"
                error_msg += "First few failing test cases with inputs and outputs:\n"
                error_msg += "="*50 + "\n"
                for i, test in enumerate(failed_tests[:5]):
                    error_msg += test + "\n" + "-"*50 + "\n"
                error_details["error_message"] = error_msg
            else:
                mismatch_lines = []
                for line in (result.stdout + result.stderr).split('\n'):
                    if 'MISMATCH' in line or 'MISSING' in line or 'ERROR' in line:
                        mismatch_lines.append(line.strip())
                if mismatch_lines:
                    error_details["error_message"] = "Test output mismatch:\n" + '\n'.join(mismatch_lines[:10])
                else:
                    error_details["error_message"] = f"Test failed with return code {result.returncode}"
            
            return False, error_details

    except subprocess.TimeoutExpired:
        error_details["error_type"] = "TIMEOUT"
        error_details["error_message"] = "Test execution timed out"
        return False, error_details
    except Exception as e:
        error_details["error_type"] = "EXCEPTION"
        error_details["error_message"] = f"Exception: {str(e)}"
        return False, error_details


# ===================== Main Processing Logic =====================

def process_one_case(entry_data: dict, turn_num: int, previous_errors: Optional[dict], log_dir: str):
    """
    Process one test case for a single turn.
    Returns: dict with keys: problem_id, success, python_code, tokens, error_details,
             user_prompt, api_response, reasoning_content
    """
    problem_id = entry_data.get('problem_id', 'unknown')
    
    result = {
        "problem_id": problem_id,
        "success": False,
        "python_code": "",
        "tokens": {"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0},
        "error_details": {},
        "user_prompt": "",
        "api_response": "",
        "reasoning_content": ""
    }
    
    # Build user prompt
    user_content = None
    for m in entry_data.get("question", []):
        if m.get("role") == "user":
            user_content = m.get("content", "")
            # Replace Verilog references with Python
            user_content = user_content.replace("SystemVerilog", "Python")
            user_content = user_content.replace("systemverilog", "python")
            user_content = user_content.replace("Verilog", "Python")
            user_content = user_content.replace("verilog", "python")
            break
    
    if not user_content:
        result["error_details"] = {"error_type": "NO_USER_CONTENT", "error_message": "No user content in question"}
        return result
    
    # For turn 2+, append previous error information
    if turn_num > 1 and previous_errors:
        prev_code = previous_errors.get('code', '')
        prev_error = previous_errors.get('error', '')
        prev_details = previous_errors.get('error_details', {})
        
        error_prompt = f"\n\n" + "="*60 + "\n"
        error_prompt += f"PREVIOUS ATTEMPT (Turn {turn_num-1}) FAILED\n"
        error_prompt += "="*60 + "\n\n"
        
        error_prompt += f"**Error Type:** {prev_details.get('error_type', 'UNKNOWN')}\n\n"
        error_prompt += f"**Error Message:**\n{prev_error}\n\n"
        
        if prev_details.get('mismatch_details'):
            error_prompt += "**Mismatch Details:**\n```\n"
            error_prompt += '\n'.join(prev_details['mismatch_details'][:10])
            error_prompt += "\n```\n\n"
        
        error_prompt += f"**Previous Code:**\n```python\n{prev_code}\n```\n\n"
        error_prompt += "Please analyze the errors and generate a corrected version of the Python code."
        
        user_content = user_content + error_prompt
    
    result["user_prompt"] = user_content
    
    # Call API
    try:
        api_result = call_deepseek(SYSTEM_PROMPT, user_content)
        result["api_response"] = api_result.get("content", "")
        result["reasoning_content"] = api_result.get("reasoning_content", "")
        result["tokens"] = {
            "prompt_tokens": api_result.get("prompt_tokens", 0),
            "completion_tokens": api_result.get("completion_tokens", 0),
            "total_tokens": api_result.get("total_tokens", 0)
        }
        
        python_code = extract_python_code(api_result["content"])
        result["python_code"] = python_code
        
        if not python_code:
            result["error_details"] = {"error_type": "NO_CODE_EXTRACTED", "error_message": "Could not extract Python code from API response"}
            return result
        
        # Run test
        work_dir = os.path.join(log_dir, f"turn_{turn_num}")
        success, error_details = run_test_detailed(entry_data, python_code, work_dir)
        
        result["success"] = success
        result["error_details"] = error_details
        
        return result
        
    except Exception as e:
        result["error_details"] = {"error_type": "API_ERROR", "error_message": f"API error: {str(e)}"}
        return result


def save_turn_logs(turn_num: int, problem_id: str, result: dict, log_dir: str):
    """Save detailed logs for each API call"""
    problem_log_dir = os.path.join(log_dir, f"turn_{turn_num}", f"problem_{problem_id}")
    
    with dir_lock:
        os.makedirs(problem_log_dir, exist_ok=True)
    
    save_log(problem_log_dir, "prompt.txt", result.get("user_prompt", ""))
    save_log(problem_log_dir, "response.txt", result.get("api_response", ""))
    
    if result.get("reasoning_content"):
        save_log(problem_log_dir, "reasoning.txt", result.get("reasoning_content", ""))
    
    save_log(problem_log_dir, "generated_code.py", result.get("python_code", ""))
    
    error_details = result.get("error_details", {})
    error_log = f"""Error Type: {error_details.get('error_type', 'N/A')}
Error Message: {error_details.get('error_message', 'N/A')}

Tokens Used:
  - Prompt: {result.get('tokens', {}).get('prompt_tokens', 0)}
  - Completion: {result.get('tokens', {}).get('completion_tokens', 0)}
  - Total: {result.get('tokens', {}).get('total_tokens', 0)}

Success: {result.get('success', False)}

--- STDOUT ---
{error_details.get('stdout', '')}

--- STDERR ---
{error_details.get('stderr', '')}

--- MISMATCH DETAILS ---
{chr(10).join(error_details.get('mismatch_details', []))}

--- TEST LOG ---
{error_details.get('test_log', '')}
"""
    save_log(problem_log_dir, "result.txt", error_log)
    
    json_result = {
        "problem_id": problem_id,
        "turn": turn_num,
        "success": result.get("success", False),
        "tokens": result.get("tokens", {}),
        "error_type": error_details.get("error_type"),
        "error_message": error_details.get("error_message"),
    }
    save_log(problem_log_dir, "result.json", json.dumps(json_result, indent=2, ensure_ascii=False))


def load_done_ids(path: str) -> set:
    """Load completed problem IDs (for resume support)"""
    done = set()
    if not Path(path).exists():
        return done
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            try:
                data = json.loads(line)
                done.add(data.get("problem_id"))
            except Exception:
                pass
    return done


def load_case_states(path: str) -> dict:
    """Load case states (for resume support)"""
    if Path(path).exists():
        with open(path, 'r', encoding='utf-8') as f:
            return json.load(f)
    return {}


def main():
    parser = argparse.ArgumentParser(description='Generate and test Python DUT implementations')
    parser.add_argument('--input', '-i', required=True, help='Input JSONL file')
    parser.add_argument('--samples', '-s', type=int, default=None, help='Number of samples (default: all)')
    parser.add_argument('--turns', '-t', type=int, default=3, help='Max turns for iterative fixing (default: 3)')
    parser.add_argument('--output-dir', '-o', default=None, help='Output directory (default: based on input filename)')
    parser.add_argument('--key-config', '-k', default='key.cfg', help='API key config file (default: key.cfg)')
    parser.add_argument('--workers', '-w', type=int, default=MAX_WORKERS, help=f'Max parallel workers (default: {MAX_WORKERS})')
    parser.add_argument('--seed', type=int, default=42, help='Random seed for sampling (default: 42)')
    parser.add_argument('--resume', action='store_true', help='Resume from previous run')
    
    args = parser.parse_args()
    
    # Set random seed
    random.seed(args.seed)
    
    # Load API keys
    global key_pool, qps_limiter
    api_keys = load_api_keys(args.key_config)
    key_pool = APIKeyPool(api_keys)
    qps_limiter = QPSLimiter(len(api_keys))  # QPS = number of keys
    
    # Set up output directory and filenames
    input_path = Path(args.input)
    input_stem = input_path.stem
    
    if args.output_dir:
        output_dir = args.output_dir
    else:
        output_dir = f"{input_stem}_output"
    
    os.makedirs(output_dir, exist_ok=True)
    
    log_dir = os.path.join(output_dir, "logs")
    output_csv = os.path.join(output_dir, f"{input_stem}_results.csv")
    output_pdf = os.path.join(output_dir, f"{input_stem}_results.pdf")
    passed_jsonl = os.path.join(output_dir, f"{input_stem}_passed.jsonl")
    states_file = os.path.join(output_dir, "case_states.json")
    progress_file = os.path.join(output_dir, "progress.json")
    
    os.makedirs(log_dir, exist_ok=True)
    
    # Read input data
    all_data = []
    with open(args.input, 'r', encoding='utf-8') as f:
        for line in f:
            if line.strip():
                all_data.append(json.loads(line))
    
    print(f"[INFO] Loaded {len(all_data)} entries from {args.input}")
    
    # Sample
    if args.samples and args.samples < len(all_data):
        cases = random.sample(all_data, args.samples)
        print(f"[INFO] Sampled {len(cases)} entries")
    else:
        cases = all_data
        print(f"[INFO] Using all {len(cases)} entries")
    
    # Resume from checkpoint
    case_states = {}
    start_turn = 1
    
    if args.resume:
        # Load already-passed problem IDs
        passed_ids = load_done_ids(passed_jsonl)
        print(f"[INFO] Found {len(passed_ids)} already passed cases")
        
        # Load case states
        case_states = load_case_states(states_file)
        
        # Load progress
        if Path(progress_file).exists():
            with open(progress_file, 'r') as f:
                progress = json.load(f)
                start_turn = progress.get('next_turn', 1)
                print(f"[INFO] Resuming from turn {start_turn}")
    
    # Statistics
    total_passed = sum(1 for pid, state in case_states.items() if state.get('passed', False))
    total_cost = sum(state.get('total_cost', 0) for state in case_states.values())
    turn_stats = []
    
    # Iterative processing
    max_turns = args.turns
    
    for turn in range(start_turn, max_turns + 1):
        print(f"\n{'='*60}")
        print(f"Turn {turn}/{max_turns}")
        print(f"{'='*60}")
        
        # Get cases that still need processing
        active_cases = [
            case for case in cases
            if case.get('problem_id') not in case_states or not case_states[case.get('problem_id')].get('passed', False)
        ]
        
        if not active_cases:
            print("All cases passed!")
            break
        
        print(f"Processing {len(active_cases)} cases in parallel (max workers: {args.workers})...")
        
        turn_prompt_tokens = 0
        turn_completion_tokens = 0
        turn_passed_this_turn = 0
        
        def process_case(case):
            problem_id = case.get('problem_id', 'unknown')
            
            previous_errors = None
            if problem_id in case_states and case_states[problem_id].get('errors'):
                previous_errors = case_states[problem_id]['errors'][-1]
            
            result = process_one_case(case, turn, previous_errors, log_dir)
            save_turn_logs(turn, problem_id, result, log_dir)
            
            return result, case
        
        results = []
        turn_pass_count = 0
        turn_fail_count = 0
        
        with ThreadPoolExecutor(max_workers=args.workers) as executor:
            futures = {executor.submit(process_case, case): case for case in active_cases}
            
            if HAS_TQDM:
                pbar = tqdm(as_completed(futures), total=len(futures), desc=f"Turn {turn}", unit="case")
                pbar.set_postfix({"pass": 0, "fail": 0, "rate": "0.0%"})
            else:
                pbar = as_completed(futures)
            
            for future in pbar:
                try:
                    result, original_case = future.result()
                    results.append((result, original_case))
                    
                    if result.get("success", False):
                        turn_pass_count += 1
                    else:
                        turn_fail_count += 1
                    
                    if HAS_TQDM:
                        completed = turn_pass_count + turn_fail_count
                        rate = turn_pass_count / completed * 100 if completed > 0 else 0
                        pbar.set_postfix({
                            "pass": turn_pass_count,
                            "fail": turn_fail_count,
                            "rate": f"{rate:.1f}%"
                        })
                    
                    if not key_pool.has_active_key():
                        print("[FATAL] All API keys exhausted. Stop.")
                        break
                        
                except Exception as e:
                    turn_fail_count += 1
                    print(f"[ERROR] Exception: {e}")
        
        # Update statistics
        for result, original_case in results:
            problem_id = result["problem_id"]
            
            turn_prompt_tokens += result["tokens"].get("prompt_tokens", 0)
            turn_completion_tokens += result["tokens"].get("completion_tokens", 0)
            
            if problem_id not in case_states:
                case_states[problem_id] = {
                    'turn': turn,
                    'passed': False,
                    'code': '',
                    'errors': [],
                    'total_cost': 0
                }
            
            # Calculate cost for this call
            call_cost = (
                result["tokens"].get("prompt_tokens", 0) / 1_000_000 * COST_INPUT_PER_MILLION +
                result["tokens"].get("completion_tokens", 0) / 1_000_000 * COST_OUTPUT_PER_MILLION
            )
            case_states[problem_id]['total_cost'] = case_states[problem_id].get('total_cost', 0) + call_cost
            
            if result["success"]:
                if not case_states[problem_id]['passed']:
                    total_passed += 1
                    turn_passed_this_turn += 1
                case_states[problem_id]['passed'] = True
                case_states[problem_id]['code'] = result["python_code"]
                case_states[problem_id]['passed_turn'] = turn
                
                # Save passing cases to _passed.jsonl
                passed_entry = original_case.copy()
                passed_entry['generated_python'] = result["python_code"]
                passed_entry['reasoning_content'] = result.get("reasoning_content", "")
                passed_entry['passed_at_turn'] = turn
                passed_entry['tokens_used'] = result["tokens"]
                append_jsonl(passed_jsonl, passed_entry)
            else:
                case_states[problem_id]['code'] = result["python_code"]
                error_msg = result["error_details"].get("error_message", "Unknown error")
                case_states[problem_id]['errors'].append({
                    'turn': turn,
                    'code': result["python_code"],
                    'error': error_msg,
                    'error_details': result["error_details"]
                })
        
        # Calculate cost for this turn
        turn_cost = (
            turn_prompt_tokens / 1_000_000 * COST_INPUT_PER_MILLION +
            turn_completion_tokens / 1_000_000 * COST_OUTPUT_PER_MILLION
        )
        total_cost += turn_cost
        
        pass_rate = total_passed / len(cases) * 100
        
        turn_stats.append({
            'turn': turn,
            'total_pass': total_passed,
            'total_cost': total_cost,
            'pass_rate': pass_rate,
            'cost_per_case': total_cost / total_passed if total_passed > 0 else 0,
            'turn_prompt_tokens': turn_prompt_tokens,
            'turn_completion_tokens': turn_completion_tokens,
            'turn_passed': turn_passed_this_turn
        })
        
        print(f"\nTurn {turn} Summary:")
        print(f"  Passed this turn: {turn_passed_this_turn}")
        print(f"  Total passed: {total_passed}/{len(cases)} ({pass_rate:.2f}%)")
        print(f"  Turn tokens: prompt={turn_prompt_tokens}, completion={turn_completion_tokens}")
        print(f"  Turn cost: ${turn_cost:.4f}")
        print(f"  Total cost: ${total_cost:.4f}")
        if total_passed > 0:
            print(f"  Cost per pass: ${total_cost/total_passed:.4f}")
        
        # Save progress (for resume support)
        with open(states_file, 'w', encoding='utf-8') as f:
            json.dump(case_states, f, indent=2, ensure_ascii=False)
        
        with open(progress_file, 'w', encoding='utf-8') as f:
            json.dump({'next_turn': turn + 1, 'total_passed': total_passed, 'total_cost': total_cost}, f)
        
        if total_passed == len(cases):
            print("\nAll cases passed!")
            break
        
        if not key_pool.has_active_key():
            print("\n[FATAL] All API keys exhausted. Stopping.")
            break
    
    # Output CSV
    print(f"\nWriting results to {output_csv}...")
    with open(output_csv, 'w', newline='', encoding='utf-8') as f:
        fieldnames = ['turn', 'total_pass', 'pass_rate', 'total_cost', 'cost_per_case', 
                      'turn_prompt_tokens', 'turn_completion_tokens', 'turn_passed']
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for stat in turn_stats:
            writer.writerow(stat)
    
    # Save final case states
    with open(states_file, 'w', encoding='utf-8') as f:
        json.dump(case_states, f, indent=2, ensure_ascii=False)
    
    # Generate summary table
    summary_csv = os.path.join(output_dir, f"{input_stem}_summary.csv")
    with open(summary_csv, 'w', newline='', encoding='utf-8') as f:
        fieldnames = ['problem_id', 'passed', 'passed_turn', 'total_cost', 'error_type']
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for pid, state in case_states.items():
            last_error_type = ''
            if state.get('errors'):
                last_error_type = state['errors'][-1].get('error_details', {}).get('error_type', '')
            writer.writerow({
                'problem_id': pid,
                'passed': state.get('passed', False),
                'passed_turn': state.get('passed_turn', ''),
                'total_cost': f"{state.get('total_cost', 0):.6f}",
                'error_type': last_error_type if not state.get('passed') else ''
            })
    
    # Plot charts
    if turn_stats:
        print(f"Generating plot to {output_pdf}...")
        fig, ax1 = plt.subplots(figsize=(12, 6))
        
        turns = [s['turn'] for s in turn_stats]
        pass_rates = [s['pass_rate'] for s in turn_stats]
        costs_per_case = [s['cost_per_case'] for s in turn_stats]
        
        color1 = 'tab:blue'
        ax1.set_xlabel('Turn Number', fontsize=12)
        ax1.set_ylabel('Pass Rate (%)', color=color1, fontsize=12)
        line1 = ax1.plot(turns, pass_rates, 'o-', color=color1, linewidth=2, markersize=8, label='Pass Rate')
        ax1.tick_params(axis='y', labelcolor=color1)
        ax1.set_ylim([0, 105])
        ax1.grid(True, alpha=0.3)
        ax1.set_xticks(turns)
        
        ax2 = ax1.twinx()
        color2 = 'tab:red'
        ax2.set_ylabel('Cost per Pass ($)', color=color2, fontsize=12)
        line2 = ax2.plot(turns, costs_per_case, 's-', color=color2, linewidth=2, markersize=8, label='Cost per Pass')
        ax2.tick_params(axis='y', labelcolor=color2)
        
        lines = line1 + line2
        labels = [l.get_label() for l in lines]
        ax1.legend(lines, labels, loc='center right')
        
        ax1.set_title(f'Iterative Test Results ({len(cases)} cases)\nFinal Pass Rate: {pass_rates[-1]:.1f}%, Total Cost: ${total_cost:.2f}', fontsize=14)
        fig.tight_layout()
        plt.savefig(output_pdf, format='pdf', dpi=300, bbox_inches='tight')
        plt.close()
    
    print(f"\nDone!")
    print(f"  Output directory: {output_dir}")
    print(f"  CSV results: {output_csv}")
    print(f"  Summary CSV: {summary_csv}")
    print(f"  PDF plot: {output_pdf}")
    print(f"  Passed cases: {passed_jsonl}")
    print(f"  Detailed logs: {log_dir}/")
    print(f"  Case states: {states_file}")
    print(f"\nFinal Statistics:")
    print(f"  Total cases: {len(cases)}")
    print(f"  Passed: {total_passed} ({total_passed/len(cases)*100:.2f}%)")
    print(f"  Failed: {len(cases) - total_passed}")
    print(f"  Total cost: ${total_cost:.4f}")


if __name__ == "__main__":
    main()

