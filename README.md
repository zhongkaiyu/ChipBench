# Install

```
docker build -t verilogeval:v2 .
docker run -it --name your-perfect-dokcer-name -v $(pwd):/workspace/verilogeval verilogeval:v2
```

# Contact  

If you have any questions or would like further information, please feel free to contact us at 
<a href="mailto:zhy055@ucsd.edu">zhy055@ucsd.edu</a> and 
<a href="mailto:cz2791@columbia.edu">cz2791@columbia.edu</a>. 
You can also visit our homepages for more details about our work: 
<a href="https://zhongkaiyu.github.io/" target="_blank">Zhongkai Yu</a> and 
<a href="https://chz05.github.io/" target="_blank">Chenyang Zhou</a>. 

# Overview

This repository provides an **end-to-end evaluation framework** that spans Verilog generation, Verilog debugging, reference model generation, and utility tooling. Conceptually, it is organized into four main components:

- **Verilog Gen**: datasets for generating Verilog designs with different structures and difficulty levels (self‑contain / non‑self‑contain / CPU IP).
- **Verilog Debugging**: buggy RTL variants and their associated `prompt.txt / ref.sv / test.sv` for 0‑shot and 1‑shot debugging tasks.
- **Ref Model Gen**: cross‑language functional reference models (Python / CXXRTL / SystemC) for the same set of problems.
- **Tool Box**: utilities for verification and data generation, such as cross‑language consistency checking and reference‑model‑based testbench generation.


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
