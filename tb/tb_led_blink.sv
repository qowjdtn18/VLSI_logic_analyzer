`timescale 1ns/1ps
// Delay unit: 1 ns. Time precision: 1 ps. Neither sets the physical board clock.
`default_nettype none

// Testbench skeleton for led_blink, with clock, reset, and waveform output.
// Fill in the TODOs to verify behaviour. Normal termination is not a functional PASS.
module tb_led_blink;
    // Short simulation interval: 10 clocks * 20 ns = 200 ns per LED toggle.
    // This overrides the RTL default of 25_000_000 clocks (0.5 s at 50 MHz).
    localparam integer TOGGLE_CYCLES = 10;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    wire led;

    led_blink #(
        .TOGGLE_CYCLES(TOGGLE_CYCLES)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .led(led)
    );

    // Model the nominal 50 MHz DE1-SoC FPGA clock: 1 / 50_000_000 Hz = 20 ns.
    // Invert clk every 10 ns, so rising edges are 20 ns (20_000 ps) apart.
    // Reference: Terasic DE1-SoC User Manual, 2019-01-28, section 3.5; see README.md.
    // This is simulation stimulus, not a board clock or pin configuration.
    always #10 clk = ~clk;

    initial begin
        $dumpfile("build/tb_led_blink.vcd");
        $dumpvars(0, tb_led_blink);

        // Drive inputs on negedge to avoid racing the DUT at posedge.
        repeat (3) @(negedge clk);
        // TODO(TB-LED-1): Check that led=0 during reset.
        rst_n = 1'b1;

        repeat (TOGGLE_CYCLES * 4 + 2) @(negedge clk);
        // TODO(TB-LED-2): Automatically check the first toggle and subsequent intervals.
        // TODO(TB-LED-3): Check reset during operation and TOGGLE_CYCLES=1.
        // Observe at negedge or after the posedge nonblocking assignments (NBA) update.
        // Use $fatal(1, ...) for mismatches/X; print PASS only after real checks pass.

        $display("SKELETON ONLY: stimulus finished; no LED behaviour checks implemented.");
        $finish;
    end

    // Prevent an endless simulation if wait statements are added later.
    initial begin
        #10_000;
        $fatal(1, "Timeout: tb_led_blink did not finish.");
    end
endmodule

`default_nettype wire
