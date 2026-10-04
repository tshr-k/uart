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

struct ExpectedResult {
    std::vector<int> bits;
    bool error;
};

void check_transmitted_frame(
    UartFixture& fixture,
    const std::vector<int>& expected_frame,
    std::uint8_t data
) {
    fixture.dut_reset();
    fixture.dut->tx_data = data;
    fixture.dut->tx_wr_en = 1;
    fixture.sim.clk.cycle();

    fixture.dut->tx_wr_en = 0;
    fixture.sim.eval_dump();

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

void check_received_frame(
    UartFixture& fixture,
    const ExpectedResult& expected_result,
    std::uint8_t data
) {
    fixture.dut_reset();
    const int cycles_per_bit = (clk_freq_hz + baud_rate_hz - 1) / baud_rate_hz;

    for (int bit : expected_result.bits) {
        fixture.dut->rx = bit;
        fixture.sim.clk.cycles(cycles_per_bit);
    }

    fixture.dut->rx = 1;
    fixture.sim.clk.cycles(cycles_per_bit);

    CHECK(fixture.dut->rx_buffer_empty == 0);
    CHECK(fixture.dut->rx_data == data);
    CHECK(fixture.dut->rx_error == expected_result.error);
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

    std::uint8_t tx_data = 0xC9;
    UartTxRef uart_tx_ref {};
    check_transmitted_frame(*this, uart_tx_ref.get_frame(tx_data), tx_data);
}

TEST_CASE_METHOD(UartFixture, "UART core stores received byte without errors in rx buffer", "[uart]") {
    open_trace(wave_dir, "uart_receive");

    UartTxRef uart_tx_ref {};
    const std::uint8_t data = 0xA5;
    const ExpectedResult expected_result {uart_tx_ref.get_frame(data), false};

    check_received_frame(*this, expected_result, data);
}

TEST_CASE_METHOD(UartFixture, "UART core stores parity error in rx buffer", "[uart]") {
    open_trace(wave_dir, "uart_receive_parity_error");

    UartTxRef uart_tx_ref {};
    const std::uint8_t data = 0xA5;
    const ExpectedResult expected_result {uart_tx_ref.get_frame(data, true), true};

    check_received_frame(*this, expected_result, data);
}

TEST_CASE_METHOD(UartFixture, "UART core stores frame error in rx buffer", "[uart]") {
    open_trace(wave_dir, "uart_receive_frame_error");

    UartTxRef uart_tx_ref {};
    const std::uint8_t data = 0xA5;
    const ExpectedResult expected_result {uart_tx_ref.get_frame(data, false, true), true};

    check_received_frame(*this, expected_result, data);
}