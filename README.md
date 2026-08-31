# VLSI Logic Analyzer

A personal project to build a logic analyzer with the DE1-SoC: sample digital signals, store them, and inspect the captured data on a PC. The project starts with small experiments and records the FPGA design, verification, and board bring-up work.

The [logbook](docs/logbook.md) keeps the questions, attempts, results, and next decisions in a conversational voice for the portfolio. This README describes the current project and how to use it. All project files use Canadian English.

## Current status

- A DE1-SoC has been purchased. Receipt and board operation have not yet been recorded.
- `led_blink` is implemented as a small counter example. The capture core now implements manual start, sample storage, stop-on-full, and registered reading after completion.
- The capture testbench compares stored data and checks control timing, restart, reset, and address boundaries. The LED testbench still has verification TODOs; normal termination alone is not a functional pass.
- Icarus Verilog capture checks passed for CHANNELS/DEPTH pairs 1/1, 8/3, 3/5, 8/8, and 8/1024. Separate temporary checks verified LED reset and toggle timing for `TOGGLE_CYCLES=1,3,4,5`. Both testbenches produce VCD files that GTKWave can read. Physical hardware remains unverified.
- There is no Quartus project, board wrapper, pin/timing constraints, or PC application yet.
- The specifications and structure below are **initial proposals**, subject to implementation and measurement.

## Where to start

The first goal is to **blink one board LED with a custom design**. Once programming and clock operation are confirmed, add capture logic. Start with the FPGA fabric; leave HPS (the ARM processor) and Linux integration for later.

1. **Check the board and development environment.** Confirm the board revision and FPGA part number, then obtain the matching Terasic manual, examples, and pin information. Prepare a Quartus edition/version that supports the exact Cyclone V device, its device package, and the USB-Blaster driver. Record the versions here. Check that Programmer recognizes the board, using the board documentation for pins and switch settings.
2. **Blink an LED.** Use a counter driven by the board clock, with pin assignments and clock timing constraints. Completion means synthesizing, placing and routing, programming the board, observing the LED, and recording the clock, pins, and tool versions used.
3. **Capture an internal signal.** Sample an internal counter or test pattern at regular intervals and store it in on-chip memory. In simulation, the values and sample count must match expectations, and writes must stop when the buffer is full.
4. **Read the capture on a PC.** Transfer data after capture and inspect it as CSV or VCD. Choose the transfer path at this stage. Completion means recovering a known board-generated pattern on the PC with the correct order and sample count.
5. **Add external GPIO and a trigger.** Check voltages and wiring before measuring a slow external signal. Add capture on a selected channel's rising edge. Completion means capturing a known external pattern and explaining the trigger position and sample interval.

## Proposed first version

| Item | Initial proposal |
| --- | --- |
| Input | Eight digital channels, starting with an internal test pattern |
| Sampling | 1,000,000 samples per second (1 MSa/s, a 1 µs interval) |
| Capture depth | 1,024 samples = 8,192 bits = 1 KiB of raw data |
| Capture window | About 1.024 ms at the proposed settings |
| Operation | Capture once, stop, then transfer to the PC |
| Trigger | Manual start first; a single-channel rising edge later |
| Storage | FPGA on-chip memory |
| PC output | CSV or VCD files |

The sample rate is not the maximum measurable signal frequency. Short pulses between samples can be missed, so begin with pulses much longer than the sample interval.

Continuous streaming, pre-trigger storage, protocol decoding, a GUI, external SDRAM, and HPS integration are outside the first version's scope. These numbers provide a starting point, not a performance guarantee.

## Proposed data flow

```text
Internal test pattern or GPIO input
                |
                v
Input handling -> Sampler -> Capture memory -> Read/transfer -> PC file/waveform
                     ^              ^
                     |              |
                Sample enable   Capture control/trigger
```

