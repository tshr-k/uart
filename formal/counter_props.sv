module counter_props #(
    parameter int unsigned MODULO = 256
) (
    input logic clk,
    input logic a_rst,
    input logic en
);
    typedef logic [$clog2(MODULO)-1:0] count_t;
    
    localparam count_t MAX_COUNT = MODULO-1;

    count_t count;

    counter #(
        .MODULO(MODULO)
    ) dut (
        .clk   (clk),
        .a_rst (a_rst),
        .en    (en),
        .count (count)
    );

    // assert liveness properties
    assert_count_eventually_changes:
        assert property (@(posedge clk)
            en |-> ##[1:$] (count != $past(count))
        );

    assert_count_eventually_increments:
        assert property (@(posedge clk)
            (en && count < MAX_COUNT) |-> ##[1:$] (count == $past(count) + 1)
        );

    assert_count_eventually_wraps:
        assert property (@(posedge clk)
            (en && count == MAX_COUNT) |-> ##[1:$] (count == 0)
        );

    assert_count_eventually_reaches_zero:
        assert property (@(posedge clk)
            (en && count != 0) |-> ##[1:$] (count == 0)
        );

    assert_count_eventually_reaches_max:
        assert property (@(posedge clk)
            (en && count < MAX_COUNT) |-> ##[1:$] (count == MAX_COUNT)
        );

    assert_count_stays_still_when_disabled:
        assert property (@(posedge clk)
            !en |-> ##[1:$] (count == $past(count))
        );

    assert_count_eventually_changes_after_reenable:
        assert property (@(posedge clk)
            (en && ! $past(en)) |-> ##[1:$] (count != $past(count))
        );
endmodule
