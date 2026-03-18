// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See VRefModule.h for the primary calling header

#include "VRefModule.h"
#include "VRefModule__Syms.h"

//==========

VL_CTOR_IMP(VRefModule) {
    VRefModule__Syms* __restrict vlSymsp = __VlSymsp = new VRefModule__Syms(this, name());
    VRefModule* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Reset internal values
    
    // Reset structure values
    _ctor_var_reset();
}

void VRefModule::__Vconfigure(VRefModule__Syms* vlSymsp, bool first) {
    if (false && first) {}  // Prevent unused
    this->__VlSymsp = vlSymsp;
    if (false && this->__VlSymsp) {}  // Prevent unused
    Verilated::timeunit(-12);
    Verilated::timeprecision(-12);
}

VRefModule::~VRefModule() {
    VL_DO_CLEAR(delete __VlSymsp, __VlSymsp = NULL);
}

void VRefModule::_eval_initial(VRefModule__Syms* __restrict vlSymsp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    VRefModule::_eval_initial\n"); );
    VRefModule* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Body
    vlTOPp->__Vclklast__TOP__clk = vlTOPp->clk;
    vlTOPp->__Vclklast__TOP__rst_n = vlTOPp->rst_n;
}

void VRefModule::final() {
    VL_DEBUG_IF(VL_DBG_MSGF("+    VRefModule::final\n"); );
    // Variables
    VRefModule__Syms* __restrict vlSymsp = this->__VlSymsp;
    VRefModule* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
}

void VRefModule::_eval_settle(VRefModule__Syms* __restrict vlSymsp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    VRefModule::_eval_settle\n"); );
    VRefModule* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
}

void VRefModule::_ctor_var_reset() {
    VL_DEBUG_IF(VL_DBG_MSGF("+    VRefModule::_ctor_var_reset\n"); );
    // Body
    clk = VL_RAND_RESET_I(1);
    rst_n = VL_RAND_RESET_I(1);
    Q = VL_RAND_RESET_I(4);
}
