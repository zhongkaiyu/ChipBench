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