- Begin with one FPGA clock and consider using a clock enable to set the sample interval.
- External inputs can be asynchronous to the FPGA clock. Account for synchronization latency, metastability, and differences in when channels are observed. Synchronizing each channel does not guarantee that a multibit value is captured coherently.
- Separate the capture rate from the PC transfer rate. The first version stops capturing before reading stored data.
- If UART is selected, first verify that the chosen path is accessible from the FPGA. Do not assume a board USB connector provides an arbitrary FPGA data interface.

## Before connecting external signals

- Check the board manual and schematics for GPIO pins, I/O voltage, and permitted input ranges. Do not connect external signals before these are confirmed.
- Do not connect 5 V signals, negative voltages, or RS-232 directly to GPIO. Prepare appropriate level shifting and input protection where needed.
- Confirm the ground connection between the board and the device under test. Configure measurement pins as inputs to avoid output contention.
- Validate the internal pattern first. Do not treat this project's inputs as protected commercial instrument inputs.

## Repository files

This table lists existing project files. Update it and the related descriptions whenever a file is added, moved, or removed.

| File | Purpose |
| --- | --- |
| [README.md](README.md) | Project purpose, starting sequence, current status, file guide, and documentation rules |
| [AGENTS.md](AGENTS.md) | Canadian English, README/logbook maintenance, verification, and documentation rules |
| [docs/logbook.md](docs/logbook.md) | Chronological narrative of questions, suggestions, actual attempts, and results |
| [docs/simulation-setup.md](docs/simulation-setup.md) | Windows simulator installation, PATH configuration, testbench execution, and waveform viewing |
| [docs/logic-analyzer.md](docs/logic-analyzer.md) | Capture core architecture, parameters, ports, timing, verification, and limitations |
| [scripts/simulate.ps1](scripts/simulate.ps1) | Compile/run helper for both testbenches, with optional GTKWave launch |
| [rtl/led_blink.sv](rtl/led_blink.sv) | Implemented LED counter example with synchronous reset and a configurable toggle interval |
| [rtl/logic_analyzer.sv](rtl/logic_analyzer.sv) | Manual-start capture buffer with sample enable, stop-on-full, and registered readback |
| [tb/tb_led_blink.sv](tb/tb_led_blink.sv) | LED module connection, nominal 50 MHz clock model, reset, waveform output, and check TODOs |
| [tb/tb_logic_analyzer.sv](tb/tb_logic_analyzer.sv) | Parameterized capture checks for stored data, control timing, reads, restart, and reset |
| [.gitignore](.gitignore) | Excludes generated output under `build/` |
| [.gitattributes](.gitattributes) | Normalizes line endings for Git text files |

`rtl/` holds design sources, `tb/` holds simulation-only sources, `scripts/` holds execution helpers, and `docs/` holds records and technical guides. `quartus/` (project, pin, and timing constraints) and `host/` (PC tools) are proposed directories that do not exist yet. Add board integration files after confirming the revision and pins.

## Reading and extending the examples

Sources use SystemVerilog (`.sv`). Both RTL headers describe implemented behaviour. The LED testbench's `TODO(TB-LED-...)` checks remain open. If an interface changes, update the comments, documentation, and testbench together.

1. `rtl/led_blink.sv`: read the counter example. The counter runs from 0 to `TOGGLE_CYCLES - 1`, then clears and toggles the LED. Reset clears both registers on a rising edge. The first toggle occurs on the `TOGGLE_CYCLES`-th rising edge after reset is released; a full LED period takes twice that many clocks. The parameter must be at least 1, and the counter width is kept at one bit for that boundary case.
2. `tb/tb_led_blink.sv`: compare the reset value, first toggle, and subsequent intervals automatically. The current setting is `TOGGLE_CYCLES=10`; also try a small value such as 4 and the boundary value of 1.
3. `rtl/logic_analyzer.sv`: follow the memory declaration, reset, capture, start, and read branches. The [capture core guide](docs/logic-analyzer.md) explains each port and shows an edge-by-edge example.
4. `tb/tb_logic_analyzer.sv`: follow the known-pattern captures and expected-value comparisons. The default uses eight samples; repeat the checks at other sizes with the documented parameter overrides.

