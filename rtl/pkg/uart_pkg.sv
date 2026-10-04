package uart_pkg;
    typedef enum bit [1:0] {
        PARITY_NONE,
        PARITY_ODD,
        PARITY_EVEN
    } parity_cfg_t;

    typedef enum bit [1:0] {
        STOP_1,
        STOP_1P5,
        STOP_2
    } stop_bits_cfg_t;

    typedef enum logic [2:0] {
        IDLE,
        START,
        DATA,
        PARITY,
        STOP
    } state_t;

    // convert stop_bits_cfg to ticks
    function automatic int unsigned stop_ticks(
        input stop_bits_cfg_t stop_bits_cfg,
        input int unsigned    oversample  // ticks per bit
    );
        unique case (stop_bits_cfg)
            STOP_1:   return 1 * oversample;
            STOP_1P5: return 3 * oversample / 2;
            STOP_2:   return 2 * oversample;
        endcase
    endfunction

    // validate parameters common to UART receiver and transmitter
    function automatic void validate_shared_uart_params(
        input int unsigned    data_bits,
        input stop_bits_cfg_t stop_bits_cfg,
        input parity_cfg_t    parity_cfg
    );
        assert (data_bits > 0)
            else $fatal(1, "DATA_BITS must be > 0");
        assert (stop_bits_cfg inside {STOP_1, STOP_1P5, STOP_2})
            else $fatal(1, "STOP_BITS_CFG must be STOP_1, STOP_1P5 or STOP_2");
        assert (parity_cfg inside {PARITY_NONE, PARITY_ODD, PARITY_EVEN})
            else $fatal(1, "PARITY_CFG must be PARITY_NONE, PARITY_ODD or PARITY_EVEN");
    endfunction

    function automatic void validate_oversample_param(input int unsigned oversample);
        assert (oversample > 1)
            else $fatal(1, "OVERSAMPLE must be > 1");
        assert (oversample % 2 == 0)
            else $fatal(1, "OVERSAMPLE must be even");
    endfunction
endpackage
