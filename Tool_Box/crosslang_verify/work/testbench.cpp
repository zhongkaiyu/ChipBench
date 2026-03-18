// Auto-generated Cross-Language Verification Testbench
// SEQUENTIAL CIRCUIT (with clock)
// Tests: RefModule (SV), DUT

#include <iostream>
#include <fstream>
#include <sstream>
#include <cstdint>
#include <cstdlib>
#include <string>
#include <random>
#include <map>
#include <vector>
#include <cstdio>
#include <memory>
#include <array>
#include <cctype>

// Verilator headers (ref)
#include "VRefModule.h"
#include "verilated.h"

// DUT
#include "VTopModule.h"


int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    VRefModule* ref = new VRefModule;
    VTopModule* dut = new VTopModule;

    std::mt19937_64 gen(12345);  // Fixed seed for reproducibility
    std::uniform_int_distribution<uint64_t> dist(0, UINT64_MAX);
    std::uniform_int_distribution<uint32_t> dist32(0, UINT32_MAX);

    uint32_t rst_n;
    int clk = 0;

    int dut_errors = 0;
    const int NUM_CYCLES = 500;

    std::cout << "============================================" << std::endl;
    std::cout << "Cross-Language Verification (SEQUENTIAL)" << std::endl;
    std::cout << "Running " << NUM_CYCLES << " clock cycles" << std::endl;
    std::cout << "============================================" << std::endl;

    // === WARMUP PHASE: Run 20 cycles with reset ACTIVE (no comparison) ===
    const int WARMUP_CYCLES = 20;
    std::cout << "Running " << WARMUP_CYCLES << " warmup cycles with reset active..." << std::endl;
    for (int warmup = 0; warmup < WARMUP_CYCLES; warmup++) {
        rst_n = dist(gen) & ((1ULL << 1) - 1);

        // Override reset signals to ACTIVE state
            rst_n = 0;  // Active-low reset active



        // === POSEDGE: clk 0 -> 1 ===
        clk = 1;
        ref->clk = clk;
        ref->rst_n = rst_n;
        ref->eval();

        // DUT
        dut->clk = clk;
        dut->rst_n = rst_n;
        dut->eval();



        // === NEGEDGE: clk 1 -> 0 ===
        clk = 0;
        ref->clk = clk;
        ref->rst_n = rst_n;
        ref->eval();

        // DUT
        dut->clk = clk;
        dut->rst_n = rst_n;
        dut->eval();
    }

    // === MAIN TEST PHASE ===
    for (int cycle = 0; cycle < NUM_CYCLES; cycle++) {
        rst_n = dist(gen) & ((1ULL << 1) - 1);

        rst_n = 1;  // Active-low reset inactive



        // === POSEDGE: clk 0 -> 1 ===
        clk = 1;
        ref->clk = clk;
        ref->rst_n = rst_n;
        ref->eval();

        // DUT
        dut->clk = clk;
        dut->rst_n = rst_n;
        dut->eval();



        int i = cycle;
        (void)i;

        // Compare DUT vs REF
        if (ref->Q != dut->Q) {
            if (dut_errors < 10) {
                std::cerr << "[DUT MISMATCH] Test " << i << ", Q: "
                          << "expected=" << (uint64_t)ref->Q
                          << ", got=" << (uint64_t)dut->Q << std::endl;
            }
            dut_errors++;
        }

        // === NEGEDGE: clk 1 -> 0 ===
        clk = 0;
        ref->clk = clk;
        ref->rst_n = rst_n;
        ref->eval();

        // DUT
        dut->clk = clk;
        dut->rst_n = rst_n;
        dut->eval();
    }
    std::cout << "============================================" << std::endl;
    std::cout << "RESULTS" << std::endl;
    std::cout << "============================================" << std::endl;
    std::cout << "Total: " << NUM_CYCLES << std::endl;
    if (dut_errors == 0) std::cout << "DUT:     PASS" << std::endl;
    else std::cerr << "DUT:     FAIL (" << dut_errors << " errors)" << std::endl;

    delete ref;
    delete dut;
    return (dut_errors > 0) ? 1 : 0;
}
