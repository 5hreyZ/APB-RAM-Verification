# =============================================================================
# File: run_vivado_sim.tcl
# Description: Standalone Vivado xsim Simulation Runner via TCL
# Usage:
#   vivado -mode batch -source run_vivado_sim.tcl -tclargs <testname>
# Example:
#   vivado -mode batch -source run_vivado_sim.tcl -tclargs test_random
# =============================================================================

# Parse testcase argument
set testname "test_base"
if { $argc > 0 } {
    set testname [lindex $argv 0]
}

puts "==============================================================================="
puts " Starting Vivado Simulation for Testcase: $testname"
puts "==============================================================================="

file mkdir xsim_run
file mkdir logs

# Include directories
set inc_dirs "-i ../ -i ../rtl -i ../tb -i ../tb/pkg -i ../tb/if -i ../tb/assertions -i ../tb/classes -i ../tb/tests"

# 1. Compile RTL and Testbench using xvlog
puts "\[1/3\] Compiling SystemVerilog Sources with xvlog..."
set compile_cmd "xvlog -sv $inc_dirs ../rtl/apb_ram_memory_array.sv ../rtl/apb_slave_ram.sv ../tb/pkg/apb_pkg.sv ../tb/if/apb_if.sv ../tb/assertions/apb_sva.sv ../tb/tb_top.sv -log logs/xvlog.log"
if {[catch {eval exec $compile_cmd} msg]} {
    puts "Compilation Output:\n$msg"
}

# 2. Elaborate Design with xelab
puts "\[2/3\] Elaborating Simulation Snapshot with xelab..."
set elab_cmd "xelab -sv_lib dpi -timescale 1ns/1ps -debug typical -s top_sim tb_top -log logs/xelab.log"
if {[catch {eval exec $elab_cmd} msg]} {
    puts "Elaboration Output:\n$msg"
}

# 3. Simulate with xsim
puts "\[3/3\] Running Simulation Snapshot with xsim (+TESTNAME=$testname)..."
set sim_cmd "xsim top_sim -R -testplusarg TESTNAME=$testname -log logs/${testname}_vivado.log"
if {[catch {eval exec $sim_cmd} msg]} {
    puts "Simulation Output:\n$msg"
}

puts "==============================================================================="
puts " Simulation Finished. Log saved to: logs/${testname}_vivado.log"
puts "==============================================================================="
