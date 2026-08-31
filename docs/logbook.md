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

The starting structure was two SystemVerilog modules: `led_blink` for the first counter exercise and [logic_analyzer](../rtl/logic_analyzer.sv) for a capture that starts manually, fills a buffer, and stops. Each had a matching testbench under `tb/`. The ports and intended behaviour were written down, but the counters, capture memory, and control logic were still TODOs.

The testbenches provide a clock, reset, waveform output, and a timeout. The capture testbench also sends a small counting pattern with gaps between sample enables. I'll need to add the expected results and check them. Right now the files are set up to finish with a `SKELETON ONLY` message, and the unimplemented outputs may show up as X.

The environment check didn't find an HDL simulator on PATH. Compilation and simulation haven't run yet; the [README](../README.md) has the commands to try once the tools are available. There are no board pin assignments in these files either. The next piece to fill in is the LED counter, along with a check that it toggles on the expected clock cycle.

## 2026-08-30: Which file should I edit first?

The skeletons are there now. Which file should I start with?

The suggestion was `led_blink.sv`, starting with the counter width and register at `TODO(LED-1)`. Then came the synchronous reset and toggle logic. It was a small place to work through clock and reset behaviour before adding capture memory and control.

The matching testbench set `TOGGLE_CYCLES` to 4. That gave me a concrete check to add: led should be 0 during reset, toggle on the fourth rising edge after reset is released, and toggle again every four clocks. The implementation and those checks were still TODOs. I would start with the counter's range and how many bits it needed.

## 2026-08-31: Can I light one LED first?

The project got ahead of the first board check. I want to step back and get one LED blinking before I try loading the larger design. What exactly do I click in Quartus, and why?

There was now a separate Rev. F LED project for that check. `CLOCK_50` drove the existing blink counter, KEY0 reset it, and LEDR0 showed the result. Its board wrapper passed a scaled simulation that checked reset and toggle timing. The Quartus compile, USB-Blaster connection, programming step, and physical LED were still pending at that point.

The next attempt is to open `quartus/led_blink.qpf`, confirm the Cyclone V device and the three Rev. F pins, compile the project, review the timing report, and load `led_blink.sof` through Programmer. If it works on the board, LEDR0 should change state every half-second after I press and release KEY0.

## 2026-08-31: Why did Programmer find two devices?

The LED project compiled far enough to generate `led_blink.sof`, but pressing Start in Programmer failed with error 209031. The message was specific: the CDF expected one device, while the physical JTAG chain contained two.

That two-device scan is normal for the DE1-SoC. One entry is `SOCVHPS`, the HPS debug interface, and the other is `5CSEMA5F31`, the FPGA fabric I want to program. My current Programmer list only described the FPGA, so it did not match the board.

The next try is to use Auto Detect, keep both devices in the detected order, leave the HPS row alone, and attach `led_blink.sof` only to the `5CSEMA5F31` row. Successful programming and the physical LED blink are still pending.

Auto Detect fixed the chain, and the next programming attempt worked. I still need to record whether LEDR0 showed the expected half-second changes before calling the physical blink complete.

That led to another basic question: what is the `top` file actually for? `de1_soc_led_top.sv` was the board-facing root of the design. Quartus started there, matched its port names to the QSF pins, and followed the `led_blink` instance below it. It also handled KEY0's active-low reset before passing reset to the reusable counter. It was somewhat like `main()` in C as an entry point, but it described connected hardware rather than a function that runs line by line.

## 2026-08-31: Should the LED check be its own project?

The LED work had become a complete bring-up exercise with its own RTL, top-level wrapper, testbench, Quartus files, timing result, and JTAG troubleshooting. It was no longer just a small file inside the logic analyzer.

I split it into a sibling `LED_blink` repository. This repository keeps the capture core, the analyzer wrapper, and the future PC transfer work. The earlier LED entries stay here as part of how the analyzer started, while the standalone LED repository now owns the actual source and its focused logbook.