Both modules assume an **active-low synchronous reset** sampled on `posedge clk`. All capture inputs must already be synchronous to `clk`. External GPIO synchronization, a sample-enable generator, trigger detection, and UART are not included. The testbench drives `sample_en` directly. Apply reset before using either module. Capture memory is not cleared by reset, but read access is blocked until a new capture completes.

The RTL assigns no physical board pins or clock frequency. The LED testbench models a nominal 50 MHz clock (20 ns period); the capture testbench still uses a 10 ns simulation clock. These clocks and small parameters do not implement or validate the 1 MSa/s proposal.

### LED clock reference

The [Terasic DE1-SoC User Manual dated 2019-01-28, section 3.5, pp. 21-22](https://hps.hs-regensburg.de/scm39115/homepage/education/labs/Lab_ElectronicBoards/DE1-SoC_UserManual.pdf) (university-hosted copy) documents nominal 50 MHz FPGA clock inputs, including `CLOCK_50`. This is the reference for the LED simulation, not confirmation of this project's physical board revision or clock operation. Check the actual revision against the matching [Terasic resources](https://www.terasic.com.tw/cgi-bin/page/archive.pl?CategoryNo=205&Language=English&No=836&PartNo=4) before choosing pins or programming settings.

- At 50 MHz, one clock period is `1 / 50_000_000 s = 20 ns = 20_000 ps`.
- In the LED testbench, `timescale 1ns/1ps` makes `#10` a 10 ns delay. Inverting the clock every 10 ns produces a 20 ns period.
- The testbench override `TOGGLE_CYCLES=10` gives 200 ns between LED toggles and a 400 ns full LED period after reset.
- The RTL default `TOGGLE_CYCLES=25_000_000` would give 0.5 s between toggles and a 1 s full LED period with a 50 MHz input clock.

Changing `#10`, `timescale`, or the LED counter does not configure a physical clock source. Board integration still needs a wrapper connecting the verified clock input to `clk`, revision-verified pin assignments, and timing constraints describing the clock period. No Quartus clock/pin settings or board measurements have been completed.

## Running simulations

The [simulation setup guide](docs/simulation-setup.md) covers Windows installation, PATH configuration, waveform viewing, and individual compile commands. The following environment was checked on 2026-08-30.

| Item | Verified environment |
| --- | --- |
| OS / shell | Windows x64 / PowerShell 7.6.4 |
| Compiler | Icarus Verilog 13.0 stable, MSYS2 UCRT64 package `1~13.0-2` |
| Simulation runtime | Icarus `vvp` 13.0 stable |
| Waveform viewer | GTKWave 3.3.127, MSYS2 UCRT64 package `3.3.127-1` |
| Tool directory on this PC | `C:\msys64\ucrt64\bin` (added to the user PATH) |

Run both testbenches from PowerShell at the repository root:

```powershell
.\scripts\simulate.ps1
```

To run one testbench and open GTKWave, use the command for that target:

```powershell
.\scripts\simulate.ps1 -Target led -Wave
.\scripts\simulate.ps1 -Target capture -Wave
```

The script compiles in SystemVerilog mode (`-g2012`) and runs `vvp` only if compilation succeeds. It can find the default MSYS2 installation and temporarily adds the tool's `bin` directory to the process PATH so the internal compiler can find its DLLs. It restores PATH and the working directory on exit. It does not change the PowerShell execution policy.

The checks completed so far are:

| Testbench | Execution result | Waveform |
| --- | --- | --- |
| `tb_led_blink` | Compiled and terminated at 900 ns with `SKELETON ONLY` (50 MHz clock, `TOGGLE_CYCLES=10`) | Generated `build/tb_led_blink.vcd`; GTKWave loaded it |
| `tb_logic_analyzer` | Directed checks passed at 786 ns with `PASS` (CHANNELS=8, DEPTH=8) | Generated `build/tb_logic_analyzer.vcd`; GTKWave loaded it |

GTKWave loading was checked with `--exit`. This does not verify every interactive UI feature. Compiled files (`.vvp`), waveforms, and setup check output belong under `build/` and are excluded from Git.

Inspection of the updated LED VCD confirmed a 20 ns clock period, reset setting the LED to 0 at 10 ns, and LED toggles at 250, 450, 650, and 850 ns. Reset is released at 60 ns, so the first toggle is on the tenth active rising edge. This checks the current simulation trace; it is not a board measurement or a completed self-checking testbench.

Separate temporary LED checks passed with Icarus Verilog for `TOGGLE_CYCLES=1,3,4,5`: reset value, first toggle, repeated intervals, reset during operation, no reset response before a rising edge, and timing after reset is released again. That harness is local under ignored `build/`; it does not fill in or replace the author's testbench TODOs.

The capture testbench prints `PASS` only after expected-value and control checks finish; mismatches call `$fatal(1, ...)`. Its [verification scope and limitations](docs/logic-analyzer.md#verification-and-limits) are documented separately. The LED testbench still prints `SKELETON ONLY` because its automatic comparisons remain TODOs. Neither VCD generation nor simulation success proves FPGA timing or physical operation. Quartus synthesis and board programming are separate, unfinished steps.

## Documentation and Doxygen preparation

Keep README as the project's entry point. Update relevant sections when files, functionality, interfaces, or build steps change. Distinguish planned work, simulation results, and behaviour verified on the board.

All project documents, comments, TODOs, and messages use Canadian English. Preserve filenames, code identifiers, commands, official names, and link targets.

Update the logbook when a project question, explanation that changes understanding, design choice, experiment, or result develops, unless the user explicitly excludes that session. Apply `humanizer:humanizer` and `soo-application-voice` to write in the author's first-person voice. Follow the actual conversation and evidence from the question to the next attempt. Distinguish suggestions from actions, never invent an experiment or failure, and append later findings rather than erase earlier uncertainty.

For each new RTL module, document:

- Purpose and data flow.
- Clock, reset polarity, and synchronous/asynchronous behaviour.
- Parameters, port directions/widths/meaning, and conditions for valid data.
- Sampling, trigger, buffer completion timing, and latency.
- Limitations, the associated testbench, and verified results.

A future `Doxyfile` will collect README and Markdown files under `docs/` into HTML documentation. The configuration and documentation build command do not exist yet.

Doxygen can turn Markdown into documentation pages. Verilog/SystemVerilog are not listed among its default supported languages, so Doxygen-style comments in `.v` or `.sv` files alone must not be treated as automatic module/port extraction. If HDL extraction becomes necessary, validate a separate filter with a small example. Until then, use Markdown module documentation. See [Doxygen language support](https://www.doxygen.nl/manual/starting.html) and [Markdown processing](https://www.doxygen.nl/manual/markdown.html).

When documentation tooling is added, record the tool version, command, and output path here. Keep generated HTML separate from source and define the appropriate Git ignore rules.

## Progress checklist

- [x] Define the project direction and documentation rules
- [x] Add LED/capture RTL and testbench skeletons
- [x] Record simulator versions and compile/run the skeletons
- [x] Simulate the capture core with known patterns, readback, and boundary checks
- [ ] Record board revision, FPGA part number, and board tool versions
- [ ] Confirm board detection in Programmer
- [ ] Verify LED blink on the board
- [ ] Integrate an internal pattern source on the board and verify captured values
- [ ] Recover captured data on a PC
- [ ] Verify external GPIO capture and a rising-edge trigger
- [ ] Add the Doxygen documentation build

## References

- [Terasic DE1-SoC resources](https://www.terasic.com.tw/cgi-bin/page/archive.pl?CategoryNo=205&Language=English&No=836&PartNo=4): manuals, examples, and pin information for the matching board revision
- [Doxygen getting started](https://www.doxygen.nl/manual/starting.html): supported languages and configuration/build steps
- [Doxygen Markdown guide](https://www.doxygen.nl/manual/markdown.html): including design documents as pages
