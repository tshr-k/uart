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
            !tick |-> ##[1:$] tick
        );

    assert_tick_eventually_deasserts:
        assert property (@(posedge clk)
            tick |-> ##[1:$] !tick
        );

    assert_tick_eventually_rises:
        assert property (@(posedge clk)
            !tick |-> ##[1:$] $rose(tick)
        );

    assert_tick_eventually_reasserts_after_falling:
        assert property (@(posedge clk)
            $fell(tick) |-> ##[1:$] tick
        );
endmodule
