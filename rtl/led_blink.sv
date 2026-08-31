`timescale 1ns/1ps
`default_nettype none

/*
 * @file led_blink.sv
 * @brief Counter-based LED blink example with synchronous reset.
 *
 * Purpose: count rising edges of clk and toggle led at a fixed interval.
 * Parameter: TOGGLE_CYCLES >= 1, the number of clocks between LED toggles.
 *            A full LED period is 2 * TOGGLE_CYCLES clocks.
 * Inputs: clk (1 bit), rst_n (1 bit, active-low synchronous reset).
 * Output: led (1 bit). Set it to 0 on a rising edge that samples reset low.
 * Timing: the first toggle is on the TOGGLE_CYCLES-th rising edge after reset
 *         is released.
 * Limits: no board pins or clock frequency are assigned. A physical reset
 *         button needs input handling, including synchronization, in a board wrapper.
 * Testbench: tb/tb_led_blink.sv supplies stimulus; its check TODOs remain open.
 */

module led_blink #(
    // With a 50 MHz input clock, 25_000_000 cycles take 0.5 s.
    // The LED toggles every 0.5 s; a full off/on period takes 1 s (1 Hz).
    // This parameter counts input edges; it does not generate or set the clock.
    // DE1-SoC clock reference and pending board checks: README.md.
    parameter integer TOGGLE_CYCLES = 25_000_000
) (
    input  logic clk,
    input  logic rst_n,
    output logic led
);

    // Count from 0 to TOGGLE_CYCLES - 1; keep at least one bit for a period of 1.. calculate the width of the counter.
    localparam integer COUNTER_WIDTH = (TOGGLE_CYCLES > 1) ? $clog2(TOGGLE_CYCLES) : 1;
    logic [COUNTER_WIDTH-1:0] counter;// Counter for the number of clock cycles since the last toggle.

    always_ff @(posedge clk) begin
        if (!rst_n) begin// if reset is assered, reset the counter/led to zero.
            counter <= '0;//counter is zero.
            led <= 1'b0;//led is off
        end else if (counter == TOGGLE_CYCLES - 1) begin//if counter hits the ceiling, reset to zero.
            counter <= '0;//reset counter to zero.
            led <= ~led;//flip the LED state
        end else begin//increment the counter...
            counter <= counter + 1'b1;
            // With no assignment here, led keeps its previous value.
        end
    end

endmodule

`default_nettype wire
