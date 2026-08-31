`timescale 1ns/1ps
`default_nettype none

// Directed checks for capture ordering, control timing, readback, and restart.
// Override CHANNELS/DEPTH at compilation to exercise the same checks at other sizes.
module tb_logic_analyzer #(
    parameter integer CHANNELS = 8,
    parameter integer DEPTH = 8
);
    localparam integer ADDR_WIDTH = (DEPTH > 1) ? $clog2(DEPTH) : 1;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic start = 1'b0;
    logic sample_en = 1'b0;
    logic [CHANNELS-1:0] sample_in = '0;
    wire busy;
    wire done;
    logic read_en = 1'b0;
    logic [ADDR_WIDTH-1:0] read_addr = '0;
    wire [CHANNELS-1:0] read_data;
    wire read_valid;
    logic [CHANNELS-1:0] expected_samples [0:DEPTH-1];

    logic_analyzer #(.CHANNELS(CHANNELS), .DEPTH(DEPTH)) dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .sample_en(sample_en), .sample_in(sample_in),
        .busy(busy), .done(done),
        .read_en(read_en), .read_addr(read_addr),
        .read_data(read_data), .read_valid(read_valid)
    );

    // A 10 ns simulation clock, independent of the board configuration.
    always #5 clk = ~clk;

    // Drive inputs at negedge; inspect results after the posedge NBA updates.
    task automatic step;
        @(posedge clk);
        #1;
    endtask

    task automatic expect_status(
        input logic want_busy, input logic want_done, input logic want_valid,
        input string phase
    );
        // Case inequality treats X/Z on any control output as a failure.
        if ({busy, done, read_valid} !== {want_busy, want_done, want_valid})
            $fatal(1, "%s: busy/done/read_valid=%b%b%b, expected %b%b%b",
                   phase, busy, done, read_valid, want_busy, want_done, want_valid);
    endtask

    task automatic expect_data(input logic [CHANNELS-1:0] value, input string phase);
        if (read_data !== value)
            $fatal(1, "%s: read_data=%h, expected %h", phase, read_data, value);
    endtask

    task automatic reset_core;
        @(negedge clk);
        rst_n = 1'b0;
        // Reset must take priority over all requests.
        start = 1'b1;
        sample_en = 1'b1;
        read_en = 1'b1;
        repeat (2) begin
            step();
            expect_status(0, 0, 0, "reset");
            expect_data('0, "reset");
        end
        @(negedge clk);
        rst_n = 1'b1;
        start = 1'b0;
        sample_en = 1'b0;
        read_en = 1'b0;
        step();
        expect_status(0, 0, 0, "reset released");
    endtask

    task automatic check_before_capture;
        @(negedge clk);
        read_en = 1'b1;
        read_addr = '0;
        sample_en = 1'b1;
        sample_in = '1;
        step();
        expect_status(0, 0, 0, "requests before capture");
        expect_data('0, "no completed data");
    endtask

    task automatic capture_pattern(input integer seed, input bit with_gaps);
        logic [CHANNELS-1:0] held_data;
        held_data = read_data;
        @(negedge clk);
        start = 1'b1;
        read_en = 1'b1;
        read_addr = '0;
        sample_en = 1'b1;
        // This differs from sample zero and must NOT be captured on the start edge.
        sample_in = ~CHANNELS'(seed);
        step();
        expect_status(1, 0, 0, "start has priority over sample and read");
        expect_data(held_data, "start holds read_data");

        for (integer i = 0; i < DEPTH; i++) begin
            @(negedge clk);
            start = 1'b0;
            read_en = 1'b1;
            if (with_gaps) begin
                sample_en = 1'b0;
                sample_in = '1;
                step();
                expect_status(1, 0, 0, "gap during capture");
                expect_data(held_data, "read blocked during gap");
                @(negedge clk);
            end

            expected_samples[i] = CHANNELS'(seed + i * 17);
            sample_in = expected_samples[i];
            sample_en = 1'b1;
            // A busy start, including one on the final write, must be ignored.
            start = (i == DEPTH / 2 || i == DEPTH - 1);
            step();
            if (i == DEPTH - 1)
                expect_status(0, 1, 0, "last sample finishes capture");
            else
                expect_status(1, 0, 0, "capture in progress");
            expect_data(held_data, "read blocked on write edge");
        end

        // Extra sample requests after completion must not overwrite stored values.
        repeat (2) begin
            @(negedge clk);
            start = 1'b0;
            read_en = 1'b0;
            sample_en = 1'b1;
            sample_in = ~expected_samples[0];
            step();
            expect_status(0, 1, 0, "capture remains complete");
            expect_data(held_data, "read_data holds after completion");
        end
    endtask

    task automatic read_capture;
        // Consecutive requests must return one stored sample per rising edge.
        for (integer i = 0; i < DEPTH; i++) begin
            @(negedge clk);
            sample_en = 1'b0;
            read_en = 1'b1;
            read_addr = ADDR_WIDTH'(i);
            step();
            expect_status(0, 1, 1, "valid read");
            expect_data(expected_samples[i], $sformatf("read address %0d", i));
        end
        @(negedge clk);
        read_en = 1'b0;
        step();
        expect_status(0, 1, 0, "read_valid clears without a request");
        expect_data(expected_samples[DEPTH-1], "idle read_data holds");

        // A non-power-of-two depth (also DEPTH=1) leaves unused address encodings.
        if (DEPTH < (2 ** ADDR_WIDTH)) begin
            @(negedge clk);
            read_en = 1'b1;
            read_addr = ADDR_WIDTH'(DEPTH);
            step();
            expect_status(0, 1, 0, "out-of-range read rejected");
            expect_data(expected_samples[DEPTH-1], "invalid read_data holds");
        end
    endtask

    initial begin
        $dumpfile("build/tb_logic_analyzer.vcd");
        $dumpvars(0, tb_logic_analyzer);
        if (CHANNELS < 1 || DEPTH < 1)
            $fatal(1, "CHANNELS and DEPTH must be positive");

        reset_core();
        check_before_capture();
        capture_pattern(17, 1);
        read_capture();
        capture_pattern(90, 0);
        read_capture();

        // Abort a capture and prove that old data is inaccessible after reset.
        @(negedge clk);
        start = 1'b1;
        read_en = 1'b0;
        sample_en = 1'b0;
        step();
        expect_status(1, 0, 0, "capture to abort");
        @(negedge clk);
        start = 1'b0;
        sample_en = (DEPTH > 1);
        sample_in = '1;
        step();
        expect_status(1, 0, 0, "partially filled or paused capture");
        reset_core();
        check_before_capture();
        capture_pattern(165, 0);
        read_capture();

        $display("PASS: logic_analyzer CHANNELS=%0d DEPTH=%0d: capture, readback, restart, and reset checks",
                 CHANNELS, DEPTH);
        $finish;
    end

    initial begin
        #(10 * (20 * DEPTH + 100));
        $fatal(1, "Timeout: tb_logic_analyzer did not finish");
    end
endmodule

`default_nettype wire
