module fifo_props #(
    parameter int unsigned DATA_BITS   = 8,   // must match width of fifo's default DATA_T
    parameter int unsigned DEPTH       = 16,
    parameter int unsigned MAX_POP_GAP = 4,   // abstraction, not a real gap (see below)
    parameter int unsigned MAX_WR_GAP  = 4    // abstraction, not a real gap (see below)
) (
    input logic                 clk,
    input logic                 a_rst,
    input logic                 pop_en,
    input logic                 wr_en,
    input logic [DATA_BITS-1:0] wr_data
);
    typedef logic [DATA_BITS-1:0] data_t;

    logic  empty;
    logic  full;
    data_t rd_data;

    fifo #(
        .DEPTH (DEPTH)
    ) dut (
        .clk     (clk),
        .a_rst   (a_rst),
        .pop_en  (pop_en),
        .wr_en   (wr_en),
        .wr_data (wr_data),
        .empty   (empty),
        .full    (full),
        .rd_data (rd_data)
    );

    // count cycles a non-empty fifo has waited for a pop (and a non-full fifo for a write)
    // to bound the consumer's and producer's latency
    // fifo only changes state on a pop or write, so short gaps only remove idle cycles
    logic [$clog2(MAX_POP_GAP)-1:0] cycles_since_pop;
    logic [$clog2(MAX_WR_GAP)-1:0]  cycles_since_wr;

    always_ff @(posedge clk or posedge a_rst) begin
        if (a_rst)
            cycles_since_pop <= '0;
        else
            cycles_since_pop <= (pop_en || empty) ? '0 : (cycles_since_pop + 1);
    end

    always_ff @(posedge clk or posedge a_rst) begin
        if (a_rst)
            cycles_since_wr <= '0;
        else
            cycles_since_wr <= (wr_en || full) ? '0 : (cycles_since_wr + 1);
    end

    // assume environment constraints
    assume_no_pop_when_empty:
        assume property (@(posedge clk)
            empty |-> !pop_en
        );

    assume_no_write_when_full:
        assume property (@(posedge clk)
            full |-> !wr_en
        );

    assume_pop_eventually_when_nonempty:
        assume property (@(posedge clk)
            (!empty && cycles_since_pop == MAX_POP_GAP-1) |-> pop_en
        );

    assume_write_eventually_when_nonfull:
        assume property (@(posedge clk)
            (!full && cycles_since_wr == MAX_WR_GAP-1) |-> wr_en
        );

    // assert liveness properties
    assert_fifo_eventually_nonempty_after_write:
        assert property (@(posedge clk)
            (wr_en && empty) |=> s_eventually !empty
        );

    assert_fifo_eventually_nonfull_after_pop:
        assert property (@(posedge clk)
            (pop_en && full) |=> s_eventually !full
        );

    assert_fifo_eventually_leaves_full:
        assert property (@(posedge clk)
            full |=> s_eventually !full
        );

    assert_fifo_eventually_leaves_empty:
        assert property (@(posedge clk)
            empty |=> s_eventually !empty
        );

    assert_fifo_stays_still_when_idle:
        assert property (@(posedge clk)
            (!a_rst && !wr_en && !pop_en) |=> s_eventually (
                empty   == $past(empty) &&
                full    == $past(full)  &&
                rd_data == $past(rd_data)
            )
        );

    assert_fifo_eventually_changes_after_reenable:
        assert property (@(posedge clk)
            ((wr_en && !$past(wr_en) && empty) || (pop_en && !$past(pop_en) && full))
                |=> s_eventually (empty != $past(empty) || full != $past(full))
        );

    // assert safety properties
    // past_valid is low during reset and the cycle after it, when $past would sample pre-reset state
    // (guards are written explicitly because EBMC does not support disable iff)
    logic a_rst_d;
    logic past_valid;

    always_ff @(posedge clk)
        a_rst_d <= a_rst;

    assign past_valid = !a_rst && !a_rst_d;

    // track occupancy independently of the fifo's own count
    logic [$clog2(DEPTH+1)-1:0] occupancy;

    always_ff @(posedge clk or posedge a_rst) begin
        if (a_rst)
            occupancy <= '0;
        else
            case ({wr_en && !full, pop_en && !empty})
                2'b10:   occupancy <= occupancy + 1;
                2'b01:   occupancy <= occupancy - 1;
                default: ;
            endcase
    end

    assert_fifo_empty_after_reset:
        assert property (@(posedge clk)
            $past(a_rst) |-> (empty && !full)
        );

    assert_fifo_never_empty_and_full:
        assert property (@(posedge clk)
            !a_rst |-> !(empty && full)
        );

    assert_empty_matches_occupancy:
        assert property (@(posedge clk)
            !a_rst |-> (empty == (occupancy == 0))
        );

    assert_full_matches_occupancy:
        assert property (@(posedge clk)
            !a_rst |-> (full == (occupancy == DEPTH))
        );

    assert_fifo_nonempty_after_write:
        assert property (@(posedge clk)
            (past_valid && $past(wr_en && !full)) |-> !empty
        );

    assert_fifo_nonfull_after_pop:
        assert property (@(posedge clk)
            (past_valid && $past(pop_en && !empty)) |-> !full
        );

    assert_write_to_empty_fifo_appears_at_head:
        assert property (@(posedge clk)
            (past_valid && $past(wr_en && empty)) |-> (rd_data == $past(wr_data))
        );

    assert_head_holds_until_pop:
        assert property (@(posedge clk)
            (past_valid && $past(!empty && !pop_en)) |-> (rd_data == $past(rd_data))
        );
endmodule
