`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////
// Module: newton_raphson_stage
//
// One Newton-Raphson refinement iteration for inverse square root:
//     out = y * (1.5 - x2 * y * y)
//
// Pipeline breakdown (total latency = 10 cycles):
//   Stage 1: fp_mult  — y_sq   = y_in * y_in              (3 cycles)
//   Stage 2: fp_fma   — term2  = (-x2_delayed) * y_sq + 1.5  (4 cycles)
//   Stage 3: fp_mult  — out    = y_delayed * term2         (3 cycles)
//
// Shift registers align operands:
//   - x2_in  delayed by 3 cycles  → arrives at FMA with y_sq
//   - y_in   delayed by 7 cycles  → arrives at final mult with term2
//
// Uses Xilinx AXI4-Stream floating-point IPs:
//   - fp_mult (latency 3)
//   - fp_fma  (latency 4, computes A*B + C)
//////////////////////////////////////////////////////////////////////////////

module newton_raphson_stage (
    input  wire        clk,
    input  wire [31:0] y_in,
    input  wire [31:0] x2_in,
    output wire [31:0] final_out,
    output wire        final_valid
);

    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------
    localparam [31:0] CONST_1P5 = 32'h3FC00000;  // IEEE 754 float 1.5

    // -----------------------------------------------------------------------
    // Shift register: delay x2_in by 3 cycles to align with y_sq output
    // -----------------------------------------------------------------------
    reg [31:0] x2_delay [0:2];
    integer i;

    always @(posedge clk) begin
        x2_delay[0] <= x2_in;
        for (i = 1; i < 3; i = i + 1) begin
            x2_delay[i] <= x2_delay[i-1];
        end
    end

    wire [31:0] x2_delayed = x2_delay[2];  // available after 3 cycles

    // -----------------------------------------------------------------------
    // Shift register: delay y_in by 7 cycles to align with term2 output
    // (3 cycles for y_sq + 4 cycles for FMA = 7 total)
    // -----------------------------------------------------------------------
    reg [31:0] y_delay [0:6];

    always @(posedge clk) begin
        y_delay[0] <= y_in;
        for (i = 1; i < 7; i = i + 1) begin
            y_delay[i] <= y_delay[i-1];
        end
    end

    wire [31:0] y_delayed = y_delay[6];  // available after 7 cycles

    // -----------------------------------------------------------------------
    // Stage 1: y_sq = y_in * y_in  (fp_mult, latency 3)
    // -----------------------------------------------------------------------
    wire [31:0] y_sq;
    wire        y_sq_valid;

    fp_mult mult_y_sq (
        .aclk                 (clk),
        .s_axis_a_tdata       (y_in),
        .s_axis_a_tvalid      (1'b1),
        .s_axis_b_tdata       (y_in),
        .s_axis_b_tvalid      (1'b1),
        .m_axis_result_tdata  (y_sq),
        .m_axis_result_tvalid (y_sq_valid)
    );

    // -----------------------------------------------------------------------
    // Negate x2_delayed: flip the sign bit (bit 31) to get -x2_delayed
    // -----------------------------------------------------------------------
    wire [31:0] neg_x2_delayed = {~x2_delayed[31], x2_delayed[30:0]};

    // -----------------------------------------------------------------------
    // Stage 2: term2 = (-x2_delayed) * y_sq + 1.5  (fp_fma, latency 4)
    //   FMA computes A*B + C
    //   A = -x2_delayed, B = y_sq, C = 1.5
    // -----------------------------------------------------------------------
    wire [31:0] term2;
    wire        term2_valid;

    fp_fma fma_term2 (
        .aclk                 (clk),
        .s_axis_a_tdata       (neg_x2_delayed),
        .s_axis_a_tvalid      (1'b1),
        .s_axis_b_tdata       (y_sq),
        .s_axis_b_tvalid      (1'b1),
        .s_axis_c_tdata       (CONST_1P5),
        .s_axis_c_tvalid      (1'b1),
        .m_axis_result_tdata  (term2),
        .m_axis_result_tvalid (term2_valid)
    );

    // -----------------------------------------------------------------------
    // Stage 3: final_out = y_delayed * term2  (fp_mult, latency 3)
    // -----------------------------------------------------------------------
    fp_mult mult_final (
        .aclk                 (clk),
        .s_axis_a_tdata       (y_delayed),
        .s_axis_a_tvalid      (1'b1),
        .s_axis_b_tdata       (term2),
        .s_axis_b_tvalid      (1'b1),
        .m_axis_result_tdata  (final_out),
        .m_axis_result_tvalid (final_valid)
    );

endmodule
