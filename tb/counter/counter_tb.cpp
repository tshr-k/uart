#include <string>

#include <catch2/catch_test_macros.hpp>

#include "tb_utils.hpp"
#include "Vcounter.h"


// specialise reset function for counter module
template<>
void DutFixture<Vcounter>::dut_reset() {
    dut->clk = 0;
    dut->a_rst = 1;
    sim.eval_dump();
    
    dut->a_rst = 0;
    dut->en = 1;
}

using CounterFixture = DutFixture<Vcounter>;

const std::string wave_dir = "traces/counter";


TEST_CASE_METHOD(CounterFixture, "Counter reset works", "[counter]") {
    // open_trace(wave_dir, "counter_reset");
    
    dut_reset();
    CHECK(dut->count == 0); 
}

TEST_CASE_METHOD(CounterFixture, "Counter enable works", "[counter]") {
    // open_trace(wave_dir, "counter_enable");

    dut_reset();

    sim.clk.cycle();
    CHECK(dut->count == 1);

    sim.clk.cycle();
    CHECK(dut->count == 2);

    dut->en = 0;
    sim.clk.cycle();
    CHECK(dut->count == 2);

    dut->en = 1;
    sim.clk.cycle();
    CHECK(dut->count == 3);
}

TEST_CASE_METHOD(CounterFixture, "Counter wraps around", "[counter]") {
    open_trace(wave_dir, "counter_wrap");

    dut_reset();

    sim.clk.cycles(254);
    CHECK(dut->count == 254);

    sim.clk.cycle();
    CHECK(dut->count == 255);

    sim.clk.cycle();
    CHECK(dut->count == 0);

    sim.clk.cycle();
    CHECK(dut->count == 1);
}

