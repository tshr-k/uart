import utils_pkg::*;

module counter #(
    parameter int unsigned MODULO = 256
) (
    input  logic                          clk,
    input  logic                          a_rst,
    input  logic                          en,

    output logic [min1_clog2(MODULO)-1:0] count
);
    initial begin
        assert (MODULO > 0)
            else $fatal(1, "MODULO must be > 0");
    end

    typedef logic [min1_clog2(MODULO)-1:0] count_t;

    always_ff @(posedge clk or posedge a_rst) begin
        if (a_rst)
            count <= '0;
        else if (en)
            count <= (count == count_t'(MODULO-1)) ? '0 : (count + 1);
    end
endmodule
