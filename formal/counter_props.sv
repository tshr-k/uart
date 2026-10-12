module counter_props #(
    parameter int unsigned MODULO     = 256,
    parameter int unsigned MAX_EN_GAP = 4  // abstraction, not a real gap (see below)
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

    // count cycles since en was last asserted to bound the gap between enables
    // counter only changes state when enabled, so a short gap only removes idle cycles
    logic [$clog2(MAX_EN_GAP)-1:0] cycles_since_en;

    always_ff @(posedge clk or posedge a_rst) begin
        if (a_rst)
            cycles_since_en <= '0;
        else
            cycles_since_en <= en ? '0 : (cycles_since_en + 1);
    end

    // assume environment constraints
    // look back with $past rather than ahead with |=> or ##[m:n] due to fragile EBMC support
    assume_en_eventually_asserts:
        assume property (@(posedge clk)
            (cycles_since_en == MAX_EN_GAP-1) |-> en
        );

    // assert liveness properties
    assert_count_eventually_changes:
        assert property (@(posedge clk)
            en |=> s_eventually (count != $past(count))
        );

    assert_count_eventually_increments:
        assert property (@(posedge clk)
            (en && count < MAX_COUNT) |=> s_eventually (count == $past(count) + 1)
        );

    assert_count_eventually_wraps:
        assert property (@(posedge clk)
            (en && count == MAX_COUNT) |=> s_eventually (count == 0)
        );

    assert_count_eventually_reaches_zero:
        assert property (@(posedge clk)
            (en && count != 0) |=> s_eventually (count == 0)
        );

    assert_count_eventually_reaches_max:
        assert property (@(posedge clk)
            (en && count < MAX_COUNT) |=> s_eventually (count == MAX_COUNT)
        );

    assert_count_stays_still_when_disabled:
        assert property (@(posedge clk)
            (!a_rst && !en) |=> s_eventually (count == $past(count))
        );

    assert_count_eventually_changes_after_reenable:
        assert property (@(posedge clk)
            (en && ! $past(en)) |=> s_eventually (count != $past(count))
        );

    // assert safety properties
    // past_valid is low during reset and the cycle after it, when $past would sample pre-reset state
    // (guards are written explicitly because EBMC does not support disable iff)
    logic a_rst_d;
    logic past_valid;

    always_ff @(posedge clk)
        a_rst_d <= a_rst;

    assign past_valid = !a_rst && !a_rst_d;

    assert_count_zero_after_reset:
        assert property (@(posedge clk)
            $past(a_rst) |-> (count == 0)
        );

    assert_count_never_exceeds_max:
        assert property (@(posedge clk)
            !a_rst |-> (count <= MAX_COUNT)
        );

    assert_count_increments_when_enabled:
        assert property (@(posedge clk)
            (past_valid && $past(en && count != MAX_COUNT)) |-> (count == $past(count) + 1)
        );

    assert_count_wraps_when_enabled_at_max:
        assert property (@(posedge clk)
            (past_valid && $past(en && count == MAX_COUNT)) |-> (count == 0)
        );

    assert_count_holds_when_disabled:
        assert property (@(posedge clk)
            (past_valid && $past(!en)) |-> (count == $past(count))
        );
endmodule
