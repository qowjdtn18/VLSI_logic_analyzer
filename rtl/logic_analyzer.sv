`timescale 1ns/1ps
`default_nettype none

/*
 * @file logic_analyzer.sv
 * @brief Manually started capture buffer with reading after completion.
 *
 * Parameters: CHANNELS >= 1 (sample width), DEPTH >= 1 (number of stored samples).
 *             ADDR_WIDTH is derived from DEPTH. Valid addresses are 0..DEPTH-1.
 * Inputs: clk, rst_n, start, sample_en, and read_en are each 1 bit.
 *         sample_in is CHANNELS bits; read_addr is ADDR_WIDTH bits.
 * Outputs: busy, done, and read_valid are each 1 bit; read_data is CHANNELS bits.
 *
 * Clock/reset: all operations use posedge clk; rst_n is active-low and synchronous.
 *              Reset initializes control state and outputs to 0.
 *              The memory need not be cleared. Data is invalid before done.
 * Input contract: all inputs are synchronous to clk. Do not connect raw GPIO here.
 *
 * Start: sampling start=1 while idle begins a capture with busy=1 and done=0.
 *        start is a one-clock pulse. Ignore it while busy.
 * Store: from the rising edge after accepting start, store only when busy && sample_en.
 *        Hold the write address when sample_en=0. Store sample_in values in order.
 * Finish: set busy=0 and done=1 on the edge that stores the DEPTH-th sample.
 *         Stop further writes. Hold done until the next start or reset.
 *         Trigger detection and pre-trigger capture are outside this module's scope.
 * Read: after capture, when busy=0, done=1, and start=0, present read_en=1 and a valid
 *       address at a rising edge. Output read_data and read_valid=1 just after that edge.
 *       On the next edge without a valid request, clear read_valid and hold read_data.
 *       Ignore requests during capture, before completion, or outside the address range.
 *       start takes priority over reading.
 *
 * Testbench: tb/tb_logic_analyzer.sv checks stored values, control timing, and restart.
 * Limits: no sample-enable generator, external input synchronizer, PC transfer, or board wiring.
 *         FPGA memory mapping and timing closure have not been checked in Quartus.
 */
module logic_analyzer #(
    parameter integer CHANNELS = 8,
    parameter integer DEPTH = 1024,
    localparam integer ADDR_WIDTH = (DEPTH > 1) ? $clog2(DEPTH) : 1
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  start,
    input  logic                  sample_en,
    input  logic [CHANNELS-1:0]   sample_in,
    output logic                  busy,
    output logic                  done,

    input  logic                  read_en,
    input  logic [ADDR_WIDTH-1:0] read_addr,
    output logic [CHANNELS-1:0]   read_data,
    output logic                  read_valid
);

    // Each memory entry holds one CHANNELS-bit sample. There are DEPTH entries.
    logic [CHANNELS-1:0] capture_memory [0:DEPTH-1];
    logic [ADDR_WIDTH-1:0] write_addr;

    // busy and done also hold the control state:
    // 0/0 = waiting for start, 1/0 = capturing, 0/1 = capture ready to read.
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            write_addr <= '0;
            busy <= 1'b0;
            done <= 1'b0;
            read_data <= '0;
            read_valid <= 1'b0;
            // Old memory contents remain, but reads are blocked until a new capture finishes.
        end else begin
            // A read is valid only on cycles that accept a read request.
            read_valid <= 1'b0;

            if (busy) begin
                // start and read requests have no effect during capture.
                if (sample_en) begin
                    capture_memory[write_addr] <= sample_in;
                    if (write_addr == DEPTH - 1) begin
                        busy <= 1'b0;
                        done <= 1'b1;
                    end else begin
                        write_addr <= write_addr + 1'b1;
                    end
                end
            end else if (start) begin
                // Starting does not store a sample on this edge, even if sample_en is high.
                write_addr <= '0;
                busy <= 1'b1;
                done <= 1'b0;
            end else if (done && read_en && (read_addr < DEPTH)) begin
                // Registered read: the requested sample appears just after this edge.
                read_data <= capture_memory[read_addr];
                read_valid <= 1'b1;
            end
            // Registers without an assignment keep their previous values.
        end
    end

endmodule

`default_nettype wire
