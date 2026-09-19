package uart_pkg;
    typedef enum bit [1:0] {
        PARITY_NONE,
        PARITY_ODD,
        PARITY_EVEN
    } parity_t;

    typedef enum bit [1:0] {
        STOP_1,
        STOP_1P5,
        STOP_2
    } stop_bits_t;

    typedef enum bit [2:0] {
        IDLE,
        START,
        DATA,
        PARITY,
        STOP
    } state_t;

    function automatic int unsigned stop_ticks(
        input stop_bits_t  stop_bits,
        input int unsigned oversample  // ticks per bit
    );
        // convert stop_bits to ticks
        unique case (stop_bits)
            STOP_1:   return 1 * oversample;
            STOP_1P5: return 3 * oversample / 2;
            STOP_2:   return 2 * oversample;
        endcase
    endfunction

    function automatic void validate_shared_params(
        input int unsigned data_bits,
        input stop_bits_t  stop_bits,
        input parity_t     parity_mode
    );
        // validate parameters common to UART receiver and transmitter
        assert (data_bits > 0)
            else $fatal(1, "DATA_BITS must be > 0");
        assert (stop_bits inside {STOP_1, STOP_1P5, STOP_2})
            else $fatal(1, "STOP_BITS must be STOP_1, STOP_1P5 or STOP_2");
        assert (parity_mode inside {PARITY_NONE, PARITY_ODD, PARITY_EVEN})
            else $fatal(1, "PARITY_MODE must be PARITY_NONE, PARITY_ODD or PARITY_EVEN");
    endfunction
endpackage
