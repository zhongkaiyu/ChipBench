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
// \src: /tmp/multi_test/dut.sv:8.1-19.10
struct p_TopModule : public module {
	// \src: /tmp/multi_test/dut.sv:11.22-11.23
	/*output*/ wire<4> p_Q;
	// \src: /tmp/multi_test/dut.sv:10.11-10.16
	/*input*/ value<1> p_rst__n;
	// \src: /tmp/multi_test/dut.sv:9.11-9.14
	/*input*/ value<1> p_clk;
	value<1> prev_p_clk;
	bool posedge_p_clk() const {
		return !prev_p_clk.slice<0>().val() && p_clk.slice<0>().val();
	}
	// \hdlname: core Q_out
	// \src: /tmp/multi_test/dut.sv:3.18-3.23
	/*outline*/ value<4> p_core_2e_Q__out;
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
	debug_outline debug_eval_outline { std::bind(&p_TopModule::debug_eval, this) };

	void debug_info(debug_items *items, debug_scopes *scopes, std::string path, metadata_map &&cell_attrs = {}) override;
}; // struct p_TopModule

void p_TopModule::reset() {
}

bool p_TopModule::eval(performer *performer) {
	bool converged = true;
	bool posedge_p_clk = this->posedge_p_clk();
	// cells $procdff$9 $flatten\core.$not$/tmp/multi_test/dut.sv:5$1
	if (posedge_p_clk) {
		p_Q.next = not_u<1>(p_Q.curr.slice<0>().val()).concat(p_Q.curr.slice<3,1>()).val();
	}
	if (p_rst__n == value<1> {0u}) {
		p_Q.next = value<4>{0u};
	}
	return converged;
}

void p_TopModule::debug_eval() {
	// \src: /tmp/multi_test/dut.sv:5.21-5.29
	// cell $flatten\core.$not$/tmp/multi_test/dut.sv:5$1
	p_core_2e_Q__out = not_u<1>(p_Q.curr.slice<0>().val()).concat(p_Q.curr.slice<3,1>()).val();
}

CXXRTL_EXTREMELY_COLD
void p_TopModule::debug_info(debug_items *items, debug_scopes *scopes, std::string path, metadata_map &&cell_attrs) {
	assert(path.empty() || path[path.size() - 1] == ' ');
	if (scopes) {
		scopes->add(path.empty() ? path : path.substr(0, path.size() - 1), "TopModule", metadata_map({
			{ "top", UINT64_C(1) },
			{ "src", "/tmp/multi_test/dut.sv:8.1-19.10" },
		}), std::move(cell_attrs));
		scopes->add(path, "core", "lfsr_core", "src\000s/tmp/multi_test/dut.sv:1.1-6.10\000", "src\000s/tmp/multi_test/dut.sv:14.15-14.45\000");
	}
	if (items) {
		items->add(path, "core Q_in", "src\000s/tmp/multi_test/dut.sv:2.17-2.21\000", debug_alias(), p_Q);
		items->add(path, "core Q_out", "src\000s/tmp/multi_test/dut.sv:3.18-3.23\000", debug_eval_outline, p_core_2e_Q__out);
		items->add(path, "next_Q", "src\000s/tmp/multi_test/dut.sv:13.16-13.22\000", debug_eval_outline, p_core_2e_Q__out);
		items->add(path, "Q", "src\000s/tmp/multi_test/dut.sv:11.22-11.23\000", p_Q, 0, debug_item::OUTPUT|debug_item::DRIVEN_SYNC);
		items->add(path, "rst_n", "src\000s/tmp/multi_test/dut.sv:10.11-10.16\000", p_rst__n, 0, debug_item::INPUT|debug_item::UNDRIVEN);
		items->add(path, "clk", "src\000s/tmp/multi_test/dut.sv:9.11-9.14\000", p_clk, 0, debug_item::INPUT|debug_item::UNDRIVEN);
	}
}

} // namespace cxxrtl_design

extern "C"
cxxrtl_toplevel cxxrtl_design_create() {
	return new _cxxrtl_toplevel { std::unique_ptr<cxxrtl_design::p_TopModule>(new cxxrtl_design::p_TopModule) };
}
