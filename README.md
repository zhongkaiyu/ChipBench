# Install

```
docker build -t verilogeval:v2 .
docker run -it --name your-perfect-dokcer-name -v $(pwd):/workspace/verilogeval verilogeval:v2
```

# Contact  

If you have any questions or would like further information, please feel free to contact us at mailto:zhy055@ucsd.edu and mailto:cz2791@columbia.edu You can also visit our homepages for more details about our work: Zhongkai Yuhttps://zhongkaiyu.github.io/ and Chenyang Zhou – https://chz05.github.io/ Chenyang Zhou is currently looking for PhD opportunities.

# Overview

This repository provides an **end-to-end evaluation framework** that spans Verilog generation, Verilog debugging, reference model generation, and utility tooling. Conceptually, it is organized into four main components:

- **Verilog Gen**: datasets for generating Verilog designs with different structures and difficulty levels (self‑contain / non‑self‑contain / CPU IP).
- **Verilog Debugging**: buggy RTL variants and their associated `prompt.txt / ref.sv / test.sv` for 0‑shot and 1‑shot debugging tasks.
- **Ref Model Gen**: cross‑language functional reference models (Python / CXXRTL / SystemC) for the same set of problems.
- **Tool Box**: utilities for verification and data generation, such as cross‑language consistency checking and reference‑model‑based testbench generation.

Below we describe each component and its directory.

### Verilog Gen

Directory: `Verilog Gen/`

- **`dataset_self_contain/`**  
  - Each problem is a **self‑contained module** with a single top module (e.g., `TopModule`) and no external submodule dependencies.  
  - Contains **challenging combinational and sequential logic problems**, suitable for evaluating spec‑to‑RTL generation.

- **`dataset_not_self_contain/`**  
  - Each problem is a **non‑self‑contained design** where a `Top Module` instantiates multiple `Sub‑Module`s.  
  - Evaluates the model’s ability to handle hierarchical designs and module interfaces.

- **`dataset_cpu_ip/`**  
  - Contains more complex **CPU IP–level problems**, such as ALU, register file, branch, and control logic.  
  - Corresponds to the “CPU IP / ALU / Reg File / Branch / Control ...” region in the high‑level figure and targets high‑difficulty RTL generation.

### Verilog Debugging

Directory: `Verilog Debugging/`

Each subdirectory corresponds to a specific **debugging setting** (0‑shot / 1‑shot) and **bug type** (state machine / timing / arithmetic / assignment), matching the “Verilog Debugging” block in the figure.

- Bug types:
  - **Timing Bug**: timing‑related issues.
  - **Assignment Bug**: incorrect blocking / non‑blocking or combinational assignments.
  - **Arithmetic Bug**: incorrect arithmetic operations.
  - **State Machine Bug**: wrong state transitions or output logic.

- Shot settings:
  - `dataset_debug_zero_shot_*`: **0‑shot** debugging, without in‑context examples.
  - `dataset_debug_one_shot_*`: **1‑shot** debugging, with one in‑context example problem.

Typical file triplet for each problem:

- **`*_prompt.txt`**: prompt given to the LLM (natural language + code context) for generating or fixing Verilog.  
- **`*_ref.sv`**: reference Verilog implementation (bug‑free).  
- **`*_test.sv`**: testbench for automatic simulation and checking.  

For example, in `dataset_debug_one_shot_state_machine/`:

- `Prob003_non-overlapping_sequence_detect_prompt.txt`
- `Prob003_non-overlapping_sequence_detect_ref.sv`
- `Prob003_non-overlapping_sequence_detect_test.sv`

form a non‑overlapping sequence detector state‑machine debugging task.

### Ref Model Gen

Directory: `Ref Model Gen/`

This component generates **functional reference models**, corresponding to the “Ref Model Gen” block in the figure:

- **`gen.py`**: uses the specifications in `data.jsonl` to generate reference models in multiple backends (Python / CXXRTL / SystemC).  
- **`gen_python_prompt.txt` / `gen_cxxrtl_prompt.txt` / `gen_systemc_prompt.txt`**: prompt templates for each backend.  
- **`data.jsonl`**: unified description of problems and specifications.  
- **`key.cfg`**: sample API‑key configuration (do not commit real keys).  

Example generated reference models live under `Tool Box/`:

- `Tool Box/python/dut.py`
- `Tool Box/cxxrtl/dut.cc`
- `Tool Box/systemc/dut.cc`

These reference models can be used to cross‑check the Verilog designs.

### Tool Box

Directory: `Tool Box/`

This corresponds to the “Tool Box” block and mainly provides:

- **Cross‑language consistency checking**
  - `crosslang_verify.py`: verifies that multiple implementations (Python / CXXRTL / SystemC / Verilog) of the same task behave identically, and reports results.  
  - `verilog/`: contains `dut.sv` (design under test) and `ref.sv` (reference RTL).  
  - `python/`, `cxxrtl/`, `systemc/`: language‑specific reference models.

- **Testbench / data generation**
  - By combining the reference models and scripts, you can batch‑generate testbenches and training data for different problems.

### Scripts (Evaluation Entry Point)

Directory: `scripts/`

- `sv-generate`: unified **LLM Verilog generation / debugging** script.  
  - Supports multiple backends (OpenAI, DeepSeek, Gemini, Claude, Together, local vLLM server).  
  - `--task` selects the high‑level prompting style, e.g.:
    - `code-complete-iccad2023`: complete the body of `TopModule`.
    - `spec-to-rtl`: generate RTL directly from problem specification.  
  - `--examples` and `--rules` control few‑shot examples and coding conventions.  
- Other files such as `verilog-example-prefix_*.txt` and `prompt-example-prefix.txt` provide prefix examples for different tasks / shot settings.

---

## Usage

### Quick Start

```
mkdir -p build/
MODEL_NAME="gpt-5.2" # change this to your model
TASK_NAME="nowcoder" # change this to your task
./configure --with-model=$MODEL_NAME --with-task=$TASK_NAME
make
mkdir -p .save && mv Prob* .save/
```

### General usage:
The evalution harness is run using make and various evaluation parameters can be set as below:

```
mkdir -p build/
./configure  --with-task=$task --with-model=$model --with-examples=$shots --with-samples=$samples --with-temperature=$temperature --with-top-p=$top_p
make
```

Evaluation can be sped up by providing the `-j` flag to make, such as `-j4` to run 4 worker processes.

Valid models are listed at the top of `scripts/sv-generate`. The number of in-context learning examples can be between 0-4, and given with `--with-examples`. Samples to collect per problem are given by `--with-samples`. Finally, model temperature and top_p can be set to --with-temperature and --with-top-p, respectively.

These parameters can be easily swept with a shell script, to create separate build directories for each evaluation harness configuration target. 
