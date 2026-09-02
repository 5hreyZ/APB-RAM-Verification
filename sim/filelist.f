# =============================================================================
# APB RAM Design & Verification Filelist
# =============================================================================

# Include Directories
+incdir+../
+incdir+../rtl
+incdir+../tb
+incdir+../tb/pkg
+incdir+../tb/if
+incdir+../tb/assertions
+incdir+../tb/classes
+incdir+../tb/tests

# RTL Sources
../rtl/apb_ram_memory_array.sv
../rtl/apb_slave_ram.sv

# Package
../tb/pkg/apb_pkg.sv

# Interface & SVA
../tb/if/apb_if.sv
../tb/assertions/apb_sva.sv

# Top-level Testbench
../tb/tb_top.sv
