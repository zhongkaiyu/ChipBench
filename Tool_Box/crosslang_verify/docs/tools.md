# tools/

Utility modules used by the testbench generator.

---

## extract_ports.py

Extracts input/output port information from hardware description files.

### `extract_ports_from_verilog(verilog_path) -> (inputs, outputs)`

Parses a Verilog/SystemVerilog file. Strips comments, matches `input`/`output` ports with optional `reg`/`wire`/`logic` qualifiers and `[MSB:LSB]` bit ranges.

### `extract_ports_from_json(json_path) -> (inputs, outputs)`

Reads a JSON file with `"inputs"` and `"outputs"` arrays, each entry having `"name"` and `"width"`.

Both return `(inputs, outputs)` as lists of `(name: str, width: int)` tuples.

---

## clk.py

### `is_clk_signal(inputs) -> bool`

Checks whether the first input signal name contains `"clk"` (case-insensitive). Determines sequential vs combinational.

---

## reset.py

### `is_reset_signal(name) -> (is_reset: bool, is_active_low: bool)`

Detects reset signals (`reset`, `rst`, `areset`, etc.) and their polarity.

### `is_active_low_reset(name) -> bool`

Active-low if starts with `n` or ends with `_n`, `_b`, `_l`.

---

## dut.py

DUT abstraction with two execution models:

- **Inline** (`is_batch=False`): set inputs, eval, compare inside the C++ loop
- **Batch** (`is_batch=True`): collect inputs during the loop, run + compare after

### `_mismatch_block(error_var, label, name, width, get_ref, get_dut) -> str`

Shared helper that generates a C++ comparison block for any width. Used by `VerilogDUT` and `CxxrtlDUT` to avoid duplicating comparison logic.

### Class: `DUT` (base class)

| Constructor arg | Description |
|---|---|
| `var_name` | C++ variable name (e.g. `"dut"`) |
| `error_var` | C++ error counter name (e.g. `"dut_errors"`) |
| `label` | Human-readable label (e.g. `"DUT"`, `"CXXRTL"`) |

| Method | Description |
|---|---|
| `include_code()` | C++ `#include` lines or constants |
| `init_code()` | C++ model instantiation |
| `clk_setter(name)` | C++ clock setter |
| `input_setter(name, width)` | C++ input setter (any width) |
| `eval_code()` | C++ model evaluation |
| `output_compare(name, width)` | C++ output comparison vs ref (any width) |
| `cleanup_code()` | C++ cleanup (e.g. `delete`) |
| `sequential_init()` | Extra C++ init for sequential circuits |
| `helper_code(is_sequential)` | C++ helper functions (emitted before `main`) |
| `post_loop_compare(is_sequential)` | Batch DUTs: C++ code after the main loop |

### Class: `VerilogDUT(DUT)` — inline

Verilator-compiled DUT (`VTopModule`). Pointer-based access, arbitrary signal widths.

### Class: `CxxrtlDUT(DUT)` — inline

CXXRTL-based DUT. Uses `.set()` / `.get<T>()`. Provides `value_to_string` / `wire_to_string` helpers.

| Constructor arg | Description |
|---|---|
| `cxxrtl_file` | CXXRTL `.cc` filename (default: `"dut.cc"`) |

| Static method | Description |
|---|---|
| `mangle(name)` | `sig_name` -> `p_sig__name` |

### Class: `PythonDUT(DUT)` — batch

Runs all inputs via subprocess in one batch. Provides `string_equals` / `call_python` helpers. Comparison in `post_loop_compare()`.

| Constructor arg | Description |
|---|---|
| `python_file` | Path to the Python `.py` file |

### Adding a new DUT language

**Inline** (compiled, linked — e.g. Rust):

1. Subclass `DUT` in `dut.py`
2. Implement: `include_code`, `init_code`, `input_setter`, `eval_code`, `output_compare`, `cleanup_code`
3. Add one line in `generate_testbench.py`

**Batch** (external execution — e.g. Julia):

1. Subclass `DUT` with `is_batch = True`
2. Implement: `include_code`, `helper_code`, `post_loop_compare`
3. Add one line in `generate_testbench.py`

---

## signal_gen.py

Unified C++ signal code generation. Each function handles **any width** (1-bit to 1000+ bits).

### `get_num_chunks(width) -> int`

Number of 32-bit chunks for a signal.

### `gen_declaration(name, width) -> str`

C++ variable declaration: `uint32_t` / `uint64_t` / `uint32_t[N]`.

### `gen_random(name, width) -> str`

C++ random assignment with proper masking.

### `gen_ref_setter(name, width) -> str`

C++ setter for the Verilator ref model.

### `gen_to_string(name, width, accessor=None) -> str`

C++ expression converting a signal to `std::string`. Used for both input variables and ref output values.

- `accessor=None`: uses `name` directly (e.g. `std::to_string(a)`)
- `accessor="ref->Q"`: uses the accessor (e.g. `std::to_string(ref->Q)`)

### `gen_reset_override(name, width, is_active_low, active) -> str`

C++ reset override. `active=True` for warmup (asserted), `active=False` for main phase (deasserted).

### `generate_signal_code(inputs, outputs, duts, reset_signals) -> dict`

Generates all signal-related C++ snippets. Only receives **inline DUTs**.

**Returns dict:**

| Key | Type | Description |
|---|---|---|
| `declarations` | `list[str]` | Variable declarations |
| `random_generators` | `list[str]` | Random assignments |
| `ref_setters` | `list[str]` | Ref model setters |
| `dut_setters` | `dict[DUT, list]` | Setters per inline DUT |
| `input_to_string` | `list[(name, expr)]` | For batch DUT input collection |
| `output_to_string` | `list[(name, expr)]` | For batch DUT output collection |
| `dut_checks` | `dict[DUT, list]` | Comparisons per inline DUT |
| `warmup_reset` | `list[str]` | Reset-active overrides |
| `fixed_reset` | `list[str]` | Reset-inactive overrides |

---

## cpp_helpers.py

C++ helper function text generators. Called by DUT classes via `helper_code()`.

### `gen_wide_to_string() -> str`

`wide_to_string()` — converts `std::vector<uint32_t>` to decimal string. Emitted when signals > 64 bits exist.

### `gen_string_equals() -> str`

`string_equals()` — compares decimal strings ignoring leading zeros. Used by `PythonDUT`.

### `gen_value_to_string() -> str`

`value_to_string<Bits>()` and `wire_to_string<Bits>()` — CXXRTL value to string. Used by `CxxrtlDUT`.

### `gen_call_python(is_sequential) -> str`

`call_python_batch()` or `call_python_sequential()` — Python subprocess execution. Used by `PythonDUT`.

### `gen_all_helpers(has_wide, duts, is_sequential) -> str`

Combines `gen_wide_to_string()` (if needed) with each DUT's `helper_code()`.
