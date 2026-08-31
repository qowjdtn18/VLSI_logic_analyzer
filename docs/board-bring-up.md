# DE1-SoC Rev. F board bring-up

This guide covers the first FPGA-only internal-pattern capture on the user's reported DE1-SoC Rev. F board. It does not use the HPS or external GPIO. The project files are ready for Quartus, but synthesis, programming, and physical behaviour have not yet been verified.

## Hardware reference

Pin assignments come from the [Terasic DE1-SoC User Manual dated 2019-01-28](https://hps.hs-regensburg.de/scm39115/homepage/education/labs/Lab_ElectronicBoards/DE1-SoC_UserManual.pdf), which covers Rev. F/G. Section 3.5 and Table 3-5 document the 50 MHz FPGA clocks. Section 3.6.1 and Tables 3-6 through 3-8 document the switches, push-buttons, and red LEDs.

The Quartus project targets `5CSEMA5F31C6`, corresponding to the manual's Cyclone V SE `5CSEMA5F31C6N` board device. Confirm that the package marking and the device shown in Quartus agree before programming. The user has identified the board as Rev. F; physical operation is not yet evidence-checked.

The [Terasic Rev. F/G resource package](https://www.terasic.com.tw/cgi-bin/page/archive.pl?CategoryNo=165&Language=English&No=836&PartNo=4) was released for Quartus 16.0. This repository's simple RTL does not depend on a Terasic IP block, but Quartus Prime Pro must not be used because it does not support Cyclone V. Use a Lite or Standard edition with Cyclone V device support. Record the installed version after installation.

## Demo behaviour

The [board wrapper](../rtl/de1_soc_top.sv) connects the [capture core](../rtl/logic_analyzer.sv) to the Rev. F controls.

| Board control | Function |
| --- | --- |
| KEY0 | Active-low reset; hold while pressed |
| KEY1 | Press once to start or restart a capture |
| SW9..SW0 | Binary read address from 0 to 1023 after capture |
| LEDR8 | Busy while samples are being stored |
| LEDR9 | Done; a complete capture is ready |
| LEDR7..LEDR0 | Eight-bit sample at the selected address |

The wrapper generates one sample enable every 50 input clocks: `50 MHz / 50 = 1 MHz`. It captures 1,024 samples, so storage takes about 1.024 ms after sampling begins. This is too brief for the busy LED to be easy to see, but done remains lit.

The input is an internal eight-bit pattern, not a physical pin. It starts at zero and increases once per accepted sample. Therefore, address 0 should display 0, address 1 should display 1, address 255 should display `0xFF`, and address 256 should wrap to 0. Changing switches after completion updates the LEDs after synchronization and a registered read, a delay far below human perception.

KEY inputs are debounced by the board circuit according to the manual. The wrapper synchronizes KEY1 before detecting a press and synchronizes reset release. It also synchronizes each switch bit. Moving several switches at once can still briefly select an intermediate address; wait until the switches are settled before reading the LEDs.

## Project files

Open [vlsi_logic_analyzer.qpf](../quartus/vlsi_logic_analyzer.qpf) in Quartus. Its matching [QSF](../quartus/vlsi_logic_analyzer.qsf) selects the device, sources, SDC, and Rev. F clock/button/switch/LED pins. The [SDC](../quartus/de1_soc_top.sdc) constrains `CLOCK_50` to 20 ns and excludes asynchronous human controls and LEDs from external timing requirements.

The top-level entity is `de1_soc_top`. Only synthesizable files under `rtl/` belong in the Quartus project. Files under `tb/` are for Icarus simulation and are deliberately absent from the QSF.

## Compile

After installing Quartus Prime Lite or Standard with Cyclone V support:

1. Open `quartus/vlsi_logic_analyzer.qpf`.
2. Confirm **Assignments > Device** shows Cyclone V `5CSEMA5F31C6`.
3. Confirm **Assignments > Pin Planner** matches the QSF and the Rev. F/G manual.
4. Choose **Processing > Start Compilation**.
5. Review Flow Summary, critical warnings, resource use, and the TimeQuest timing summary. Do not treat generation of a `.sof` alone as proof that timing passed.

The equivalent PowerShell command is:

```powershell
cd "C:\Users\qowjd\Documents\GitHub\VLSI_logic_analyzer\quartus"
quartus_sh --flow compile vlsi_logic_analyzer
```

A successful compile creates `quartus/output_files/vlsi_logic_analyzer.sof`. Generated Quartus databases, reports, and programming files are excluded from Git.

## Program and observe

1. Power the DE1-SoC and connect the onboard USB-Blaster USB port.
2. Open **Tools > Programmer** and choose **Hardware Setup > USB-Blaster**.
3. Use JTAG mode. Add `output_files/vlsi_logic_analyzer.sof` if it is not already listed.
4. Enable **Program/Configure**, then choose **Start**.
5. Press and hold KEY0 briefly after programming, then release it.
6. Press KEY1. LEDR9 should become lit after the capture completes.
7. Set SW9..SW0 to a binary address and compare LEDR7..LEDR0 with the low eight bits of that address.

Programming a `.sof` configures volatile FPGA memory. The design is normally lost when board power is removed. Persistent flash programming is outside this first bring-up.

Do not mark the board milestone complete until Quartus compilation reports have been reviewed, Programmer identifies the expected device, and the observed LEDs match several selected addresses. Record the actual Quartus version, USB-Blaster result, compile/timing status, and observations in README after the checks are performed.
