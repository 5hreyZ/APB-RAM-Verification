# Comprehensive Guide: Running APB RAM Controller in Xilinx Vivado

This guide provides step-by-step instructions to simulate, verify, and synthesize the **AMBA APB4 RAM Controller** project in **Xilinx Vivado (2020.1 to 2024.x+)**.

---

## 📋 Table of Contents
1. [Quickstart: 1-Command Automated Simulation](#1-quickstart-1-command-automated-simulation)
2. [Method A: Vivado GUI Project Setup](#2-method-a-vivado-gui-project-setup)
3. [Method B: Vivado Batch / Command-Line Mode](#3-method-b-vivado-batch--command-line-mode)
4. [Inspecting Waveforms in Vivado Waveform Viewer](#4-inspecting-waveforms-in-vivado-waveform-viewer)
5. [Running RTL Synthesis & Utilization Reports](#5-running-rtl-synthesis--utilization-reports)
6. [Selecting Testcases via Plusargs](#6-selecting-testcases-via-plusargs)

---

## 1. Quickstart: 1-Command Automated Simulation

From your terminal or Vivado command prompt:

```bash
cd apb_ram_design_verification/sim

# Run default smoke test (test_base)
vivado -mode batch -source run_vivado_sim.tcl

# Run 1000+ transaction randomized stress test
vivado -mode batch -source run_vivado_sim.tcl -tclargs test_random

# Run targeted byte-strobe masking verification
vivado -mode batch -source run_vivado_sim.tcl -tclargs test_byte_strobe
```

---

## 2. Method A: Vivado GUI Project Setup

### Step 1: Open Vivado and Execute Project Generation Script
1. Launch Vivado:
   ```bash
   vivado
   ```
2. In the Vivado Tcl Console at the bottom of the window, navigate to the `sim` directory and source the project script:
   ```tcl
   cd <path_to_repo>/apb_ram_design_verification/sim
   source create_vivado_proj.tcl
   ```
   *This automatically creates a configured Vivado project with all RTL files, testbench components, include directories, and simulation properties configured.*

### Step 2: Run Behavioral Simulation in GUI
1. In the **Flow Navigator** on the left panel, click **Run Simulation** $\rightarrow$ **Run Behavioral Simulation**.
2. Vivado will compile all SystemVerilog sources and open the simulation waveform viewer.
3. In the Tcl Console, enter:
   ```tcl
   run all
   ```
4. View the live simulation logs in the **Tcl Console** or **Log tab** to see the Scoreboard match count and SVA assertions.

---

## 3. Method B: Vivado Batch / Command-Line Mode

You can run Vivado's native simulator (`xvlog`, `xelab`, `xsim`) directly without opening the full GUI:

```bash
cd apb_ram_design_verification/sim

# 1. Compile RTL & Testbench Sources
xvlog -sv -i ../ -i ../rtl -i ../tb -i ../tb/pkg -i ../tb/if -i ../tb/assertions -i ../tb/classes -i ../tb/tests \
    ../rtl/apb_ram_memory_array.sv \
    ../rtl/apb_slave_ram.sv \
    ../tb/pkg/apb_pkg.sv \
    ../tb/if/apb_if.sv \
    ../tb/assertions/apb_sva.sv \
    ../tb/tb_top.sv \
    -log logs/xvlog.log

# 2. Elaborate Design Snapshot
xelab -sv_lib dpi -timescale 1ns/1ps -debug typical -s top_sim tb_top -log logs/xelab.log

# 3. Execute Simulation with Desired Testcase
xsim top_sim -R -testplusarg TESTNAME=test_random -log logs/test_random_vivado.log
```

---

## 4. Inspecting Waveforms in Vivado Waveform Viewer

1. When running behavioral simulation in GUI, Vivado displays all top-level signals:
   - `PCLK`, `PRESETn`
   - `PSEL`, `PENABLE`, `PWRITE`
   - `PADDR[31:0]`, `PWDATA[31:0]`, `PSTRB[3:0]`, `PPROT[2:0]`
   - `PREADY`, `PRDATA[31:0]`, `PSLVERR`
2. **Adding Internal Signals**: Expand `u_dut` in the Scope window to drag internal signals (such as `ram_write_en`, `word_addr`, `valid_access`) into the waveform window.
3. **Saving Waveform Layout**: Click **File $\rightarrow$ Save Waveform Configuration As...** to save as `apb_signals.wcfg`.

---

## 5. Running RTL Synthesis & Utilization Reports

To verify that the RTL controller synthesizes cleanly for Xilinx FPGAs and generate resource utilization numbers:

```bash
cd apb_ram_design_verification/sim
vivado -mode batch -source run_vivado_synth.tcl
```

### Expected Output & Resource Utilization (Artix-7 `xc7a35t`):
- **LUTs (Look-Up Tables)**: ~120 - 180 LUTs (Address decoding, strobe masking, ready logic)
- **Flip-Flops (Registers)**: ~32 FFs
- **BRAM / Distributed RAM**: Inferred RAM array
- **Timing Closure**: $F_{\max} > 250\text{ MHz}$ on -1 speed grade

Reports are saved in `sim/reports/`:
- `utilization_synth.rpt`
- `timing_synth.rpt`
- `power_synth.rpt`

---

## 6. Selecting Testcases via Plusargs

The top-level harness `tb_top.sv` supports dynamic testcase selection using the `+TESTNAME=<name>` plusarg:

| Plusarg Option | Test Description |
| :--- | :--- |
| `+TESTNAME=test_base` | Sanity write and read smoke test. |
| `+TESTNAME=test_random` | 1000+ constrained-random transfers with random address, data, and strobe. |
| `+TESTNAME=test_byte_strobe` | Exhaustive byte write-masking verification (`PSTRB[3:0]`). |
| `+TESTNAME=test_error_handling`| Out-of-bounds address and unaligned address injection (`PSLVERR`). |
| `+TESTNAME=test_b2b_stress` | Zero-idle-delay burst read/write collision stress test. |
| `+TESTNAME=test_wait_states` | Multi-cycle wait-state injection test. |

In Vivado GUI Tcl Console:
```tcl
set_property -name {xsim.simulate.xsim.more_options} -value {-testplusarg TESTNAME=test_random} -objects [get_filesets sim_1]
launch_simulation
```
