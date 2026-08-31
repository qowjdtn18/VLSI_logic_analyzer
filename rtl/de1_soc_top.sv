`timescale 1ns/1ps
`default_nettype none

/*
 * @file de1_soc_top.sv
 * @brief DE1-SoC Rev. F board wrapper for an internal-pattern capture demo.
 *
 * Board inputs: CLOCK_50 is the 50 MHz FPGA clock. KEY[0] is active-low reset;
 *               KEY[1] starts a capture. SW selects the read address after capture.
 * Board outputs: LEDR[8] is busy, LEDR[9] is done, and LEDR[7:0] is read_data.
 *
 * Capture: SAMPLE_RATE_HZ sets a periodic sample enable. The default 1 MHz rate
 *          divides the 50 MHz input by 50. An 8-bit internal count is captured,
 *          so address N contains the low 8 bits of N after a completed capture.
 * Read: while done is high, SW[9:0] selects one of the 1,024 default samples.
 *       read_data is registered, so LEDs update after a CLOCK_50 rising edge.
 *
 * Reset/start: KEY inputs are debounced on the board but asynchronous to CLOCK_50.
 *              Reset asserts asynchronously in a two-stage release synchronizer;
 *              the core still samples its resulting reset synchronously. KEY[1]
 *              passes through two flip-flops before falling-edge detection.
 *
 * Parameters: CLOCK_HZ >= 1, SAMPLE_RATE_HZ >= 1, CLOCK_HZ must be evenly
 *             divisible by SAMPLE_RATE_HZ, and 1 <= CAPTURE_DEPTH <= 1024.
 * Limits: this demo captures an internal pattern, not GPIO. It has no trigger,
 *         timestamp, pre-trigger history, PC transfer, or HPS integration.
 * Testbench: tb/tb_de1_soc_top.sv uses smaller parameters for a quick simulation.
 */
module de1_soc_top #(
    parameter integer CLOCK_HZ = 50_000_000,
    parameter integer SAMPLE_RATE_HZ = 1_000_000,
    parameter integer CAPTURE_DEPTH = 1024,
    localparam integer SAMPLE_DIVISOR = CLOCK_HZ / SAMPLE_RATE_HZ,
    localparam integer DIVIDER_WIDTH = (SAMPLE_DIVISOR > 1) ? $clog2(SAMPLE_DIVISOR) : 1,
    localparam integer ADDR_WIDTH = (CAPTURE_DEPTH > 1) ? $clog2(CAPTURE_DEPTH) : 1
) (
    input  logic       CLOCK_50,
    input  logic [1:0] KEY,
    input  logic [9:0] SW,
    output logic [9:0] LEDR
);
    logic [1:0] reset_release;
    logic rst_n;
    logic key1_meta;
    logic key1_sync;
    logic key1_previous;
    logic start_pulse;
    logic [DIVIDER_WIDTH-1:0] sample_count;
    logic sample_enable;
    logic [7:0] sample_pattern;
    logic busy;
    logic done;
    logic [7:0] read_data;
    logic read_valid;
    logic [ADDR_WIDTH-1:0] read_addr;
    logic [9:0] switch_meta;
    logic [9:0] switch_sync;

    // Pressing KEY[0] asserts reset immediately. Release reaches rst_n after two clocks.
    always_ff @(posedge CLOCK_50 or negedge KEY[0]) begin
        if (!KEY[0])
            reset_release <= 2'b00;
        else
            reset_release <= {reset_release[0], 1'b1};
    end
    assign rst_n = reset_release[1];

    // Convert one debounced, active-low KEY[1] press into one synchronous start pulse.
    always_ff @(posedge CLOCK_50) begin
        if (!rst_n) begin
            key1_meta <= 1'b1;
            key1_sync <= 1'b1;
            key1_previous <= 1'b1;
        end else begin
            key1_meta <= KEY[1];
            key1_sync <= key1_meta;
            key1_previous <= key1_sync;
        end
    end
    assign start_pulse = key1_previous && !key1_sync;

    // Synchronize each switch bit before the selection is used by clocked read logic.
    // Switch bits changed together can still arrive on different clocks during motion.
    always_ff @(posedge CLOCK_50) begin
        if (!rst_n) begin
            switch_meta <= '0;
            switch_sync <= '0;
        end else begin
            switch_meta <= SW;
            switch_sync <= switch_meta;
        end
    end

    // Generate a one-clock sample enable. Restart its phase for each capture.
    always_ff @(posedge CLOCK_50) begin
        if (!rst_n || start_pulse) begin
            sample_count <= '0;
            sample_enable <= 1'b0;
        end else if (sample_count == SAMPLE_DIVISOR - 1) begin
            sample_count <= '0;
            sample_enable <= 1'b1;
        end else begin
            sample_count <= sample_count + 1'b1;
            sample_enable <= 1'b0;
        end
    end

    // Increment once per accepted sample. The core stores the value before this update.
    always_ff @(posedge CLOCK_50) begin
        if (!rst_n || start_pulse)
            sample_pattern <= '0;
        else if (busy && sample_enable)
            sample_pattern <= sample_pattern + 1'b1;
    end

    assign read_addr = switch_sync[ADDR_WIDTH-1:0];

    logic_analyzer #(
        .CHANNELS(8),
        .DEPTH(CAPTURE_DEPTH)
    ) capture_core (
        .clk(CLOCK_50),
        .rst_n(rst_n),
        .start(start_pulse),
        .sample_en(sample_enable),
        .sample_in(sample_pattern),
        .busy(busy),
        .done(done),
        .read_en(done),
        .read_addr(read_addr),
        .read_data(read_data),
        .read_valid(read_valid)
    );

    always_comb begin
        LEDR = '0;
        LEDR[7:0] = read_data;
        LEDR[8] = busy;
        LEDR[9] = done;
    end

endmodule

`default_nettype wire
