module uart_tx_props #(
    parameter int unsigned DATA_BITS    = 8,  // must match uart_tx's default DATA_BITS
    parameter int unsigned MAX_TICK_GAP = 4   // abstraction, not the real gap (see below)
) (
    input logic                 clk,
    input logic                 a_rst,
    input logic                 en_tick,
    input logic                 data_ready,
    input logic [DATA_BITS-1:0] data_in
);
    logic tx;
    logic done_tick;

    uart_tx #(
        .DATA_BITS (DATA_BITS)
    ) dut (
        .clk        (clk),
        .a_rst      (a_rst),
        .en_tick    (en_tick),
        .data_ready (data_ready),
        .data_in    (data_in),
        .tx         (tx),
        .done_tick  (done_tick)
    );

    // count cycles since the last tick to bound the gap between ticks
    // the real gap is ~CLK_FREQ_HZ/TICK_FREQ_HZ cycles, but uart_tx only changes state on a tick,
    // so a shorter gap only removes idle cycles and lets frames complete within the bound
    logic [$clog2(MAX_TICK_GAP)-1:0] cycles_since_tick;

    always_ff @(posedge clk or posedge a_rst) begin
        if (a_rst)
            cycles_since_tick <= '0;
        else
            cycles_since_tick <= en_tick ? '0 : (cycles_since_tick + 1);
    end

    // assume environment constraints
    // look back with $past rather than ahead with |=> or ##[m:n] due to fragile EBMC support
    assume_en_tick_is_single_cycle_pulse:
        assume property (@(posedge clk)
            $past(en_tick) |-> !en_tick
        );

    assume_en_tick_eventually_asserts:
        assume property (@(posedge clk)
            (cycles_since_tick == MAX_TICK_GAP-1) |-> en_tick
        );

    assume_data_ready_held_until_done:
        assume property (@(posedge clk)
            $past(data_ready && !done_tick) |-> data_ready
        );

    assume_data_in_stable_until_done:
        assume property (@(posedge clk)
            $past(data_ready && !done_tick) |-> (data_in == $past(data_in))
        );

    // assert liveness properties
    assert_tx_eventually_starts_frame:
        assert property (@(posedge clk)
            (!a_rst && en_tick && data_ready) |=> s_eventually !tx
        );

    assert_tx_eventually_returns_high:
        assert property (@(posedge clk)
            (en_tick && !tx) |=> s_eventually tx
        );

    assert_done_tick_eventually_asserts:
        assert property (@(posedge clk)
            (!a_rst && en_tick && data_ready) |=> s_eventually done_tick
        );

    assert_done_tick_eventually_deasserts:
        assert property (@(posedge clk)
            (en_tick && done_tick) |=> s_eventually !done_tick
        );

    assert_tx_eventually_starts_next_frame:
        assert property (@(posedge clk)
            (!a_rst && en_tick && done_tick && data_ready) |=> s_eventually !tx
        );

    assert_tx_stays_still_without_tick:
        assert property (@(posedge clk)
            !en_tick |=> s_eventually (tx == $past(tx))
        );

    assert_done_tick_stays_still_without_tick:
        assert property (@(posedge clk)
            !en_tick |=> s_eventually (done_tick == $past(done_tick))
        );
endmodule
