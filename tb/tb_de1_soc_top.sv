`timescale 1ns/1ps
`default_nettype none

// Board-wrapper checks use a short divider and capture depth for quick simulation.
module tb_de1_soc_top;
    localparam integer CAPTURE_DEPTH = 8;

    logic CLOCK_50 = 1'b0;
    logic [1:0] KEY = 2'b10;
    logic [9:0] SW = '0;
    wire [9:0] LEDR;
    integer enable_pulses = 0;
    time previous_enable_time = 0;

    de1_soc_top #(
        .CLOCK_HZ(8),
        .SAMPLE_RATE_HZ(2),
        .CAPTURE_DEPTH(CAPTURE_DEPTH)
    ) dut (
        .CLOCK_50(CLOCK_50),
        .KEY(KEY),
        .SW(SW),
        .LEDR(LEDR)
    );

    // Model the physical 50 MHz board period even though divider parameters are scaled down.
    always #10 CLOCK_50 = ~CLOCK_50;

    // The scaled 8 Hz / 2 Hz parameters must produce one enable every four clocks.
    always @(posedge CLOCK_50) begin
        #1;
        if (!dut.rst_n || dut.start_pulse) begin
            enable_pulses = 0;
            previous_enable_time = 0;
        end else if (dut.sample_enable && dut.busy) begin
            if (enable_pulses > 0 && ($time - previous_enable_time) != 80)
                $fatal(1, "Sample enables were not four 20 ns clocks apart");
            previous_enable_time = $time;
            enable_pulses = enable_pulses + 1;
        end
    end

    task automatic inspect_after_edge;
        @(posedge CLOCK_50);
        #1;
    endtask

    task automatic press_start;
        @(negedge CLOCK_50);
        KEY[1] = 1'b0;
        repeat (4) inspect_after_edge();
        @(negedge CLOCK_50);
        KEY[1] = 1'b1;
    endtask

    initial begin
        $dumpfile("build/tb_de1_soc_top.vcd");
        $dumpvars(0, tb_de1_soc_top);

        // Hold KEY[0] low, then release it and wait for synchronized reset release.
        repeat (3) inspect_after_edge();
        if (LEDR !== '0) $fatal(1, "Reset did not clear board outputs");
        @(negedge CLOCK_50);
        KEY[0] = 1'b1;
        repeat (4) inspect_after_edge();
        if (LEDR !== '0) $fatal(1, "Idle board outputs are not zero");

        press_start();
        if (LEDR[8] !== 1'b1 || LEDR[9] !== 1'b0)
            $fatal(1, "Start did not enter capture state");

        wait (LEDR[9] === 1'b1);
        #1;
        if (LEDR[8] !== 1'b0) $fatal(1, "busy remained high after completion");
        if (enable_pulses != CAPTURE_DEPTH)
            $fatal(1, "Expected %0d sample enables, observed %0d", CAPTURE_DEPTH, enable_pulses);

        // Switches choose a completed sample; LEDs show the internal sequence 0..7.
        for (integer address = 0; address < CAPTURE_DEPTH; address++) begin
            @(negedge CLOCK_50);
            SW = 10'(address);
            repeat (3) inspect_after_edge();
            if (LEDR[7:0] !== 8'(address))
                $fatal(1, "Address %0d returned %0h", address, LEDR[7:0]);
        end

        // A second press restarts capture and clears done.
        press_start();
        if (LEDR[8] !== 1'b1 || LEDR[9] !== 1'b0)
            $fatal(1, "Restart did not clear done and assert busy");

        // Reset while busy must return to the idle display.
        @(negedge CLOCK_50);
        KEY[0] = 1'b0;
        inspect_after_edge();
        if (LEDR !== '0) $fatal(1, "Reset during capture did not clear board outputs");

        $display("PASS: de1_soc_top reset, start, sample-divider ratio, capture, switches, and LEDs");
        $finish;
    end

    initial begin
        #20_000;
        $fatal(1, "Timeout: tb_de1_soc_top did not finish");
    end
endmodule

`default_nettype wire
