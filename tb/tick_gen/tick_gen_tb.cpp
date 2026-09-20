#include <string>

#include <catch2/catch_test_macros.hpp>

#include "tb_utils.hpp"
#include "Vtick_gen.h"


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