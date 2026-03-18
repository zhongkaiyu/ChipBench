"""
C++ helper function text generators for testbench.cpp.

Each function returns a string of C++ code to be emitted into the testbench.
"""


def gen_wide_to_string():
    return '''
// Helper to convert wide signal (array of uint32_t) to decimal string
std::string wide_to_string(const std::vector<uint32_t>& chunks) {
    if (chunks.empty()) return "0";
    if (chunks.size() == 1) return std::to_string(chunks[0]);
    if (chunks.size() == 2) {
        uint64_t val = ((uint64_t)chunks[1] << 32) | chunks[0];
        return std::to_string(val);
    }
    std::vector<uint32_t> temp = chunks;
    std::string digits;
    bool all_zero = false;
    while (!all_zero) {
        all_zero = true;
        uint64_t remainder = 0;
        for (int i = (int)temp.size() - 1; i >= 0; i--) {
            uint64_t dividend = (remainder << 32) | temp[i];
            temp[i] = (uint32_t)(dividend / 10);
            remainder = dividend % 10;
            if (temp[i] != 0) all_zero = false;
        }
        digits = (char)('0' + remainder) + digits;
        if (all_zero && digits.length() == 1) break;
    }
    size_t start = digits.find_first_not_of('0');
    return (start == std::string::npos) ? "0" : digits.substr(start);
}
'''


def gen_string_equals():
    return '''
// Helper to compare string numbers (ignoring leading zeros)
bool string_equals(const std::string& a, const std::string& b) {
    size_t a_start = a.find_first_not_of('0');
    size_t b_start = b.find_first_not_of('0');
    std::string a_trimmed = (a_start == std::string::npos) ? "0" : a.substr(a_start);
    std::string b_trimmed = (b_start == std::string::npos) ? "0" : b.substr(b_start);
    return a_trimmed == b_trimmed;
}
'''


def gen_value_to_string():
    return '''
// Helper to convert CXXRTL value to string (for arbitrary width)
template<size_t Bits>
std::string value_to_string(const cxxrtl::value<Bits>& val) {
    if (Bits <= 64) {
        uint64_t v = 0;
        for (size_t i = 0; i < val.chunks && i < 2; i++) {
            v |= ((uint64_t)val.data[i]) << (32 * i);
        }
        return std::to_string(v);
    }
    std::vector<uint32_t> temp(val.chunks);
    for (size_t i = 0; i < val.chunks; i++) temp[i] = val.data[i];
    std::vector<uint32_t> digits_vec;
    bool all_zero = false;
    while (!all_zero) {
        all_zero = true;
        uint64_t remainder = 0;
        for (int i = (int)temp.size() - 1; i >= 0; i--) {
            uint64_t dividend = (remainder << 32) | temp[i];
            temp[i] = (uint32_t)(dividend / 10);
            remainder = dividend % 10;
            if (temp[i] != 0) all_zero = false;
        }
        digits_vec.push_back((uint32_t)remainder);
        if (all_zero && digits_vec.size() == 1 && digits_vec[0] == 0) break;
    }
    std::string result;
    for (int i = (int)digits_vec.size() - 1; i >= 0; i--) {
        result += ('0' + digits_vec[i]);
    }
    return result.empty() ? "0" : result;
}

// Helper to convert CXXRTL wire to string
template<size_t Bits>
std::string wire_to_string(const cxxrtl::wire<Bits>& w) {
    return value_to_string(w.curr);
}
'''


def gen_call_python(is_sequential):
    func_name = "call_python_sequential" if is_sequential else "call_python_batch"
    return f'''
// Helper: Execute Python with TopModule class and eval() function
std::vector<std::map<std::string, std::string>> {func_name}(
    const std::vector<std::map<std::string, std::string>>& all_inputs) {{

    std::vector<std::map<std::string, std::string>> results;

    std::stringstream json_ss;
    json_ss << "[";
    for (size_t i = 0; i < all_inputs.size(); i++) {{
        json_ss << "{{";
        bool first = true;
        for (const auto& kv : all_inputs[i]) {{
            if (!first) json_ss << ", ";
            json_ss << "\\"" << kv.first << "\\": \\"" << kv.second << "\\"";
            first = false;
        }}
        json_ss << "}}";
        if (i + 1 < all_inputs.size()) json_ss << ", ";
    }}
    json_ss << "]";

    std::ofstream tmp_in("_py_inputs.json");
    tmp_in << json_ss.str();
    tmp_in.close();

    std::string cmd = "python3 -c \\""
        "import sys, json; "
        "sys.path.insert(0, '.'); "
        "from " + std::string(PYTHON_MODULE) + " import TopModule; "
        "inputs = json.load(open('_py_inputs.json')); "
        "inputs = [{{k: int(v) for k, v in inp.items()}} for inp in inputs]; "
        "dut = TopModule(); "
        "outputs = [dut.eval(inp) for inp in inputs]; "
        "print(json.dumps([{{k: str(int(v) if isinstance(v, bool) else v) for k,v in o.items()}} for o in outputs]));\\"";

    std::array<char, 65536> buffer;
    std::string output;

    FILE* pipe = popen(cmd.c_str(), "r");
    if (!pipe) return results;

    while (fgets(buffer.data(), buffer.size(), pipe) != nullptr) {{
        output += buffer.data();
    }}

    if (pclose(pipe) != 0) return results;

    size_t pos = 0;
    while ((pos = output.find("{{", pos)) != std::string::npos) {{
        size_t end = output.find("}}", pos);
        if (end == std::string::npos) break;

        std::string obj_str = output.substr(pos, end - pos + 2);
        std::map<std::string, std::string> obj;

        size_t kpos = 0;
        while ((kpos = obj_str.find("\\"", kpos)) != std::string::npos) {{
            size_t key_start = kpos + 1;
            size_t key_end = obj_str.find("\\"", key_start);
            if (key_end == std::string::npos) break;

            std::string key = obj_str.substr(key_start, key_end - key_start);

            size_t colon = obj_str.find(":", key_end);
            if (colon == std::string::npos) break;

            size_t val_quote_start = obj_str.find("\\"", colon);
            if (val_quote_start == std::string::npos) break;

            size_t val_start = val_quote_start + 1;
            size_t val_end = obj_str.find("\\"", val_start);
            if (val_end == std::string::npos) break;

            std::string value = obj_str.substr(val_start, val_end - val_start);
            obj[key] = value;
            kpos = val_end + 1;
        }}

        results.push_back(obj);
        pos = end + 2;
    }}

    return results;
}}
'''


def gen_all_helpers(has_wide, duts, is_sequential):
    """Generate all C++ helper functions needed by active DUTs."""
    code = ""
    if has_wide:
        code += gen_wide_to_string()
    for dut in duts:
        code += dut.helper_code(is_sequential)
    return code
