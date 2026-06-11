`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////
// Module: float_divide_by_two
//
// Divides an IEEE 754 single-precision float by 2 by decrementing the
// 8-bit exponent field (bits [30:23]) by 1.
// Bypass: if x == 0, output 0 (avoids corrupting the zero encoding).
// Result is registered on the rising edge of clk.
//////////////////////////////////////////////////////////////////////////////

module float_divide_by_two (
    input  wire        clk,
    input  wire [31:0] x,
    output reg  [31:0] x2_out
);

    always @(posedge clk) begin
        if (x == 32'h00000000) begin
            x2_out <= 32'h00000000;
        end else begin
            // Sign stays the same, exponent decremented by 1, mantissa unchanged
            x2_out <= {x[31], x[30:23] - 8'd1, x[22:0]};
        end
    end

endmodule
