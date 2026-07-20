# Self-Contained Benchmark — Fixed Prompts

This directory adds the **self-contained** problem set for the ChipBench
benchmark, with corrected prompt text. Each problem is fully self-contained:
the prompt fully specifies the module interface and behavior, and ships
alongside its reference implementation and testbench.

## Contents

The set covers **30 problems** (`Prob000`–`Prob034`), each provided as three
files, plus an index:

| File pattern | Count | Description |
|---|---|---|
| `ProbNNN_<name>_prompt.txt` | 30 | Natural-language problem statement given to the model |
| `ProbNNN_<name>_ref.sv`     | 30 | Reference SystemVerilog implementation (`TopModule`) |
| `ProbNNN_<name>_test.sv`    | 30 | Self-checking testbench |
| `problems.txt`              | 1  | Index of the problems in this set |

Total: **91 files**.

## What was fixed

The purpose of this change is to correct **prompting issues** in the
self-contained category. The prompts were revised so that each one fully and
unambiguously specifies the target module — its interface (port names, widths,
reset polarity), timing behavior, and expected functionality — so that a model
can implement `TopModule` from the prompt alone without relying on the
reference or testbench.

The following **20 prompts** were revised:

- `Prob001_continuous_input_sequence_detect`
- `Prob002_extraneous_items_sequence_detect`
- `Prob003_non-overlapping_sequence_detect`
- `Prob004_continuous_input_sequence_detect2`
- `Prob008_non-integer_data_width_conversion_24to128`
- `Prob009_non-integer_data_width_conversion_8to12`
- `Prob010_integer_multiple_data_bit_width_conversion_8to16`
- `Prob012_state_machine_overlapping_sequence_detection`
- `Prob013_least_common_multiple`
- `Prob014_sequence_generator`
- `Prob015_vending_machine2`
- `Prob016_odd-number_division_with_a_duty_cycle_of_half`
- `Prob017_arbitrary_fractional_frequency_division`
- `Prob020_write_state_machine_two_stage`
- `Prob027_settable_counter`
- `Prob028_up_and_down_counter`
- `Prob030_simple_implementation_RAM`
- `Prob032_pipeline_multiplier`
- `Prob033_traffic_lights`
- `Prob034_gaming_machine_billing_program`

The remaining problems' reference implementations (`*_ref.sv`) and testbenches
(`*_test.sv`) are unchanged.
