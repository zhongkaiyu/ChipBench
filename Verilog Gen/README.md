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
