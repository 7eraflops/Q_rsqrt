`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////
// Module: zedboard_vio_top
//
// Top-level wrapper for VIO (Virtual Input/Output) hardware verification.
//
// Connects the Fast Inverse Square Root pipeline to a VIO core,
// allowing 32-bit test vectors to be driven from the Vivado GUI
// and reading back the 32-bit result and 1-bit valid flag.
//////////////////////////////////////////////////////////////////////////////

module zedboard_vio_top (
    input wire clk
);

    // Internal wires connecting the VIO core to the algorithm pipeline
    wire [31:0] vio_data_in;   // 32-bit input value provided by VIO GUI
    wire [31:0] algo_data_out; // 32-bit computed result
    wire algo_data_valid;      // 1-bit valid flag

    // Instantiate the Virtual I/O (VIO) core
    vio_0 vio_inst (
        .clk(clk),
        .probe_in0(algo_data_out),     // 32-bit input to VIO (reading the result)
        .probe_in1(algo_data_valid),   // 1-bit input to VIO (reading the valid flag)
        .probe_out0(vio_data_in)       // 32-bit output from VIO (driving the pipeline)
    );

    // Instantiate the Fast Inverse Square Root pipeline
    fast_inv_sqrt_top inv_sqrt_inst (
        .clk(clk),
        .data_in(vio_data_in),
        .data_out(algo_data_out),
        .data_valid(algo_data_valid)
    );

endmodule
