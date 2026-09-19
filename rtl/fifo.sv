import utils_pkg::*;

module fifo #(
    parameter type         data_t = logic [7:0],  // synthesizable and packed
    parameter int unsigned DEPTH  = 16
) (
    input  logic  clk,
    input  logic  a_rst,
    input  logic  pop_en,
    input  logic  wr_en,
    input  data_t wr_data,

    output logic  empty,
    output logic  full,
    output data_t rd_data
);
    initial begin
        assert (DEPTH > 0)
            else $fatal(1, "DEPTH must be > 0");
    end

    typedef logic [min1_clog2(DEPTH)-1:0] ptr_t;
    typedef logic [$clog2(DEPTH+1)-1:0]   count_t;

    data_t  data_array [0:DEPTH-1];
    ptr_t   wr_ptr;
    ptr_t   rd_ptr;
    count_t count;

    logic   wr_ok;
    logic   pop_ok;

    function automatic ptr_t next_ptr(input ptr_t ptr);
        // advance ptr with wraparound
        if (ptr == ptr_t'(DEPTH-1))
            return '0;
        else
            return ptr + 1;
    endfunction

    always_ff @(posedge clk or posedge a_rst) begin
        if (a_rst) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            count  <= '0;
        end else begin
            // both write and pop can occur on same clock edge
            if (wr_ok) begin
                data_array[wr_ptr] <= wr_data;
                wr_ptr <= next_ptr(wr_ptr);
            end

            if (pop_ok) begin
                rd_ptr <= next_ptr(rd_ptr);
            end

            unique case ({wr_ok, pop_ok})
                2'b10:   count <= count + 1;
                2'b01:   count <= count - 1;
                default: ;
            endcase
        end
    end

    assign empty   = (count == '0);
    assign full    = (count == count_t'(DEPTH));
    assign rd_data = data_array[rd_ptr];  // asynchronous read

    assign wr_ok   = wr_en  && !full;  // rejected if full
    assign pop_ok  = pop_en && !empty;  // rejected if empty
endmodule
