# EDA Playground 1-Click Simulation Guide

This project includes a pre-packaged single-file SystemVerilog testbench (`eda_playground_bundle.sv`) allowing anyone (including recruiters, hiring managers, and interviewers) to run the full RTL design, OOP verification environment, assertions, and randomized test suite directly in a web browser without needing local EDA tool licenses.

---

## 🚀 Quick Steps to Run on EDA Playground

1. Go to **[EDA Playground](https://www.edaplayground.com/)** (free account).
2. On the left sidebar settings:
   - **Language**: `SystemVerilog / Verilog`
   - **Tools & Simulators**: Choose **Aldec Riviera-PRO**, **Synopsys VCS**, or **Cadence Xcelium / Siemens Questa**.
   - Check the box **"Open EPWave after run"** (if you want to inspect waveforms).
3. Copy the contents of [`eda_playground_bundle.sv`](eda_playground_bundle.sv).
4. Paste the entire code into the **`testbench.sv`** editor tab on EDA Playground (leave `design.sv` empty, as everything is self-contained).
5. Click the blue **"Run"** button at the top toolbar.

---

## 📊 Expected Output in Console

```text
0 | [INFO]  | DRIVER       | Driver signals initialized to default state.
[TB_TOP] Reset deasserted at time 35000
0 | [INFO]  | DRIVER       | Reset deasserted. Driver active.

[TB] === Starting Comprehensive Verification Regression ===
[TB] Step 1: Testing Byte-Masked Writes (PSTRB)...
[TB] Step 2: Testing Out-of-Bounds & Unaligned Error Injections (PSLVERR)...
[TB] Step 3: Running Constrained-Random Stress Test...

===============================================================================
                          VERIFICATION SCOREBOARD REPORT                       
===============================================================================
 Total Transactions Processed : 210
 Total Writes Verified        : 104
 Total Reads Verified         : 104
 Total Matches (PASS)         : 210
 Total Mismatches (FAIL)      : 0
-------------------------------------------------------------------------------
                    >>> TEST STATUS: PASSED (100% MATCH) <<<                   
===============================================================================

[TB] === Simulation Completed Successfully! ===
```

---

## 🔍 Key Highlights Validated in the Bundle
- **AMBA APB4 Protocol Handshake**: SETUP -> ACCESS phase handshakes with zero wait states.
- **Byte Write-Masking**: Tested via incremental single-byte writes (`4'b0001`, `4'b0010`, `4'b0100`, `4'b1000`) and preserved non-written bytes.
- **Negative Testing & PSLVERR**: Validates that out-of-bounds and unaligned memory accesses correctly trigger `PSLVERR = 1`.
- **SystemVerilog Assertions (SVA)**: Bound concurrent assertions verifying protocol rules.
- **Constrained-Random Verification (CRV)**: 200+ randomized transfers checked against an associative byte-level golden reference memory model.
