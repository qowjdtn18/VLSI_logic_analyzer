# VLSI Logic Analyzer

A personal FPGA project to build a logic analyzer with the DE1-SoC: sample
digital signals, store them, and inspect the captured data on a PC. The project
starts with an internal test pattern before any external GPIO is connected.

The [logbook](docs/logbook.md) records the questions, attempts, results, and
decisions that led here. This README describes the current design and how to
use it. All project files use Canadian English.

The initial LED bring-up experiment now lives in a separate sibling
`LED_blink` repository. This repository keeps the capture core, analyzer board
wrapper, and future PC transfer work.

## Current status

- The user identifies the board as a DE1-SoC Rev. F. The physical part marking
  has not been independently recorded.
- `logic_analyzer` implements manual start, sample storage, stop-on-full, and
  registered readback after capture.
- The core testbench checks stored data, control timing, restart, reset, and
  address boundaries. Icarus parameter checks have passed for CHANNELS/DEPTH
  pairs 1/1, 8/3, 3/5, 8/8, and 8/1024.
- `de1_soc_top` provides a Rev. F internal-pattern demonstration with a proposed
  1 MSa/s sample enable. Its scaled wrapper simulation passes.
- The analyzer Quartus project contains the Cyclone V device, Rev. F/G pins,
  and 50 MHz timing constraint. A complete analyzer Quartus compile, timing
  review, programming result, and physical capture remain pending.
- There is no PC readout application yet.

The channel count, sample rate, and capture depth below are initial design
choices, not measured hardware capabilities.

## Proposed first version

| Item | Initial choice |
| --- | --- |
| Input | Eight digital channels, beginning with an internal pattern |
| Sampling | 1,000,000 samples per second (1 MSa/s, a 1 us interval) |
| Capture depth | 1,024 samples = 8,192 bits = 1 KiB of raw data |
| Capture window | About 1.024 ms at the proposed settings |
| Operation | Capture once, stop, then transfer to the PC |
| Trigger | Manual start first; a single-channel rising edge later |
| Storage | FPGA on-chip memory |
| PC output | CSV or VCD files |

The sample rate is not the maximum measurable signal frequency. A transition
between sample instants can be missed, so initial external tests should use
pulses much longer than the sample interval.

Continuous streaming, pre-trigger storage, protocol decoding, a GUI, external
SDRAM, and HPS integration are outside the first version's scope.

## Data flow

```text
Internal pattern or GPIO input
              |
              v
Input handling -> Sampler -> Capture memory -> Read/transfer -> PC file
                     ^              ^
                     |              |
                Sample enable   Capture control
```

- Begin with one FPGA clock and use a clock enable to set the sample interval.
- External inputs can be asynchronous to the FPGA clock. Account for
  synchronization latency, metastability, and multibit coherence before using
  GPIO signals.
- Separate capture timing from PC transfer. The first version stops capturing
  before data is read.
- Do not assume that a board USB connector is an arbitrary FPGA data interface.
  Select and verify the transfer path before building the host application.

## Before connecting external signals

- Check the Rev. F/G manual and schematics for GPIO pins, I/O voltage, and
  permitted input ranges.
- Do not connect 5 V, negative voltage, or RS-232 signals directly to GPIO.
- Connect grounds between the board and the device under test.
- Configure measurement pins as inputs to avoid output contention.
- Validate the internal pattern before attaching an external source.

## Repository files

Generated simulation and Quartus output directories are excluded from Git and
are not listed individually.

| File | Purpose |
| --- | --- |
| [README.md](README.md) | Project status, architecture, workflow, and file inventory |
| [AGENTS.md](AGENTS.md) | Canadian English, documentation, hardware, and verification rules |
| [docs/logbook.md](docs/logbook.md) | Chronological narrative of questions, attempts, results, and decisions |
| [docs/simulation-setup.md](docs/simulation-setup.md) | Windows simulator setup and individual commands |
| [docs/logic-analyzer.md](docs/logic-analyzer.md) | Capture-core parameters, ports, timing, verification, and limitations |
| [docs/board-bring-up.md](docs/board-bring-up.md) | Rev. F internal-pattern build, programming, and observation workflow |
| [rtl/logic_analyzer.sv](rtl/logic_analyzer.sv) | Manual-start capture buffer and registered readback |
| [rtl/de1_soc_top.sv](rtl/de1_soc_top.sv) | Rev. F internal-pattern board wrapper controlled by keys and switches |
| [tb/tb_logic_analyzer.sv](tb/tb_logic_analyzer.sv) | Self-checking capture-core testbench |
| [tb/tb_de1_soc_top.sv](tb/tb_de1_soc_top.sv) | Self-checking scaled board-wrapper testbench |
| [scripts/simulate.ps1](scripts/simulate.ps1) | PowerShell simulation and optional GTKWave helper |
| [quartus/vlsi_logic_analyzer.qpf](quartus/vlsi_logic_analyzer.qpf) | Analyzer Quartus project entry point |
| [quartus/vlsi_logic_analyzer.qsf](quartus/vlsi_logic_analyzer.qsf) | Device, source, Rev. F/G pin, and I/O-standard assignments |
| [quartus/de1_soc_top.sdc](quartus/de1_soc_top.sdc) | 50 MHz clock constraint and asynchronous board-I/O exceptions |
| [.gitignore](.gitignore) | Generated simulation and Quartus output exclusions |
| [.gitattributes](.gitattributes) | Git text-file line-ending normalization |

