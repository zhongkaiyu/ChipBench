#include <cxxrtl/cxxrtl.h>

#if defined(CXXRTL_INCLUDE_CAPI_IMPL) || \
    defined(CXXRTL_INCLUDE_VCD_CAPI_IMPL)
#include <cxxrtl/capi/cxxrtl_capi.cc>
#endif

#if defined(CXXRTL_INCLUDE_VCD_CAPI_IMPL)
#include <cxxrtl/capi/cxxrtl_capi_vcd.cc>
#endif

using namespace cxxrtl_yosys;

namespace cxxrtl_design {

// \top: 1
// \src: /workspace/verilogeval/Tool_Box/verilog/dut.sv:1.1-11.10
struct p_TopModule : public module {
	// \src: /workspace/verilogeval/Tool_Box/verilog/dut.sv:5.25-5.26
	/*output*/ wire<4> p_Q;
	// \src: /workspace/verilogeval/Tool_Box/verilog/dut.sv:3.25-3.30
	/*input*/ value<1> p_rst__n;
	// \src: /workspace/verilogeval/Tool_Box/verilog/dut.sv:2.25-2.28
	/*input*/ value<1> p_clk;
	value<1> prev_p_clk;
	bool posedge_p_clk() const {
		return !prev_p_clk.slice<0>().val() && p_clk.slice<0>().val();
	}
	p_TopModule(interior) {}
	p_TopModule() {
		reset();
	};

	void reset() override;

	bool eval(performer *performer = nullptr) override;

	template<class ObserverT>
	bool commit(ObserverT &observer) {
		bool changed = false;
		if (p_Q.commit(observer)) changed = true;
		prev_p_clk = p_clk;
		return changed;
	}

	bool commit() override {
		observer observer;
		return commit<>(observer);
	}

	void debug_eval();

	void debug_info(debug_items *items, debug_scopes *scopes, std::string path, metadata_map &&cell_attrs = {}) override;
}; // struct p_TopModule

void p_TopModule::reset() {
}

bool p_TopModule::eval(performer *performer) {
	bool converged = true;
	bool posedge_p_clk = this->posedge_p_clk();
	// cells $procdff$8 $not$/workspace/verilogeval/Tool_Box/verilog/dut.sv:9$3
	if (posedge_p_clk) {
		p_Q.next = not_u<1>(p_Q.curr.slice<0>().val()).concat(p_Q.curr.slice<3,1>()).val();
	}
	if (p_rst__n == value<1> {0u}) {
		p_Q.next = value<4>{0u};
	}
	return converged;
}

void p_TopModule::debug_eval() {
}

CXXRTL_EXTREMELY_COLD
void p_TopModule::debug_info(debug_items *items, debug_scopes *scopes, std::string path, metadata_map &&cell_attrs) {
	assert(path.empty() || path[path.size() - 1] == ' ');
	if (scopes) {
		scopes->add(path.empty() ? path : path.substr(0, path.size() - 1), "TopModule", metadata_map({
			{ "top", UINT64_C(1) },
			{ "src", "/workspace/verilogeval/Tool_Box/verilog/dut.sv:1.1-11.10" },
		}), std::move(cell_attrs));
	}
	if (items) {
		items->add(path, "Q", "src\000s/workspace/verilogeval/Tool_Box/verilog/dut.sv:5.25-5.26\000", p_Q, 0, debug_item::OUTPUT|debug_item::DRIVEN_SYNC);
		items->add(path, "rst_n", "src\000s/workspace/verilogeval/Tool_Box/verilog/dut.sv:3.25-3.30\000", p_rst__n, 0, debug_item::INPUT|debug_item::UNDRIVEN);
		items->add(path, "clk", "src\000s/workspace/verilogeval/Tool_Box/verilog/dut.sv:2.25-2.28\000", p_clk, 0, debug_item::INPUT|debug_item::UNDRIVEN);
	}
}

} // namespace cxxrtl_design

extern "C"
cxxrtl_toplevel cxxrtl_design_create() {
	return new _cxxrtl_toplevel { std::unique_ptr<cxxrtl_design::p_TopModule>(new cxxrtl_design::p_TopModule) };
}
