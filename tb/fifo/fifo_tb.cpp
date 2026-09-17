#include <cstdint>
#include <string>

#include <catch2/catch_test_macros.hpp>

#include "tb_utils.hpp"
#include "fifo_ref.hpp"
#include "Vfifo.h"


// specialise reset function for fifo module
template<>
void DutFixture<Vfifo>::dut_reset() {
    dut->clk = 0;
    dut->a_rst = 1;
    sim.eval_dump();

    dut->a_rst = 0;
}

using FifoFixture = DutFixture<Vfifo>;

const std::string wave_path = "traces/fifo.fst";


TEST_CASE_METHOD(FifoFixture, "fifo reset works", "[fifo]") {
    // open_trace(wave_path);
    
    dut_reset();
    CHECK(dut->empty);
    CHECK(dut->full == 0);

    sim.eval_dump();

    sim.clk.cycles(3);
}

TEST_CASE_METHOD(FifoFixture, "fifo write and read work", "[fifo]") {
    // open_trace(wave_path);

    dut_reset();

    // only RTL model
    auto dut_write = [&](std::uint8_t data) {
        dut->wr_en = 1;
        dut->wr_data = data;
        sim.eval_dump();
        sim.clk.cycle();

        dut->wr_en = 0;
    };

    auto dut_pop = [&]() {
        dut->pop_en = 1;
        sim.eval_dump();
        sim.clk.cycle();
    };

    dut_write(5);
    CHECK_FALSE(dut->empty);
    CHECK(dut->rd_data == 5);

    dut_write(7);
    CHECK(dut->rd_data == 5);

    dut_pop();
    CHECK(dut->rd_data == 7);

    sim.clk.cycles(3);
    CHECK(dut->empty);

    dut_pop();
    CHECK(dut->empty);
    CHECK_FALSE(dut->full);
}

TEST_CASE_METHOD(FifoFixture, "fifo RTL matches reference C++ model", "[fifo]") {
    open_trace(wave_path);

    dut_reset();

    FifoRef<std::uint8_t> ref{16};

    // both RTL model and C++ reference model
    auto lockstep_check = [&]() {
        CHECK(static_cast<bool>(dut->empty) == ref.empty());
        CHECK(static_cast<bool>(dut->full) == ref.full());

        std::uint8_t expected_data = 0;
        if (ref.try_read(expected_data)) {
            CHECK(dut->rd_data == expected_data);
        }
    };

    auto lockstep_cycle = [&](bool wr_en, std::uint8_t wr_data, bool pop_en) {
        dut->wr_en = wr_en;
        dut->wr_data = wr_data;
        dut->pop_en = pop_en;
        sim.eval_dump();
        lockstep_check();

        const bool wr_ok = wr_en && !ref.full();
        const bool pop_ok = pop_en && !ref.empty();
        if (pop_ok) {
            std::uint8_t value = 0;
            REQUIRE(ref.try_pop(value));
        }
        if (wr_ok) {
            REQUIRE(ref.try_write(wr_data));
        }

        sim.clk.cycle();
        lockstep_check();
    };

    for (std::uint8_t value = 0; value < 16; ++value) {
        lockstep_cycle(true, value, false);
    }

    lockstep_cycle(true, 0xff, false);  // write while full is ignored
    lockstep_cycle(true, 0xee, true);  // simultaneous read and blocked write

    for (std::uint8_t value = 16; value < 31; ++value) {
        lockstep_cycle(true, value, true);  // simultaneous read and write
    }

    lockstep_cycle(false, 0, true);
    lockstep_cycle(false, 0, true);
    lockstep_cycle(true, 0xa5, true);

    while (!ref.empty()) {
        lockstep_cycle(false, 0, true);
    }

    lockstep_cycle(false, 0, true);  // read while empty is ignored
    CHECK(dut->empty);
    CHECK_FALSE(dut->full);
}
