#include <cstdint>
#include <string>
#include <vector>

#include <catch2/catch_test_macros.hpp>

#include "tb_utils.hpp"
#include "uart_tx_ref.hpp"
#include "Vuart_tx.h"


// specialise reset function for uart_tx module
template<>
void DutFixture<Vuart_tx>::dut_reset() {
    dut->clk = 0;
    dut->a_rst = 0;
    dut->en_tick = 0;
    dut->data_ready = 0;
    sim.eval_dump();

    dut->a_rst = 1;
    sim.eval_dump();

    dut->a_rst = 0;
    sim.eval_dump();
}

using UartTxFixture = DutFixture<Vuart_tx>;

const std::string wave_dir = "traces/uart_tx";


TEST_CASE_METHOD(UartTxFixture, "UART transmitter reset works", "[uart_tx]") {
    open_trace(wave_dir, "uart_tx_reset");
    
    dut_reset();
    CHECK(dut->tx == 1);
    CHECK(dut->done_tick == 0);

    sim.clk.cycles(5);  // no en_tick
    CHECK(dut->tx == 1);
    CHECK(dut->done_tick == 0);
}

TEST_CASE_METHOD(UartTxFixture, "UART transmitter transmits a frame correctly", "[uart_tx]") {
    // open_trace(wave_dir, "uart_tx_transmit");

    UartTxRef ref {};

    dut_reset();
    dut->en_tick = 1; // leave high for testing so that each clock edge is used
   
    // send a byte of data
    std::uint8_t data_to_send = 0xA5;
    dut->data_in = data_to_send;
    dut->data_ready = 1;
    sim.clk.cycle();  // enter START state

    dut->data_ready = 0;  // don't send this frame twice
    sim.eval_dump();

    // collect transmitted bits for the length of a frame
    std::vector<int> transmitted_bits;
    for (int i = 0; i < ref.get_frame_length(); ++i) {
        sim.clk.cycle();
        transmitted_bits.push_back(dut->tx);
    }
    
    CHECK(dut->done_tick == 1);
    CHECK(transmitted_bits == ref.get_frame(data_to_send));

    for (int i = 0; i < 5; ++i) {
        sim.clk.cycle();
        CHECK(dut->tx == 1);  // IDLE state
    }
}
