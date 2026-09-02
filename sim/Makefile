# =============================================================================
# Makefile for AMBA APB RAM Controller Design & Verification
# Multi-Simulator Support: Synopsys VCS, Siemens Questa, Cadence Xcelium, Xilinx Vivado
# =============================================================================

TEST ?= test_base
SEED ?= 1
GUI  ?= 0

TESTS = test_base test_random test_byte_strobe test_error_handling test_b2b_stress test_wait_states

.PHONY: help vcs questa xcelium vivado regression clean wave

help:
	@echo "==============================================================================="
	@echo "                      AMBA APB RAM CONTROLLER SIMULATION SUITE                 "
	@echo "==============================================================================="
	@echo " Available Targets:"
	@echo "   make run_py                     : Run cycle-accurate Python simulation & regression"
	@echo "   make vcs        TEST=<testname>  : Compile & run using Synopsys VCS"
	@echo "   make questa     TEST=<testname>  : Compile & run using Siemens Questa/ModelSim"
	@echo "   make xcelium    TEST=<testname>  : Compile & run using Cadence Xcelium"
	@echo "   make vivado     TEST=<testname>  : Compile & run using Xilinx Vivado (xsim)"
	@echo "   make regression SIM=<simulator>  : Run entire test suite and generate summary"
	@echo "   make wave                        : Open waveform in GTKWave"
	@echo "   make clean                       : Clean all simulation logs and artifacts"
	@echo ""
	@echo " Available Testcases:"
	@echo "   test_base           : Sanity write/read smoke test"
	@echo "   test_random         : 1000+ transaction constrained-random stress test"
	@echo "   test_byte_strobe    : Exhaustive byte masking (PSTRB) verification"
	@echo "   test_error_handling : Negative testing (out-of-bounds & unaligned PSLVERR)"
	@echo "   test_b2b_stress     : Zero-wait-state back-to-back read/write burst test"
	@echo "   test_wait_states    : Handshake and wait-cycle response test"
	@echo "==============================================================================="

run_py:
	@python3 py_sim.py --test all

# -----------------------------------------------------------------------------
# Synopsys VCS
# -----------------------------------------------------------------------------
vcs:
	mkdir -p work_vcs logs
	vcs -full64 -sverilog +v2k -timescale=1ns/1ps \
		-assert svaext -assert enable_diag \
		-cm line+cond+fsm+tgl+branch+assert \
		-f filelist.f \
		-o work_vcs/simv \
		-l logs/compile_vcs.log
	./work_vcs/simv +TESTNAME=$(TEST) +ntb_random_seed=$(SEED) \
		-cm line+cond+fsm+tgl+branch+assert \
		-l logs/$(TEST)_vcs.log

# -----------------------------------------------------------------------------
# Siemens Questa / ModelSim
# -----------------------------------------------------------------------------
questa:
	mkdir -p work logs
	vlib work
	vlog -sv -timescale "1ns/1ps" +cover=sbfec +acc -f filelist.f -l logs/compile_questa.log
	vsim -c -coverage tb_top +TESTNAME=$(TEST) -sv_seed $(SEED) \
		-do "coverage save -onexit logs/$(TEST)_cov.ucdb; run -all; quit" \
		-l logs/$(TEST)_questa.log

# -----------------------------------------------------------------------------
# Cadence Xcelium
# -----------------------------------------------------------------------------
xcelium:
	mkdir -p logs
	xrun -64bit -sv -timescale 1ns/1ps \
		-coverage all -covoverwrite \
		-f filelist.f \
		+TESTNAME=$(TEST) -svseed $(SEED) \
		-l logs/$(TEST)_xcelium.log

# -----------------------------------------------------------------------------
# Xilinx Vivado (xsim)
# -----------------------------------------------------------------------------
vivado:
	mkdir -p xsim_dir logs
	xvlog -sv -f filelist.f -log logs/xvlog.log
	xelab tb_top -s top_sim -timescale 1ns/1ps -log logs/xelab.log
	xsim top_sim -R -testplusarg TESTNAME=$(TEST) -log logs/$(TEST)_vivado.log

# -----------------------------------------------------------------------------
# Automated Full Regression Runner
# -----------------------------------------------------------------------------
regression:
	@python3 run_sim.py

# -----------------------------------------------------------------------------
# Waveform Viewing
# -----------------------------------------------------------------------------
wave:
	gtkwave waveform.vcd &

# -----------------------------------------------------------------------------
# Cleanup
# -----------------------------------------------------------------------------
clean:
	rm -rf work work_vcs xsim.dir .simvision xcelium.d
	rm -rf logs *.log *.vcd *.vpd *.wlf *.ucdb *.key transcript
	rm -rf xvlog.* xelab.* xsim.* *.jou
	@echo "Cleaned all simulation outputs."
