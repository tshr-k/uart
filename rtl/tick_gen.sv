import utils_pkg::*;

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
        assert (CLK_FREQ_HZ > 0)
            else $fatal(1, "CLK_FREQ_HZ must be > 0");
        assert (TICK_FREQ_HZ > 0)
            else $fatal(1, "TICK_FREQ_HZ must be > 0");
        assert (TICK_FREQ_HZ < CLK_FREQ_HZ)
            else $fatal(1, "TICK_FREQ_HZ must be < CLK_FREQ_HZ");
    end

    typedef logic [min1_clog2(CLK_FREQ_HZ):0] acc_t;

    acc_t acc,  next_acc;
    logic       next_tick;
    acc_t sum;

    always_ff @(posedge clk or posedge a_rst) begin
        if (a_rst) begin
            acc  <= '0;
            tick <= 1'b0;
        end else begin
            acc  <= next_acc;
            tick <= next_tick;
        end
    end

    always_comb begin
        sum = acc + acc_t'(TICK_FREQ_HZ);

        if (sum >= acc_t'(CLK_FREQ_HZ)) begin
            next_acc  = sum - acc_t'(CLK_FREQ_HZ);
            next_tick = 1'b1;
        end else begin
            next_acc  = sum;
            next_tick = 1'b0;
        end
    end
endmodule
