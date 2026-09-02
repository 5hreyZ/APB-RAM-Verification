# =============================================================================
# File: apb_ram_constraints.xdc
# Description: Timing Constraints & 100 MHz Clock Definition for APB RAM
# Author: Antigravity DV Team
# =============================================================================

# Define 100 MHz Primary Clock (10.0 ns period, 50% duty cycle)
create_clock -period 10.000 -name PCLK -waveform {0.000 5.000} [get_ports PCLK]

# Set Input Delays (2.0 ns setup budget relative to PCLK)
set_input_delay -clock [get_clocks PCLK] 2.000 [get_ports {PRESETn PSEL PENABLE PWRITE}]
set_input_delay -clock [get_clocks PCLK] 2.000 [get_ports PADDR*]
set_input_delay -clock [get_clocks PCLK] 2.000 [get_ports PWDATA*]
set_input_delay -clock [get_clocks PCLK] 2.000 [get_ports PSTRB*]
set_input_delay -clock [get_clocks PCLK] 2.000 [get_ports PPROT*]

# Set Output Delays (2.0 ns setup budget relative to PCLK)
set_output_delay -clock [get_clocks PCLK] 2.000 [get_ports PREADY]
set_output_delay -clock [get_clocks PCLK] 2.000 [get_ports PRDATA*]
set_output_delay -clock [get_clocks PCLK] 2.000 [get_ports PSLVERR]