`host/` remains a proposed directory and does not exist yet.

## Capture core

The [capture-core guide](docs/logic-analyzer.md) documents every parameter,
port, edge transition, read latency, and current limitation. The implemented
flow is:

1. Apply active-low synchronous reset.
2. Pulse `start` for one rising edge.
3. While `busy` is high, each rising edge with `sample_en=1` stores
   `sample_in`.
4. The final accepted sample clears `busy` and raises `done`.
5. After completion, assert `read_en` with a valid address. `read_data` and
   `read_valid` update on the rising edge.

Capture memory is not cleared by reset, but read access remains blocked until a
new capture completes. External-input synchronization, triggers, continuous
capture, and a transfer interface are not implemented.

## Rev. F internal-pattern demonstration

The [board wrapper](rtl/de1_soc_top.sv) generates a one-cycle sample enable
every 50 clocks. With a nominal 50 MHz board clock, that proposes a 1 MHz sample
rate. An internal eight-bit value increments once per accepted sample and fills
1,024 memory locations.

| Board control | Function |
| --- | --- |
| KEY0 | Active-low reset |
| KEY1 | Start or restart capture |
| SW9..SW0 | Read address after capture |
| LEDR8 | Busy |
| LEDR9 | Done |
| LEDR7..LEDR0 | Sample value at the selected address |

The full pin, compile, programming, and observation sequence is in the
[Rev. F board bring-up guide](docs/board-bring-up.md). The analyzer project has
not yet completed this physical workflow.

## Run simulations

The verified local environment is Windows PowerShell 7.6.4, Icarus Verilog
13.0, and GTKWave 3.3.127. Run both testbenches from the repository root:

```powershell
.\scripts\simulate.ps1
```

Run one testbench and open its waveform:

```powershell
.\scripts\simulate.ps1 -Target capture -Wave
.\scripts\simulate.ps1 -Target board -Wave
```

| Testbench | Result | Waveform |
| --- | --- | --- |
| `tb_logic_analyzer` | Directed checks passed at 786 ns for CHANNELS=8, DEPTH=8 | `build/tb_logic_analyzer.vcd` |
| `tb_de1_soc_top` | Reset, start, divider, capture, switch, and LED checks passed at 1,451 ns | `build/tb_de1_soc_top.vcd` |

Separate parameter sweeps passed for capture configurations 1/1, 8/3, 3/5,
8/8, and 8/1024. Simulation does not validate Quartus placement, board timing,
physical pins, or analogue signal integrity.

## Documentation and Doxygen preparation

Keep README current when files, functionality, interfaces, or workflows
change. Keep the logbook in the author's first-person voice and preserve the
actual sequence of uncertainty, attempts, failures, corrections, and results.

For each RTL module, document its purpose, parameters, port directions and
widths, clock and reset behaviour, timing and latency, limitations, and related
testbench.

A future Doxyfile will include README and Markdown under `docs/`. Doxygen does
not list Verilog or SystemVerilog among its default languages, so comments in
`.sv` files must not be presented as automatic module extraction. Validate an
HDL filter before adding that workflow.

## Progress

- [x] Define the capture direction and documentation rules
- [x] Implement and simulate the capture core
- [x] Add and simulate the Rev. F internal-pattern wrapper
- [x] Separate the LED bring-up experiment into its own repository
- [ ] Complete the analyzer Quartus compile and review timing
- [ ] Program and verify the internal-pattern capture on the board
- [ ] Transfer captured samples to the PC
- [ ] Verify external GPIO input handling and a rising-edge trigger
- [ ] Add the Doxygen documentation build

## References

- [Terasic DE1-SoC Rev. F/G resources](https://www.terasic.com.tw/cgi-bin/page/archive.pl?CategoryNo=165&Language=English&No=836&PartNo=4)
- [Doxygen getting started](https://www.doxygen.nl/manual/starting.html)
- [Doxygen Markdown guide](https://www.doxygen.nl/manual/markdown.html)
