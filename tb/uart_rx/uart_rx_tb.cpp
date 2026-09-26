#include <cstdint>
#include <random>
#include <string>
#include <vector>

#include <catch2/catch_test_macros.hpp>

#include "tb_utils.hpp"
#include "uart_tx/uart_tx_ref.hpp"
#include "Vuart_rx.h"


// specialise reset function for uart_tx module
template<>
void DutFixture<Vuart_rx>::dut_reset() {
    // enable for testing so that state machine can progress on each clock edge
    dut->en_tick = 1;
    dut->clk = 0;
    dut->a_rst = 0;
    dut->rx = 1;  // idle state
    sim.eval_dump();

    dut->a_rst = 1;
    sim.eval_dump();

    dut->a_rst = 0;
    sim.eval_dump();
}

using UartRxFixture = DutFixture<Vuart_rx>;

const std::string wave_dir = "traces/uart_rx";

void check_received_frame(
    UartRxFixture& fixture,
    UartTxRef& uart_tx_ref,
    std::uint8_t data,
    bool parity_error = false,
    bool frame_error = false
) {
    fixture.dut_reset();
    auto frame = uart_tx_ref.get_frame(data, parity_error, frame_error);
    bool saw_done = false;
    bool received_error = false;

    for (int bit : frame) {
        for (int i = 0; i < 16; ++i) {
            fixture.dut->rx = bit;
            fixture.sim.clk.cycle();
            if (fixture.dut->done_tick == 1) {
                saw_done = true;
                received_error = fixture.dut->error;
            }
        }
    }

    fixture.dut->rx = 1;
    fixture.sim.clk.cycles(4);

    CHECK(saw_done);
    CHECK(fixture.dut->data_out == data);
    CHECK(received_error == (parity_error || frame_error));
}


TEST_CASE_METHOD(UartRxFixture, "UART receiver reset works", "[uart_rx]") {
    // open_trace(wave_dir, "uart_rx_reset");
    
    dut->data_out = 0xFF;  // should remain unaffected by reset
    sim.eval_dump();

    dut_reset();
    CHECK(dut->data_out == 0xFF);
    CHECK(dut->done_tick == 0);
    CHECK(dut->error == 0);

    sim.clk.cycles(99);  // rx is idle, so no change should occur
    CHECK(dut->data_out == 0xFF);
    CHECK(dut->done_tick == 0);
    CHECK(dut->error == 0);
}

TEST_CASE_METHOD(UartRxFixture, "UART receiver enable works", "[uart_rx]") {
    // open_trace(wave_dir, "uart_rx_enable");
    
    dut->data_out = 0xFF;  // should remain unaffected by reset
    dut_reset();

    dut->en_tick = 0;  // disable reception
    sim.eval_dump();

    for (int i = 0; i < 5; ++i) {
        sim.clk.cycle();
        CHECK(dut->data_out == 0xFF);
        CHECK(dut->done_tick == 0);
        CHECK(dut->error == 0);
    }
}

TEST_CASE_METHOD(UartRxFixture, "UART receiver detects frame errors", "[uart_rx]") {
    open_trace(wave_dir, "uart_rx_receive");

    UartTxRef uart_tx_ref {8, 1, parity_cfg_t::PARITY_EVEN};

    check_received_frame(*this, uart_tx_ref, 0xA5, true, false);
    check_received_frame(*this, uart_tx_ref, 0xA5, false, true);
    check_received_frame(*this, uart_tx_ref, 0xA5, true, true);
}

TEST_CASE_METHOD(UartRxFixture, "UART receiver receives random frames", "[uart_rx]") {
    UartTxRef uart_tx_ref {8, 1, parity_cfg_t::PARITY_EVEN};
    std::mt19937 random{0xA17};

    for (int i = 0; i < 100; ++i) {
        const bool parity_error = random() % 2;
        const bool frame_error = random() % 2;
        check_received_frame(
            *this,
            uart_tx_ref,
            static_cast<std::uint8_t>(random()),
            parity_error,
            frame_error
        );
    }
}
