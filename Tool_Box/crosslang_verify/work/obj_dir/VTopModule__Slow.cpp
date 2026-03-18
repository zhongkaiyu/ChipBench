// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See VTopModule.h for the primary calling header

#include "VTopModule.h"
#include "VTopModule__Syms.h"

//==========

VL_CTOR_IMP(VTopModule) {
    VTopModule__Syms* __restrict vlSymsp = __VlSymsp = new VTopModule__Syms(this, name());
    VTopModule* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Reset internal values
    
    // Reset structure values
    _ctor_var_reset();
}

void VTopModule::__Vconfigure(VTopModule__Syms* vlSymsp, bool first) {
    if (false && first) {}  // Prevent unused
    this->__VlSymsp = vlSymsp;
    if (false && this->__VlSymsp) {}  // Prevent unused
    Verilated::timeunit(-12);
    Verilated::timeprecision(-12);
}

VTopModule::~VTopModule() {
    VL_DO_CLEAR(delete __VlSymsp, __VlSymsp = NULL);
}

void VTopModule::_eval_initial(VTopModule__Syms* __restrict vlSymsp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    VTopModule::_eval_initial\n"); );
    VTopModule* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Body
    vlTOPp->__Vclklast__TOP__clk = vlTOPp->clk;
    vlTOPp->__Vclklast__TOP__rst_n = vlTOPp->rst_n;
}

void VTopModule::final() {
    VL_DEBUG_IF(VL_DBG_MSGF("+    VTopModule::final\n"); );
    // Variables
    VTopModule__Syms* __restrict vlSymsp = this->__VlSymsp;
    VTopModule* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
}

void VTopModule::_eval_settle(VTopModule__Syms* __restrict vlSymsp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    VTopModule::_eval_settle\n"); );
    VTopModule* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
}

void VTopModule::_ctor_var_reset() {
    VL_DEBUG_IF(VL_DBG_MSGF("+    VTopModule::_ctor_var_reset\n"); );
    // Body
    clk = VL_RAND_RESET_I(1);
    rst_n = VL_RAND_RESET_I(1);
    Q = VL_RAND_RESET_I(4);
}
