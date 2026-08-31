# DE1-SoC Rev. F CLOCK_50 is a nominal 50 MHz input: 20 ns per period.
create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]

# KEY and SW are asynchronous board controls followed by synchronizer registers.
set_false_path -from [get_ports {KEY[*]}]
set_false_path -from [get_ports {SW[*]}]

# The red LEDs are human-visible status/data outputs with no external capture clock.
set_false_path -to [get_ports {LEDR[*]}]
