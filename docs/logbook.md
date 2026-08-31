# Logic analyzer logbook

## 2026-08-30: I bought the board. Where do I start?

Okay, I just bought a DE1-SoC. I want to try building a logic analyzer with it. This is a personal project, so the first question was pretty open: where do I even start?

The starting point suggested was to get an LED blinking. Let's try that first. Before getting into capture logic, the immediate task is to check the board revision, set up the tools, and see whether the Programmer recognizes the board. Then download a small design and check the LED.

After that, the proposed path is to generate a pattern inside the FPGA, capture it in memory, and read it back on the PC. That gives me a known pattern to compare against before connecting an external signal. The initial plan uses the FPGA on its own, with HPS and Linux left for later.

The README has a starting proposal of eight channels, 1 MSa/s, and 1,024 samples. Those numbers are still a proposal. There is no capture implementation or measured performance behind them yet. The PC transfer method is also open.

So far, the work in the repository is documentation. No RTL, simulation results, or board checks are recorded yet. The next practical step is still getting the board recognized and an LED blinking.

## 2026-08-30: How do I keep the process for my portfolio?

I want to use this project in my portfolio, and I want a separate place for the questions I ask along the way. How would I do this? Okay, let's try that. What happened, and what should I try next?

That's what this logbook is for. I want it in English, but with the same tone I use when I'm working through something. If an attempt fails, I want to keep what I tried and what I saw, then follow the next idea. If I haven't tried it yet, it stays a plan.

The README now links here, and the repository rules say to update this log as the project develops. The README will keep the current setup and file guide; these entries will keep the sequence of questions and decisions. I also want to organize the documentation with Doxygen later. For now, this is a Markdown file, and the documentation build is still pending.

## 2026-08-30: Give me the skeleton. I'll fill it in.

Okay, let's make the basic files first. I asked for the RTL and testbench skeletons so I can fill in the implementation myself.

The starting structure is two SystemVerilog modules: [led_blink](../rtl/led_blink.sv) for the first counter exercise and [logic_analyzer](../rtl/logic_analyzer.sv) for a capture that starts manually, fills a buffer, and stops. Each has a matching testbench under `tb/`. The ports and intended behaviour are written down, but the counters, capture memory, and control logic are still TODOs.

The testbenches provide a clock, reset, waveform output, and a timeout. The capture testbench also sends a small counting pattern with gaps between sample enables. I'll need to add the expected results and check them. Right now the files are set up to finish with a `SKELETON ONLY` message, and the unimplemented outputs may show up as X.

The environment check didn't find an HDL simulator on PATH. Compilation and simulation haven't run yet; the [README](../README.md) has the commands to try once the tools are available. There are no board pin assignments in these files either. The next piece to fill in is the LED counter, along with a check that it toggles on the expected clock cycle.

## 2026-08-30: Which file should I edit first?

The skeletons are there now. Which file should I start with?

The suggestion is [led_blink.sv](../rtl/led_blink.sv), starting with the counter width and register at `TODO(LED-1)`. Then comes the synchronous reset and toggle logic. It's a small place to work through clock and reset behaviour before adding capture memory and control.

The matching [testbench](../tb/tb_led_blink.sv) sets `TOGGLE_CYCLES` to 4. That gives me a concrete check to add: led should be 0 during reset, toggle on the fourth rising edge after reset is released, and toggle again every four clocks. The implementation and those checks are still TODOs. I'll start with the counter's range and how many bits it needs.
