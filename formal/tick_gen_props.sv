module tick_gen_props #(
    parameter int unsigned CLK_FREQ_HZ  = 50_000_000,
    parameter int unsigned TICK_FREQ_HZ = 115_200
) (
    input logic clk,
    input logic a_rst
);
    logic tick;

    tick_gen #(
        .CLK_FREQ_HZ  (CLK_FREQ_HZ),
        .TICK_FREQ_HZ (TICK_FREQ_HZ)
    ) dut (
        .clk   (clk),
        .a_rst (a_rst),
        .tick  (tick)
    );

    // assert liveness properties
    assert_tick_eventually_asserts:
        assert property (@(posedge clk)
            !tick |=> s_eventually tick
        );

    assert_tick_eventually_deasserts:
        assert property (@(posedge clk)
            tick |=> s_eventually !tick
        );

    assert_tick_eventually_rises:
        assert property (@(posedge clk)
            !tick |=> s_eventually $rose(tick)
        );

    assert_tick_eventually_reasserts_after_falling:
        assert property (@(posedge clk)
            $fell(tick) |=> s_eventually tick
        );

    // assert safety properties
    // consecutive ticks are floor(CLK_FREQ_HZ/TICK_FREQ_HZ) or ceil(CLK_FREQ_HZ/TICK_FREQ_HZ) cycles apart
    localparam int unsigned TICK_PERIOD_MIN = CLK_FREQ_HZ / TICK_FREQ_HZ;
    localparam int unsigned TICK_PERIOD_MAX = (CLK_FREQ_HZ + TICK_FREQ_HZ - 1) / TICK_FREQ_HZ;

    // count cycles since the last tick (saturating) and note whether any tick has occurred yet
    logic [$clog2(TICK_PERIOD_MAX+1)-1:0] cycles_since_tick;
    logic                                 seen_tick;

    always_ff @(posedge clk or posedge a_rst) begin
        if (a_rst) begin
            cycles_since_tick <= '0;
            seen_tick         <= 1'b0;
        end else begin
            if (tick)
                cycles_since_tick <= '0;
            else if (cycles_since_tick != TICK_PERIOD_MAX)
                cycles_since_tick <= cycles_since_tick + 1;

            seen_tick <= seen_tick || tick;
        end
    end

    assert_tick_low_after_reset:
        assert property (@(posedge clk)
            $past(a_rst) |-> !tick
        );

    assert_tick_period_at_least_min:
        assert property (@(posedge clk)
            (!a_rst && tick && seen_tick) |-> (cycles_since_tick + 1 >= TICK_PERIOD_MIN)
        );

    assert_tick_period_at_most_max:
        assert property (@(posedge clk)
            (!a_rst && seen_tick) |-> (cycles_since_tick + 1 <= TICK_PERIOD_MAX)
        );
endmodule
