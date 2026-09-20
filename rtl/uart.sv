import uart_pkg::*;
import tick_gen_pkg::*;

module uart #(
    parameter int unsigned    CLK_FREQ_HZ     = 50_000_000,
    parameter int unsigned    BAUD_RATE_HZ    = 115_200,
    parameter int unsigned    DATA_BITS       = 8,
    parameter stop_bits_cfg_t STOP_BITS_CFG   = STOP_1,
    parameter parity_cfg_t    PARITY_CFG      = PARITY_NONE,
    parameter int unsigned    OVERSAMPLE      = 16,  // ticks per bit, for receiver
    parameter int unsigned    RX_BUFFER_DEPTH = 16,
    parameter int unsigned    TX_BUFFER_DEPTH = 16
) (
    input  logic                 clk,
    input  logic                 a_rst,
    input  logic                 rx,
    input  logic [DATA_BITS-1:0] tx_data,
    input  logic                 rx_pop_en,
    input  logic                 tx_wr_en,

    output logic                 tx,
    output logic [DATA_BITS-1:0] rx_data,
    output logic                 rx_error,
    output logic                 rx_overflow_tick,
    output logic                 tx_buffer_full,
    output logic                 rx_buffer_empty
);
    initial begin
        validate_tick_gen_params(
            CLK_FREQ_HZ,
            BAUD_RATE_HZ
        );
        validate_shared_uart_params(
            DATA_BITS,
            STOP_BITS_CFG,
            PARITY_CFG
        );
        validate_oversample_param(OVERSAMPLE);

        assert (RX_BUFFER_DEPTH > 0)
            else $fatal(1, "RX_BUFFER_DEPTH must be > 0");
        assert (TX_BUFFER_DEPTH > 0)
            else $fatal(1, "TX_BUFFER_DEPTH must be > 0");
    end

    localparam int unsigned TICK_FREQ_HZ = OVERSAMPLE * BAUD_RATE_HZ;

    typedef logic [DATA_BITS-1:0] data_t;
    typedef struct packed {
        data_t data;
        logic  error;
    } rx_result_t;

    logic                          oversample_tick;
    logic [$clog2(OVERSAMPLE)-1:0] oversample_tick_count;
    logic                          bit_tick;

    data_t                         tx_data_buffered;
    rx_result_t                    rx_result_to_buffer;
    rx_result_t                    rx_result;
    logic                          tx_done_tick;
    logic                          rx_done_tick;
    logic                          tx_buffer_empty;
    logic                          rx_buffer_full;

    tick_gen #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .TICK_FREQ_HZ(TICK_FREQ_HZ)
    ) oversample_tick_gen (
        .clk,
        .a_rst,

        .tick(oversample_tick)
    );

    counter #(
        .MODULO(OVERSAMPLE)
    ) oversample_tick_counter (
        .clk,
        .a_rst,
        .en(oversample_tick),

        .count(oversample_tick_count)
    );

    fifo #(
        .DATA_T(data_t),
        .DEPTH(TX_BUFFER_DEPTH)
    ) tx_buffer (
        .clk,
        .a_rst,
        .pop_en(tx_done_tick),
        .wr_en(tx_wr_en),
        .wr_data(tx_data),

        .empty(tx_buffer_empty),
        .full(tx_buffer_full),
        .rd_data(tx_data_buffered)
    );

    uart_tx #(
        .DATA_BITS(DATA_BITS),
        .STOP_BITS_CFG(STOP_BITS_CFG),
        .PARITY_CFG(PARITY_CFG)
    ) transmitter (
        .clk,
        .a_rst,
        .en_tick(bit_tick),
        .data_ready(!tx_buffer_empty),
        .data_in(tx_data_buffered),

        .tx,
        .done_tick(tx_done_tick)
    );

    fifo #(
        .DATA_T(rx_result_t),
        .DEPTH(RX_BUFFER_DEPTH)
    ) rx_buffer (
        .clk,
        .a_rst,
        .pop_en(rx_pop_en),
        .wr_en(rx_done_tick),
        .wr_data(rx_result_to_buffer),

        .empty(rx_buffer_empty),
        .full(rx_buffer_full),
        .rd_data(rx_result)
    );

    uart_rx #(
        .DATA_BITS(DATA_BITS),
        .STOP_BITS_CFG(STOP_BITS_CFG),
        .PARITY_CFG(PARITY_CFG),
        .OVERSAMPLE(OVERSAMPLE)
    ) receiver (
        .clk,
        .a_rst,
        .en_tick(oversample_tick),
        .rx,

        .data_out(rx_result_to_buffer.data),
        .done_tick(rx_done_tick),
        .error_tick(rx_result_to_buffer.error)
    );

    assign bit_tick         = oversample_tick && (oversample_tick_count == OVERSAMPLE-1);
    assign rx_data          = rx_result.data;
    assign rx_error         = rx_result.error;
    assign rx_overflow_tick = rx_done_tick && rx_buffer_full;
endmodule
