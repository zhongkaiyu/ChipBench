"""
Unified signal code generation for C++ testbenches.

Each function handles ANY signal width (1-bit to 1000+ bits) without
requiring the caller to branch on width.
"""


def get_num_chunks(width):
    return (width + 31) // 32


def gen_declaration(name, width):
    """C++ variable declaration for any width."""
    if width <= 32:
        return f"    uint32_t {name};"
    if width <= 64:
        return f"    uint64_t {name};"
    return f"    uint32_t {name}[{get_num_chunks(width)}];"


def gen_random(name, width):
    """C++ random value assignment for any width."""
    if width <= 64:
        mask = f"((1ULL << {width}) - 1)" if width < 64 else "UINT64_MAX"
        return f"        {name} = dist(gen) & {mask};"
    n = get_num_chunks(width)
    lines = []
    for i in range(n):
        remaining = width - i * 32
        if i == n - 1 and remaining < 32:
            lines.append(f"        {name}[{i}] = dist32(gen) & ((1U << {remaining}) - 1);")
        else:
            lines.append(f"        {name}[{i}] = dist32(gen);")
    return '\n'.join(lines)


def gen_ref_setter(name, width):
    """Ref model (Verilator VRefModule) setter for any width."""
    if width <= 64:
        return f"        ref->{name} = {name};"
    n = get_num_chunks(width)
    return f"        for (int _i = 0; _i < {n}; _i++) ref->{name}[_i] = {name}[_i];"


def gen_to_string(name, width, accessor=None):
    """C++ expression converting a signal to std::string.

    accessor: how to access the value, e.g. "ref->Q". Defaults to just the variable name.
    """
    src = accessor or name
    if width <= 64:
        return f"std::to_string({src})"
    n = get_num_chunks(width)
    return f'''[&]() {{
            std::vector<uint32_t> chunks({n});
            for (int _i = 0; _i < {n}; _i++) chunks[_i] = {src}[_i];
            return wide_to_string(chunks);
        }}()'''


def gen_reset_override(name, width, is_active_low, active):
    """Reset override for any width. active=True for warmup, False for main phase."""
    indent = "            " if active else "        "
    suffix = "active" if active else "inactive"

    if width <= 64:
        if is_active_low:
            val = "0" if active else "1"
        else:
            val = "1" if active else "0"
        label = "Active-low" if is_active_low else "Active-high"
        return f'{indent}{name} = {val};  // {label} reset {suffix}'

    n = get_num_chunks(width)
    lines = []
    for i in range(n):
        remaining = width - i * 32
        all_ones = (1 << remaining) - 1 if remaining < 32 else 0xFFFFFFFF
        if is_active_low:
            val = 0 if active else (all_ones if i == n - 1 else 0xFFFFFFFF)
        else:
            val = (all_ones if i == n - 1 else 0xFFFFFFFF) if active else 0
        lines.append(f'{indent}{name}[{i}] = {val};')
    return '\n'.join(lines)


def generate_signal_code(inputs, outputs, duts, reset_signals):
    """Generate all signal-related C++ code snippets.

    Returns dict with: declarations, random_generators, ref_setters,
    dut_setters ({dut: [...]}), input_to_string, output_to_string,
    dut_checks ({dut: [...]}), warmup_reset, fixed_reset.
    """
    sig = {
        'declarations': [],
        'random_generators': [],
        'ref_setters': [],
        'dut_setters': {dut: [] for dut in duts},
        'input_to_string': [],
        'output_to_string': [],
        'dut_checks': {dut: [] for dut in duts},
        'warmup_reset': [],
        'fixed_reset': [],
    }

    for name, width in inputs:
        if name.lower() == 'clk':
            sig['ref_setters'].append(f"        ref->clk = clk;")
            for dut in duts:
                sig['dut_setters'][dut].append(dut.clk_setter(name))
            continue

        sig['declarations'].append(gen_declaration(name, width))
        sig['random_generators'].append(gen_random(name, width))
        sig['ref_setters'].append(gen_ref_setter(name, width))
        for dut in duts:
            sig['dut_setters'][dut].append(dut.input_setter(name, width))
        sig['input_to_string'].append((name, gen_to_string(name, width)))

    for name, width in outputs:
        sig['output_to_string'].append((name, gen_to_string(name, width, f"ref->{name}")))
        for dut in duts:
            sig['dut_checks'][dut].append(dut.output_compare(name, width))

    for name, width, is_active_low in reset_signals:
        sig['warmup_reset'].append(gen_reset_override(name, width, is_active_low, active=True))
        sig['fixed_reset'].append(gen_reset_override(name, width, is_active_low, active=False))

    return sig
