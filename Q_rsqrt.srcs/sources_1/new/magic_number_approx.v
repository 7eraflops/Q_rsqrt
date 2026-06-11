`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////
// Module: magic_number_approx
//
// Quake III "magic number" initial approximation for inverse square root.
// Treats the 32-bit IEEE 754 float as an integer, performs:
//     y = 0x5F3759DF - (x >> 1)
// Result is registered on the rising edge of clk.
//////////////////////////////////////////////////////////////////////////////

module magic_number_approx (
    input  wire        clk,
    input  wire [31:0] x,
    output reg  [31:0] y_out
);

    always @(posedge clk) begin
        y_out <= 32'h5F3759DF - (x >> 1);
    end

endmodule
