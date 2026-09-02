# =============================================================================
# File: run_vivado_synth.tcl
# Description: Out-of-Context RTL Synthesis & Timing/Resource Estimation
# Usage:
#   vivado -mode batch -source run_vivado_synth.tcl
# =============================================================================

set part_name "xc7a35tcsg324-1"
set top_module "apb_slave_ram"

file mkdir reports
file mkdir synth_out

puts "==============================================================================="
puts " Running Vivado Out-of-Context Synthesis for: $top_module (Part: $part_name)"
puts "==============================================================================="

# Read RTL files
read_verilog -sv ../rtl/apb_ram_memory_array.sv
read_verilog -sv ../rtl/apb_slave_ram.sv

# Read Timing Constraints
if {[file exists "../synth/apb_ram_constraints.xdc"]} {
    read_xdc ../synth/apb_ram_constraints.xdc
}

# Synthesize design
synth_design -top $top_module -part $part_name -mode out_of_context

# Generate Utilization & Timing Reports
report_utilization -file reports/utilization_synth.rpt
report_timing_summary -file reports/timing_synth.rpt
report_power -file reports/power_synth.rpt

puts "==============================================================================="
puts " Synthesis Completed Successfully!"
puts " Reports generated in sim/reports/:"
puts "   - utilization_synth.rpt (LUTs, FFs, BRAM slices)"
puts "   - timing_synth.rpt      (Setup/Hold slack & Fmax)"
puts "   - power_synth.rpt       (Dynamic & Static Power)"
puts "==============================================================================="
