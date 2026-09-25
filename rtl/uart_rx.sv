import uart_pkg::*;
import utils_pkg::*;

module uart_rx #(
    parameter int unsigned    DATA_BITS     = 8,
    parameter stop_bits_cfg_t STOP_BITS_CFG = STOP_1,
    parameter parity_cfg_t    PARITY_CFG    = PARITY_NONE,
    parameter int unsigned    OVERSAMPLE    = 16  // ticks per bit
) (
    // a "tick" is asserted for exactly one clock cycle
    input  logic                 clk,
    input  logic                 a_rst,
    input  logic                 en_tick,  // asserted OVERSAMPLE times per bit
    input  logic                 rx,

    output logic [DATA_BITS-1:0] data_out,
    output logic                 done_tick,  // asserted even on error
    output logic                 error  // sticky frame or parity error status
    // asserted as soon as an error is detected; resets to 0 after done_tick
);
    initial begin
        validate_shared_uart_params(
            DATA_BITS,
            STOP_BITS_CFG,
            PARITY_CFG
        );

        validate_oversample_param(OVERSAMPLE);
    end

    localparam int unsigned STOP_TICKS = stop_ticks(STOP_BITS_CFG, OVERSAMPLE);
    localparam int unsigned MAX_TICKS  = max(OVERSAMPLE, STOP_TICKS);

    typedef logic [$clog2(MAX_TICKS)-1:0]     tick_count_t;
    typedef logic [min1_clog2(DATA_BITS)-1:0] data_count_t;
    typedef logic [DATA_BITS-1:0]             data_t;

    localparam tick_count_t DATA_SAMPLE_TICK  = tick_count_t'(OVERSAMPLE   - 1);
    localparam tick_count_t START_SAMPLE_TICK = tick_count_t'(OVERSAMPLE/2 - 1);

    state_t      state,      state_next;
    logic        rx_sync_1,  rx_sync_2;
    tick_count_t tick_count, tick_count_next;
    data_count_t data_count, data_count_next;
    data_t                   data_out_next;
    logic        parity_bit, parity_bit_next;
    logic                    done_tick_next;
    logic                    error_next;

    function automatic logic parity_error(
        input logic parity
    );
        unique case (PARITY_CFG)
            PARITY_NONE: return 1'b0;
            PARITY_EVEN: return parity != 1'b0;
            PARITY_ODD:  return parity != 1'b1;
        endcase
    endfunction

    always_ff @(posedge clk or posedge a_rst) begin
        if (a_rst) begin
            state      <= IDLE;
            rx_sync_1  <= 1'b1;
            rx_sync_2  <= 1'b1;
            tick_count <= '0;
            data_count <= '0;
            done_tick  <= 1'b0;
            error      <= 1'b0;
        end else begin
            // synchronise rx to avoid metastability
            rx_sync_1 <= rx;
            rx_sync_2 <= rx_sync_1;

            // update state only on a tick
            if (en_tick) begin
                state      <= state_next;
                tick_count <= tick_count_next;
                data_count <= data_count_next;
                data_out   <= data_out_next;
                parity_bit <= parity_bit_next;
                done_tick  <= done_tick_next;
                error      <= error_next;
            end
        end
    end

    always_comb begin
        state_next      = state;
        tick_count_next = tick_count;
        data_count_next = data_count;
        data_out_next   = data_out;
        parity_bit_next = parity_bit;
        done_tick_next  = 1'b0;
        error_next      = 1'b0;

        unique case (state)
            IDLE:
                if (rx_sync_2 == 1'b0) begin
                    state_next      = START;
                    tick_count_next = '0;
                end

            START:
                if (tick_count == START_SAMPLE_TICK) begin
                    if (rx_sync_2 != 1'b0) begin
                        state_next = IDLE;
                    end else begin
                        state_next      = DATA;
                        tick_count_next = '0;
                        data_count_next = '0;
                    end
                end else begin
                    tick_count_next = tick_count + 1;
                end

            DATA:
                if (tick_count == DATA_SAMPLE_TICK) begin
                    tick_count_next           = '0;
                    data_out_next[data_count] = rx_sync_2;
                    if (data_count == data_count_t'(DATA_BITS-1))
                        state_next = (PARITY_CFG == PARITY_NONE) ? STOP : PARITY;
                    else
                        data_count_next = data_count + 1;
                end else begin
                    tick_count_next = tick_count + 1;
                end

            PARITY:
                if (tick_count == DATA_SAMPLE_TICK) begin
                    state_next      = STOP;
                    tick_count_next = '0;
                    parity_bit_next = rx_sync_2;
                end else begin
                    tick_count_next = tick_count + 1;
                end

            STOP:
                if (tick_count == tick_count_t'(STOP_TICKS-1)) begin
                    state_next = (rx_sync_2 == 1'b0) ? START : IDLE;
                    error_next = error || parity_error(^{data_out, parity_bit});  // frame or parity error
                    // any errors are cleared on the first enable tick of a START or IDLE state
                    done_tick_next  = 1'b1;
                end else begin
                    // only validate the first stop bit
                    if (tick_count == DATA_SAMPLE_TICK && rx_sync_2 != 1'b1)
                        error_next = 1'b1;  // don't abort, just report the error
                    else
                        error_next = error;  // remember whether the first stop bit was invalid
                    tick_count_next = tick_count + 1;
                end
        endcase
    end
endmodule
