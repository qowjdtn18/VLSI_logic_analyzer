# Capture core

This document describes the implemented [logic_analyzer module](../rtl/logic_analyzer.sv) and its [testbench](../tb/tb_logic_analyzer.sv). It is technical documentation, separate from the narrative logbook. The core stores one capture and exposes the stored samples for reading. It is not yet a complete board instrument.

## Data path and state

```text
sample_in -> capture_memory[write_addr] -> read_data
                  ^                         ^
             sample_en                 read_en/read_addr
```

Each memory entry holds one sample containing all channels. The write address selects the next entry. There is no separate state variable: `busy` and `done` describe the state.

| busy | done | Meaning |
| --- | --- | --- |
| 0 | 0 | Waiting for the first start after reset |
| 1 | 0 | Capturing; accept samples when sample_en is high |
| 0 | 1 | Capture complete; accept reads or a new start |

`busy=1, done=1` is not a normal state. Reset initializes the state; apply reset before using the module.

## Parameters

| Name | Default | Meaning |
| --- | --- | --- |
| CHANNELS | 8 | Bits per sample; must be at least 1 |
| DEPTH | 1024 | Number of samples per capture; must be at least 1 |
| ADDR_WIDTH | Derived | max(1, ceil(log2(DEPTH))); not an independent setting |

The default memory holds 8,192 data bits (1 KiB). This is a logical capacity, not a measured FPGA resource count. Positive parameter values are a caller requirement; the testbench rejects non-positive values.

## Ports

All inputs must already be synchronous to `clk`. Every operation uses its rising edge.

| Port | Direction | Width | Meaning |
| --- | --- | --- | --- |
| clk | Input | 1 | Input clock; the core neither creates it nor sets its frequency |
| rst_n | Input | 1 | Active-low synchronous reset; takes priority over requests |
| start | Input | 1 | Pulse high for one clock to start a capture while idle |
| sample_en | Input | 1 | Store the current sample on an edge while busy |
| sample_in | Input | CHANNELS | Simultaneous channel values for one sample |
| busy | Output | 1 | Capture is accepting samples |
| done | Output | 1 | A complete capture is available; held until reset or a new start |
| read_en | Input | 1 | Request a stored sample after completion |
| read_addr | Input | ADDR_WIDTH | Requested sample index, from 0 to DEPTH-1 |
| read_data | Output | CHANNELS | Registered sample value; interpret it with read_valid |
| read_valid | Output | 1 | A read request was accepted on this edge |

## Timing and priorities

Reset clears the write address, busy, done, read_data, and read_valid. It does not clear the memory array. Old contents cannot be read until a new capture has completely overwritten the buffer and set done.

An idle start clears done, sets busy, and resets the write address. It does not store a sample on that edge, even if sample_en is high. The first possible sample is on the following rising edge.

While busy, each sample_en edge writes one entry. A low sample_en pauses capture without advancing the address. Start and read requests are ignored while busy, including on the final write edge. The DEPTH-th write clears busy and sets done. Further sample_en pulses cannot overwrite the completed capture.

After completion, read_en with a valid address registers read_data and asserts read_valid just after the accepting edge. Consecutive requests can produce one result per clock. This is a clocked read, not an asynchronous response to changes in read_addr. A downstream register clocked by the same edge observes the previous read outputs; the new outputs are available after that edge.

On an edge without an accepted read, read_valid clears and read_data holds its previous value. Reads before completion, during capture, or outside the address range are rejected. A new idle start has priority over a simultaneous read and also clears read_valid. Reset instead clears read_data to zero.

For example, with DEPTH=3:

| Rising edge | Request | Result just after the edge |
| --- | --- | --- |
| 0 | start=1, sample_en=1 | busy=1; no sample stored |
| 1 | start=0, sample_en=1, sample_in=0x11 | Store address 0 |
| 2 | sample_en=0 | Pause; address does not advance |
| 3 | sample_en=1, sample_in=0x22 | Store address 1 |
| 4 | sample_en=1, sample_in=0x33 | Store address 2; busy=0, done=1 |
| 5 | read_en=1, read_addr=0 | read_data=0x11, read_valid=1 |
| 6 | read_en=1, read_addr=1 | read_data=0x22, read_valid=1 |
| 7 | read_en=0 | read_data holds 0x22, read_valid=0 |

Sample spacing is controlled entirely by sample_en. The core stores values, not timestamps. If sample_en has irregular gaps, the saved data alone cannot reconstruct those gaps. A later periodic sample-enable generator is needed for a fixed sampling rate such as the proposed 1 MSa/s.

## Verification and limits

Run the default 8-channel, depth-8 testbench with the [simulation commands](simulation-setup.md#running-individual-commands). The capture clock remains 10 ns for simulation and is independent of the LED testbench's 20 ns clock.

The testbench drives a known pattern, reads every location, and compares values using case inequality so unknown outputs fail. It checks reset priority, reads before completion, no sample on the start edge, sample gaps, consecutive samples, busy start/read requests, final-write timing, no overwrites after completion, consecutive reads, read-data holding, restart with a different pattern, and reset during capture. Unused address encodings are checked when the chosen depth provides them.

Icarus Verilog 13.0 passed these CHANNELS/DEPTH pairs: 1/1, 8/3, 3/5, 8/8, and 8/1024. See the [parameter sweep commands](simulation-setup.md#checking-other-capture-sizes) to repeat them. These are directed simulation checks, not exhaustive or formal verification.

Not implemented or verified in the core: raw GPIO handling, metastability protection, a periodic sample-enable generator, trigger detection, pre-trigger history, or PC transfer. The separate [Rev. F board wrapper and bring-up guide](board-bring-up.md) add an internal pattern, a 1 MHz sample enable, and board control pins. Quartus synthesis, inferred memory resources, timing closure, and physical operation remain unverified. HPS/Linux is optional future work.
