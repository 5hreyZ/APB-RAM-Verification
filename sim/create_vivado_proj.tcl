# =============================================================================
# File: create_vivado_proj.tcl
# Description: Automated Vivado Project Generator & Configuration Script
# Usage in Vivado GUI / Tcl Shell:
#   cd <project_dir>/sim
#   source create_vivado_proj.tcl
# =============================================================================

set proj_name "apb_ram_verification"
set proj_dir  "./vivado_project"
set part_name "xc7a35tcsg324-1" ;# Artix-7 baseline part (change to UltraScale if needed)

# Close any open project
close_project -quiet

# Create project directory and project
file mkdir $proj_dir
create_project $proj_name $proj_dir -part $part_name -force

# -----------------------------------------------------------------------------
# 1. Add RTL Sources
# -----------------------------------------------------------------------------
add_files -fileset sources_1 [list \
    "../rtl/apb_ram_memory_array.sv" \
    "../rtl/apb_slave_ram.sv" \
]

set_property file_type "SystemVerilog" [get_files -of_objects [get_filesets sources_1]]
set_property top apb_slave_ram [current_fileset]

# -----------------------------------------------------------------------------
# 2. Add Constraints Sources
# -----------------------------------------------------------------------------
if {[file exists "../synth/apb_ram_constraints.xdc"]} {
    add_files -fileset constrs_1 [list "../synth/apb_ram_constraints.xdc"]
}

# -----------------------------------------------------------------------------
# 3. Add Simulation Sources & Testbench
# -----------------------------------------------------------------------------
add_files -fileset sim_1 [list \
    "../tb/pkg/apb_pkg.sv" \
    "../tb/if/apb_if.sv" \
    "../tb/assertions/apb_sva.sv" \
    "../tb/tb_top.sv" \
]

set_property file_type "SystemVerilog" [get_files -of_objects [get_filesets sim_1]]
set_property top tb_top [get_filesets sim_1]

# Set Include Directories for Header/Class Inclusions
set_property include_dirs [list \
    "../" \
    "../rtl" \
    "../tb" \
    "../tb/pkg" \
    "../tb/if" \
    "../tb/assertions" \
    "../tb/classes" \
    "../tb/tests" \
] [get_filesets sim_1]

# Set Simulation Configuration Properties
set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.log_all_signals} -value {true} -objects [get_filesets sim_1]

puts "==============================================================================="
puts " \[SUCCESS\] Vivado Project '$proj_name' created successfully!"
puts " Run Simulation: launch_simulation"
puts " Run Synthesis : launch_runs synth_1 -jobs 4"
puts "==============================================================================="
