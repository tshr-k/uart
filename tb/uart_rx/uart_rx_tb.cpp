#include <cstdint>
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


TEST_CASE_METHOD(UartRxFixture, "UART receiver reset works", "[uart_rx]") {
    // open_trace(wave_dir, "uart_rx_reset");
    
    dut->data_out = 0xFF;  // should remain unaffected by reset
    sim.eval_dump();

    dut_reset();
    CHECK(dut->data_out == 0xFF);
    CHECK(dut->done_tick == 0);
    CHECK(dut->error_tick == 0);

    sim.clk.cycles(99);  // rx is idle, so no change should occur
    CHECK(dut->data_out == 0xFF);
    CHECK(dut->done_tick == 0);
    CHECK(dut->error_tick == 0);
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
        CHECK(dut->error_tick == 0);
    }
}

TEST_CASE_METHOD(UartRxFixture, "", "[uart_rx]") {
    open_trace(wave_dir, "uart_rx_receive");

    UartTxRef uart_tx_ref {};

    dut_reset();

   
    // receive a frame of data
    std::vector<int> frame = uart_tx_ref.get_frame(0xA5);
    for (int bit_num = 0; bit_num < frame.size(); ++bit_num) {
        for (int i = 0; i < 16; ++i) {  // 16 ticks per bit
            dut->rx = frame[bit_num];
            sim.clk.cycle();
        }

        if (dut->done_tick == 1) {
            CHECK(dut->data_out == 0xA5);
            CHECK(bit_num == frame.size() - 1);  // must be last bit of frame
            CHECK(dut->error_tick == 0);
        }
    }

    dut->rx = 1;  // return to idle state
    sim.clk.cycle();
    CHECK(dut->data_out == 0xA5);
    CHECK(dut->done_tick == 0);
}
