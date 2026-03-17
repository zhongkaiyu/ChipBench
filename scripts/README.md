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