import uart_pkg::*;
import utils_pkg::*;

module uart_tx #(
    parameter int unsigned    DATA_BITS     = 8,
    parameter stop_bits_cfg_t STOP_BITS_CFG = STOP_1,
    parameter parity_cfg_t    PARITY_CFG    = PARITY_NONE
) (
    // a "tick" is asserted for exactly one clock cycle
    input  logic                 clk,
    input  logic                 a_rst,
    input  logic                 en_tick,  // asserted once per bit
    input  logic                 data_ready,
    input  logic [DATA_BITS-1:0] data_in,  // must remain constant until transmission finishes

    output logic                 tx,
    output logic                 done_tick
    // the frame is transmitted again if done_tick remains high after transmission and data_in is unchanged
);
    initial begin
        validate_shared_params(
            DATA_BITS,
            STOP_BITS_CFG,
            PARITY_CFG
        );

        assert (STOP_BITS_CFG != STOP_1P5)
            else $fatal(1, "UART transmitter does not support STOP_1P5 stop bits");
    end

    localparam int unsigned STOP_BITS = (STOP_BITS_CFG == STOP_1) ? 1 : 2;
    localparam int unsigned MAX_BITS  = max(DATA_BITS, STOP_BITS);

    typedef logic [min1_clog2(MAX_BITS)-1:0] bit_count_t;

    state_t     state,     state_next;
    bit_count_t bit_count, bit_count_next;
    logic                  tx_next;
    logic                  done_tick_next;

    always_ff @(posedge clk or posedge a_rst) begin
        if (a_rst) begin
            state     <= IDLE;
            bit_count <= '0;
            tx        <= 1'b1;
            done_tick <= 1'b0;
        end else begin
            // update state only on a tick
            if (en_tick) begin
                state     <= state_next;
                bit_count <= bit_count_next;
                tx        <= tx_next;
                done_tick <= done_tick_next;
            end
        end
    end

    always_comb begin
        state_next     = state;
        bit_count_next = bit_count;
        tx_next        = tx;
        done_tick_next = 1'b0;

        unique case (state)
            IDLE: begin
                tx_next = 1'b1;
                if (data_ready) begin
                    state_next = START;
                end
            end

            START: begin
                state_next     = DATA;
                bit_count_next = '0;
                tx_next        = 1'b0;
            end

            DATA: begin
                tx_next        = data_in[bit_count];
                bit_count_next = bit_count + 1;

                if (bit_count == bit_count_t'(DATA_BITS-1)) begin
                    state_next     = (PARITY_CFG == PARITY_NONE) ? STOP : PARITY;
                    bit_count_next = '0;
                end
            end

            PARITY: begin
                state_next = STOP;
                tx_next    = (PARITY_CFG == PARITY_EVEN) ? ^data_in : ~^data_in;
            end

            STOP: begin
                tx_next        = 1'b1;
                bit_count_next = bit_count + 1;

                if (bit_count == bit_count_t'(STOP_BITS-1)) begin
                    state_next     = IDLE;
                    done_tick_next = 1'b1;
                end
            end
        endcase
    end
endmodule
