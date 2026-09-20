package tick_gen_pkg;
    function automatic void validate_tick_gen_params(
        input int unsigned clk_freq_hz  = 50_000_000,
        input int unsigned tick_freq_hz = 115_200
    );
        assert (clk_freq_hz > 0)
            else $fatal(1, "CLK_FREQ_HZ must be > 0");
        assert (tick_freq_hz > 0)
            else $fatal(1, "TICK_FREQ_HZ must be > 0");
        assert (tick_freq_hz < clk_freq_hz)  // clock division must be possible
            else $fatal(1, "TICK_FREQ_HZ must be < CLK_FREQ_HZ");
    endfunction
endpackage
