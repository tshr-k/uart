import utils_pkg::*;
import tick_gen_pkg::*;

// Bresenham-style fractional clock divider
module tick_gen #(
    parameter int unsigned CLK_FREQ_HZ  = 50_000_000,
    parameter int unsigned TICK_FREQ_HZ = 115_200
) (
    input  logic clk,
    input  logic a_rst,

    output logic tick
);
    initial begin
        validate_tick_gen_params(
            CLK_FREQ_HZ,
            TICK_FREQ_HZ
        );
    end

    typedef logic [min1_clog2(CLK_FREQ_HZ):0] acc_t;

    acc_t acc,  acc_next;
    logic       tick_next;
    acc_t sum;

    always_ff @(posedge clk or posedge a_rst) begin
        if (a_rst) begin
            acc  <= '0;
            tick <= 1'b0;
        end else begin
            acc  <= acc_next;
            tick <= tick_next;
        end
    end

    always_comb begin
        sum = acc + acc_t'(TICK_FREQ_HZ);

        if (sum >= acc_t'(CLK_FREQ_HZ)) begin
            acc_next  = sum - acc_t'(CLK_FREQ_HZ);
            tick_next = 1'b1;
        end else begin
            acc_next  = sum;
            tick_next = 1'b0;
        end
    end
endmodule
