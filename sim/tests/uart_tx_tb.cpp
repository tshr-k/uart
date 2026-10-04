#include <cstdint>
#include <random>
#include <string>
#include <vector>

#include <catch2/catch_test_macros.hpp>

#include "tb_utils.hpp"
#include "uart_tx_ref.hpp"
#include "Vuart_tx.h"


// specialise reset function for uart_tx module
template<>
void DutFixture<Vuart_tx>::dut_reset() {
    // enable for testing so that state machine can progress on each clock edge
    dut->en_tick = 1;
    dut->clk = 0;
    dut->a_rst = 0;
    dut->data_ready = 0;
    sim.eval_dump();

    dut->a_rst = 1;
    sim.eval_dump();

    dut->a_rst = 0;
    sim.eval_dump();
}

using UartTxFixture = DutFixture<Vuart_tx>;

const std::string wave_dir = "traces/uart_tx";

void check_transmitted_frame(
    UartTxFixture& fixture,
    const std::vector<int>& expected_frame,
    std::uint8_t data
) {
    fixture.dut_reset();
    fixture.dut->data_in = data;
    fixture.dut->data_ready = 1;
    fixture.sim.clk.cycle();

    fixture.dut->data_ready = 0;
    fixture.sim.eval_dump();

    std::vector<int> transmitted_bits;
    for (int bit = 0; bit < expected_frame.size(); ++bit) {
        fixture.sim.clk.cycle();
        transmitted_bits.push_back(fixture.dut->tx);
    }

    CHECK(fixture.dut->done_tick == 1);
    CHECK(transmitted_bits == expected_frame);
}


TEST_CASE_METHOD(UartTxFixture, "UART transmitter reset and enable work", "[uart_tx]") {
    open_trace(wave_dir, "uart_tx_reset");
    
    dut_reset();
    CHECK(dut->tx == 1);
    CHECK(dut->done_tick == 0);

    dut->en_tick = 0;  // disable transmission
    sim.eval_dump();
    sim.clk.cycles(2);
    CHECK(dut->tx == 1);
    CHECK(dut->done_tick == 0);
}

TEST_CASE_METHOD(UartTxFixture, "UART transmitter transmits a frame correctly", "[uart_tx]") {
    open_trace(wave_dir, "uart_tx_transmit");

    UartTxRef uart_tx_ref {};

    check_transmitted_frame(*this, uart_tx_ref.get_frame(0xA5), 0xA5);

    for (int bit = 0; bit < 5; ++bit) {
        sim.clk.cycle();
        CHECK(dut->tx == 1);  // idle
    }
}

TEST_CASE_METHOD(UartTxFixture, "UART transmitter transmits random frames", "[uart_tx]") {
    UartTxRef uart_tx_ref {};
    std::mt19937 random{0xA17};

    for (int rep = 0; rep < 100; ++rep) {
        const auto data = static_cast<std::uint8_t>(random());
        check_transmitted_frame(*this, uart_tx_ref.get_frame(data), data);
    }
}
