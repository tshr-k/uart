#include <vector>
#include <cmath>
#include <numeric>
#include <string>

#include <catch2/catch_test_macros.hpp>

#include "tb_utils.hpp"
#include "Vtick_gen.h"


const int clk_freq_hz = 50'000'000;
const int tick_freq_hz = 115'200;

// the tick generation pattern repeats after ticks_pattern_period ticks
const int ticks_pattern_period = clk_freq_hz / std::gcd(clk_freq_hz, tick_freq_hz);

// specialise reset function for tick_gen module
template<>
void DutFixture<Vtick_gen>::dut_reset() {
    dut->clk = 0;
    dut->a_rst = 1;
    sim.eval_dump();
    
    dut->a_rst = 0;
}

using TickGenFixture = DutFixture<Vtick_gen>;

const std::string wave_path = "traces/tick_gen/tick_gen.fst";


TEST_CASE_METHOD(TickGenFixture, "Tick generator reset works", "[tick_gen]") {
    // open_trace(wave_path);
    
    dut_reset();
    CHECK(dut->tick == 0); 
}

TEST_CASE_METHOD(TickGenFixture, "Tick generator first ticks after (clk_freq/tick_freq) + 1 cycles", "[tick_gen]") {
    // open_trace(wave_path);
    
    dut_reset();
    for (int i = 0; i < clk_freq_hz/tick_freq_hz; ++i) {
        sim.clk.cycle();
        CHECK(dut->tick == 0);
    }

    sim.clk.cycle();
    CHECK(dut->tick == 1);
}

TEST_CASE_METHOD(TickGenFixture, "Tick generator is periodic", "[tick_gen]") {
    // open_trace(wave_path);

    std::vector<int> tick_history;
    
    dut_reset();
    for (int i = 0; i < ticks_pattern_period; ++i) {
        sim.clk.cycle();
        tick_history.push_back(dut->tick);
    }

    for (int rep = 0; rep < 5; ++rep) {
        for (int i = 0; i < ticks_pattern_period; ++i) {
            sim.clk.cycle();
            CHECK(dut->tick == tick_history[i]);
        }
    }
    
}

TEST_CASE_METHOD(TickGenFixture, "Tick generator is never off by 1 or more ticks", "[tick_gen]") {
    open_trace(wave_path);
    
    const double ticks_per_cycle = static_cast<double>(tick_freq_hz) / clk_freq_hz;
    double ref_ticks = 0;
    int ticks = 0;

    dut_reset();
    for (int rep = 0; rep < 5; ++rep) {
        for (int i = 0; i < ticks_pattern_period; ++i) {
            sim.clk.cycle();
            if (dut->tick) {
                ++ticks;
            }
            ref_ticks += ticks_per_cycle;
            
            CHECK(std::abs(ref_ticks - ticks) < 1.0);
        }
    }
}
