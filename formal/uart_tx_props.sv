module uart_tx_props #(
    parameter int unsigned DATA_BITS    = 8,     // must match uart_tx's default DATA_BITS
    parameter bit          PARITY_EN    = 1'b1,  // must match uart_tx's default PARITY_CFG
    parameter bit          PARITY_ODD   = 1'b0,  // must match uart_tx's default PARITY_CFG
    parameter int unsigned STOP_BITS    = 1,     // must match uart_tx's default STOP_BITS_CFG
    parameter int unsigned MAX_TICK_GAP = 4      // abstraction, not the real gap (see below)
) (
    input logic                 clk,
    input logic                 a_rst,
    input logic                 en_tick,
    input logic                 data_ready,
    input logic [DATA_BITS-1:0] data_in
);
    localparam int unsigned FRAME_BITS = 1 + DATA_BITS + PARITY_EN + STOP_BITS;

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

    // count the ticks left in the frame uart_tx has committed to, using only its ports
    // it commits when it samples data_ready on a tick while idle or on the final tick of a frame,
    // and that frame then takes FRAME_BITS more ticks (start, data, parity and stop bits)
    logic [$clog2(FRAME_BITS+1)-1:0] ticks_left;

    always_ff @(posedge clk or posedge a_rst) begin
        if (a_rst)
            ticks_left <= '0;
        else if (en_tick) begin
            if (ticks_left <= 1)
                ticks_left <= data_ready ? FRAME_BITS : 0;
            else
                ticks_left <= ticks_left - 1;
        end
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

    assume_data_in_stable_during_frame:
        assume property (@(posedge clk)
            $past(ticks_left != 0) |-> (data_in == $past(data_in))
        );

    // assert liveness properties
    assert_tx_eventually_starts_frame:
        assert property (@(posedge clk)
            (!a_rst && en_tick && data_ready && ticks_left <= 1) |=> s_eventually !tx
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

    // assert safety properties
    // past_valid is low during reset and the cycle after it, when $past would sample pre-reset state
    // (guards are written explicitly because EBMC does not support disable iff)
    logic a_rst_d;
    logic past_valid;

    always_ff @(posedge clk)
        a_rst_d <= a_rst;

    assign past_valid = !a_rst && !a_rst_d;

    // record tx after every tick so the whole frame can be checked when done_tick rises
    // (oldest bit in the LSB, so the start bit is at bit 0 of the frame)
    logic                  tick_d;
    logic [FRAME_BITS-2:0] tx_history;
    logic [FRAME_BITS-1:0] frame;

    always_ff @(posedge clk or posedge a_rst) begin
        if (a_rst) begin
            tick_d     <= 1'b0;
            tx_history <= '1;
        end else begin
            tick_d <= en_tick;

            if (tick_d)
                tx_history <= {tx, tx_history[FRAME_BITS-2:1]};
        end
    end

    assign frame = {tx, tx_history};

    assert_tx_idle_after_reset:
        assert property (@(posedge clk)
            $past(a_rst) |-> (tx && !done_tick)
        );

    assert_outputs_change_only_after_tick:
        assert property (@(posedge clk)
            (past_valid && (tx != $past(tx) || done_tick != $past(done_tick))) |-> $past(en_tick)
        );

    assert_tx_high_during_done_tick:
        assert property (@(posedge clk)
            (!a_rst && done_tick) |-> tx
        );

    assert_done_tick_lasts_one_bit:
        assert property (@(posedge clk)
            (past_valid && $past(en_tick && done_tick)) |-> !done_tick
        );

    assert_done_tick_iff_frame_ends:
        assert property (@(posedge clk)
            (past_valid && $past(en_tick)) |-> (done_tick == $past(ticks_left == 1))
        );

    assert_frame_start_bit_low:
        assert property (@(posedge clk)
            (past_valid && $rose(done_tick)) |-> !frame[0]
        );

    assert_frame_data_bits_match:
        assert property (@(posedge clk)
            (past_valid && $rose(done_tick)) |-> (frame[DATA_BITS:1] == data_in)
        );

    assert_frame_parity_bit_correct:
        assert property (@(posedge clk)
            (past_valid && $rose(done_tick) && PARITY_EN) |-> (frame[DATA_BITS+1] == (^data_in ^ PARITY_ODD))
        );

    assert_frame_stop_bits_high:
        assert property (@(posedge clk)
            (past_valid && $rose(done_tick)) |-> (&frame[FRAME_BITS-1:FRAME_BITS-STOP_BITS])
        );
endmodule
