#include <cstdint>
#include <string>
#include <vector>

#include <catch2/catch_test_macros.hpp>

#include "tb_utils.hpp"
#include "uart_tx_ref.hpp"
#include "Vuart.h"


// specialise reset function for uart module
template<>
void DutFixture<Vuart>::dut_reset() {
    dut->clk = 0;
    dut->a_rst = 0;
    dut->rx = 1;  // idle
    dut->rx_pop_en = 0;
    dut->tx_wr_en = 0;
    sim.eval_dump();

    dut->a_rst = 1;
    sim.eval_dump();

    dut->a_rst = 0;
    sim.eval_dump();
}

using UartFixture = DutFixture<Vuart>;

const std::string wave_dir = "traces/uart";

constexpr int clk_freq_hz = 50'000'000;
constexpr int baud_rate_hz = 115'200;

// account for the FIFO and transmitter state transitions before the start bit.
constexpr int tx_start_latency_bits = 2;

void check_transmitted_frame(
    UartFixture& fixture,
    UartTxRef& uart_tx_ref,
    std::uint8_t data
) {
    const auto expected_frame = uart_tx_ref.get_frame(data);
    std::vector<int> transmitted_bits;
    int previous_sample_cycle = 0;

    for (int bit = 0; bit < expected_frame.size(); ++bit) {
        const int sample_cycle =
            ((bit + tx_start_latency_bits) * clk_freq_hz + baud_rate_hz - 1)
            / baud_rate_hz;

        fixture.sim.clk.cycles(sample_cycle - previous_sample_cycle);
        transmitted_bits.push_back(fixture.dut->tx);
        previous_sample_cycle = sample_cycle;
    }

    CHECK(transmitted_bits == expected_frame);
}

TEST_CASE_METHOD(UartFixture, "UART core reset works", "[uart]") {
    open_trace(wave_dir, "uart_reset");

    dut_reset();
    CHECK(dut->tx == 1);
    CHECK(dut->rx_overflow_tick == 0);
    CHECK(dut->tx_buffer_full == 0);
    CHECK(dut->rx_buffer_empty == 1);

    sim.clk.cycles(3);  // rx is idle and no tx is happening
    CHECK(dut->tx == 1);
    CHECK(dut->rx_overflow_tick == 0);
    CHECK(dut->tx_buffer_full == 0);
    CHECK(dut->rx_buffer_empty == 1);
}

TEST_CASE_METHOD(UartFixture, "UART core transmits a byte pushed to its tx buffer", "[uart]") {
    open_trace(wave_dir, "uart_transmit");

    dut_reset();

    std::uint8_t tx_data = 0xC9;
    dut->tx_data = tx_data;
    dut->tx_wr_en = 1;
    sim.clk.cycle();  // push data into tx buffer

    dut->tx_wr_en = 0;
    sim.eval_dump();

    UartTxRef uart_tx_ref {};
    check_transmitted_frame(*this, uart_tx_ref, tx_data);
}