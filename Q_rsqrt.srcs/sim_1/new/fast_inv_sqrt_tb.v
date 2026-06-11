`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////
// Testbench: fast_inv_sqrt_tb
//
// Drives a set of IEEE 754 test vectors through the pipelined inverse
// square root core, collects results, and compares them against the exact
// mathematical value  1 / sqrt(x).
//
// Reports absolute and relative (%) error for every test case and prints
// a PASS/FAIL summary at the end.
//////////////////////////////////////////////////////////////////////////////

module fast_inv_sqrt_tb;

    // -----------------------------------------------------------------------
    // Parameters
    // -----------------------------------------------------------------------
    localparam CLK_PERIOD   = 10;            // ns  (100 MHz)
    localparam NUM_TESTS    = 10;
    localparam real ERR_THRESHOLD = 2.0;     // max allowed % error

    // -----------------------------------------------------------------------
    // DUT signals
    // -----------------------------------------------------------------------
    reg         clk;
    reg  [31:0] data_in;
    wire [31:0] data_out;
    wire        data_valid;

    // -----------------------------------------------------------------------
    // Clock generation
    // -----------------------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // -----------------------------------------------------------------------
    // DUT
    // -----------------------------------------------------------------------
    fast_inv_sqrt_top uut (
        .clk       (clk),
        .data_in   (data_in),
        .data_out  (data_out),
        .data_valid(data_valid)
    );

    // -----------------------------------------------------------------------
    // Test vector storage
    // -----------------------------------------------------------------------
    reg [31:0] test_inputs  [0:NUM_TESTS-1];
    reg [31:0] result_store [0:NUM_TESTS-1];
    integer    results_collected;

    // -----------------------------------------------------------------------
    // Populate test vectors  (IEEE 754 hex encodings)
    // -----------------------------------------------------------------------
    initial begin
        test_inputs[0] = 32'h3F800000;  //   1.0
        test_inputs[1] = 32'h40800000;  //   4.0
        test_inputs[2] = 32'h40000000;  //   2.0
        test_inputs[3] = 32'h3E800000;  //   0.25
        test_inputs[4] = 32'h42C80000;  // 100.0
        test_inputs[5] = 32'h41200000;  //  10.0
        test_inputs[6] = 32'h3F000000;  //   0.5
        test_inputs[7] = 32'h40A00000;  //   5.0
        test_inputs[8] = 32'h41C80000;  //  25.0
        test_inputs[9] = 32'h3DCCCCCD;  //   0.1
    end

    // -----------------------------------------------------------------------
    // Drive inputs:  feed one test value per clock cycle, then hold zero.
    // -----------------------------------------------------------------------
    integer feed_idx;

    initial begin
        // IMPORTANT: Wait for Xilinx Global Set/Reset (GSR) to release.
        // We wait 500ns to let the GSR fully release and allow the pipeline 
        // to completely flush out any 'X' or initial garbage states with zeros.
        #500;

        data_in  = 32'h00000000;
        feed_idx = 0;

        // Drive inputs on the FALLING edge (negedge).
        // In post-synthesis and timing simulations, physical clock networks have routing delays.
        // Driving inputs exactly on the rising edge causes setup/hold violations.
        @(negedge clk);

        // feed test vectors (one per cycle)
        for (feed_idx = 0; feed_idx < NUM_TESTS; feed_idx = feed_idx + 1) begin
            data_in = test_inputs[feed_idx];
            @(negedge clk);
        end

        // hold zero for the remaining pipeline drain
        data_in = 32'h00000000;
    end

    // -----------------------------------------------------------------------
    // Collect outputs (Auto-Aligning)
    // -----------------------------------------------------------------------
    integer timeout_counter;
    
    initial begin
        results_collected = 0;
        timeout_counter = 0;

        // Wait out the GSR flush, same as the drive thread
        #500;

        // Auto-detect pipeline latency by synchronously polling for the first
        // valid (non-zero, non-X) floating point result. This makes the testbench
        // immune to Vivado changing IP latency during synthesis mapping.
        while (1) begin
            @(negedge clk);
            timeout_counter = timeout_counter + 1;
            
            if (timeout_counter > 100) begin
                $display("\n============================================");
                $display(" ERROR: Simulation Timeout!");
                $display(" Pipeline failed to produce any valid data.");
                $display("============================================\n");
                $finish;
            end

            // Check if data is completely stable (No X's) and not zero
            if (^data_out !== 1'bX && data_out !== 32'h00000000) begin
                result_store[results_collected] = data_out;
                results_collected = results_collected + 1;
                break; // Found the start of the data burst!
            end
        end

        // Collect the remaining (NUM_TESTS - 1) results back-to-back
        while (results_collected < NUM_TESTS) begin
            @(negedge clk);
            result_store[results_collected] = data_out;
            results_collected = results_collected + 1;
        end

        // let the pipeline flush a couple more cycles
        repeat (4) @(posedge clk);

        // now validate
        validate_results();

        $display("");
        $display("============================================");
        $display("  Simulation complete.");
        $display("============================================");
        $finish;
    end

    // -----------------------------------------------------------------------
    // Validation task
    // -----------------------------------------------------------------------
    task validate_results;
        integer  k;
        real     x_val, expected, got, abs_err, pct_err;
        integer  pass_count, fail_count;
    begin
        pass_count = 0;
        fail_count = 0;

        $display("");
        $display("=========================================================================================");
        $display("  #  |   Input (hex)   |   x value   |  Expected 1/sqrt(x)  |   Got (float)   | Err (%%)");
        $display("=========================================================================================");

        for (k = 0; k < NUM_TESTS; k = k + 1) begin
            x_val    = $bitstoshortreal(test_inputs[k]);
            expected = 1.0 / $sqrt(x_val);
            got      = $bitstoshortreal(result_store[k]);

            abs_err  = (got > expected) ? (got - expected) : (expected - got);

            if (expected != 0.0)
                pct_err = (abs_err / expected) * 100.0;
            else
                pct_err = 0.0;

            if (pct_err <= ERR_THRESHOLD) begin
                $display(" %2d  |   0x%08H   | %11.5f | %20.10f | %15.10f | %6.3f  PASS",
                         k, test_inputs[k], x_val, expected, got, pct_err);
                pass_count = pass_count + 1;
            end else begin
                $display(" %2d  |   0x%08H   | %11.5f | %20.10f | %15.10f | %6.3f  FAIL",
                         k, test_inputs[k], x_val, expected, got, pct_err);
                fail_count = fail_count + 1;
            end
        end

        $display("=========================================================================================");
        $display("  Summary:  %0d / %0d PASSED    |   Error threshold: %.1f%%",
                 pass_count, NUM_TESTS, ERR_THRESHOLD);

        if (fail_count > 0)
            $display("  *** %0d test(s) FAILED ***", fail_count);
        else
            $display("  All tests PASSED.");

        $display("=========================================================================================");
    end
    endtask

endmodule