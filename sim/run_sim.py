#!/usr/bin/env python3
"""
=============================================================================
File: run_sim.py
Description: Automated Test Runner & Regression Manager for APB RAM Verification
Author: Antigravity DV Team
=============================================================================
"""

import sys
import os
import subprocess
import time
import argparse
import shutil
import re

TEST_SUITE = [
    "test_base",
    "test_random",
    "test_byte_strobe",
    "test_error_handling",
    "test_b2b_stress",
    "test_wait_states"
]

SIMULATORS = {
    "vcs": {
        "check": "vcs",
        "compile_cmd": "vcs -full64 -sverilog +v2k -timescale=1ns/1ps -assert svaext -assert enable_diag -cm line+cond+fsm+tgl+branch+assert -f filelist.f -o work_vcs/simv -l logs/compile_vcs.log",
        "run_cmd": "./work_vcs/simv +TESTNAME={test} +ntb_random_seed={seed} -l logs/{test}_vcs.log"
    },
    "questa": {
        "check": "vsim",
        "compile_cmd": "vlib work && vlog -sv -timescale 1ns/1ps +cover=sbfec +acc -f filelist.f -l logs/compile_questa.log",
        "run_cmd": "vsim -c -coverage tb_top +TESTNAME={test} -sv_seed {seed} -do 'coverage save -onexit logs/{test}_cov.ucdb; run -all; quit' -l logs/{test}_questa.log"
    },
    "vivado": {
        "check": "xvlog",
        "compile_cmd": "xvlog -sv -f filelist.f -log logs/xvlog.log && xelab tb_top -s top_sim -timescale 1ns/1ps -log logs/xelab.log",
        "run_cmd": "xsim top_sim -R -testplusarg TESTNAME={test} -log logs/{test}_vivado.log"
    },
    "xcelium": {
        "check": "xrun",
        "compile_cmd": "xrun -64bit -sv -timescale 1ns/1ps -coverage all -covoverwrite -f filelist.f +TESTNAME={test} -svseed {seed} -l logs/{test}_xcelium.log",
        "run_cmd": ""
    }
}

def detect_simulator():
    for sim_name, sim_cfg in SIMULATORS.items():
        if shutil.which(sim_cfg["check"]) is not None:
            return sim_name
    return None

def parse_log(log_path):
    """Parses simulation log for transactions, score, and coverage."""
    trans_cnt = "N/A"
    status = "UNKNOWN"
    coverage = "N/A"
    
    if not os.path.exists(log_path):
        return status, trans_cnt, coverage
        
    with open(log_path, "r", errors="ignore") as f:
        content = f.read()

        # Check for PASS / FAIL
        if "TEST STATUS: PASSED" in content or "Simulation successfully finished" in content:
            if "FAIL" not in content or "0 ERRORS" in content:
                status = "PASSED"
            else:
                status = "FAILED"
        elif "FATAL" in content or "FAIL" in content or "Error" in content:
            status = "FAILED"

        # Extract transaction count
        trans_match = re.search(r"Total Transactions Processed\s*:\s*(\d+)", content)
        if trans_match:
            trans_cnt = trans_match.group(1)

        # Extract coverage
        cov_match = re.search(r"Overall Coverage Achieved\s*:\s*([\d\.]+)%", content)
        if cov_match:
            coverage = f"{cov_match.group(1)}%"

    return status, trans_cnt, coverage

def run_regression(sim_name, tests, seed):
    os.makedirs("logs", exist_ok=True)
    results = []

    print("\n" + "="*80)
    print(f"       AMBA APB RAM CONTROLLER REGRESSION RUNNER (Simulator: {sim_name.upper()})")
    print("="*80)

    # Compilation step
    cfg = SIMULATORS[sim_name]
    if cfg["compile_cmd"]:
        print(f"[*] Compiling SystemVerilog Design & Testbench sources...")
        t_start = time.time()
        ret = subprocess.run(cfg["compile_cmd"], shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        comp_time = time.time() - t_start
        if ret.returncode != 0:
            print(f"[!] Compilation FAILED in {comp_time:.2f}s! See logs/compile_{sim_name}.log")
            print(ret.stderr or ret.stdout)
            return
        print(f"[+] Compilation SUCCESS in {comp_time:.2f}s.\n")

    # Run tests
    for test in tests:
        print(f"[*] Running testcase: {test} (Seed: {seed})...", end="", flush=True)
        run_cmd = cfg["run_cmd"].format(test=test, seed=seed) if cfg["run_cmd"] else cfg["compile_cmd"].format(test=test, seed=seed)
        log_file = f"logs/{test}_{sim_name}.log"

        t_start = time.time()
        ret = subprocess.run(run_cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        elapsed = time.time() - t_start

        # Parse log
        status, trans_cnt, coverage = parse_log(log_file)
        if ret.returncode != 0 and status != "FAILED":
            status = "FAILED"

        tag = "\033[92mPASS\033[0m" if status == "PASSED" else "\033[91mFAIL\033[0m"
        print(f" [{tag}] ({elapsed:.2f}s)")
        results.append({
            "name": test,
            "status": status,
            "trans": trans_cnt,
            "coverage": coverage,
            "time": f"{elapsed:.2f}s"
        })

    # Summary Table
    print("\n" + "="*80)
    print("                             REGRESSION SUMMARY REPORT                         ")
    print("="*80)
    print(f"{'Testcase Name':<25} | {'Status':<10} | {'Trans Count':<12} | {'Coverage':<10} | {'Time':<8}")
    print("-" * 80)
    
    passed = 0
    for r in results:
        status_disp = r['status']
        if r['status'] == "PASSED":
            passed += 1
        print(f"{r['name']:<25} | {status_disp:<10} | {r['trans']:<12} | {r['coverage']:<10} | {r['time']:<8}")
    
    print("-" * 80)
    print(f" Total Executed: {len(results)} | Passed: {passed} | Failed: {len(results) - passed}")
    print("="*80 + "\n")

def main():
    parser = argparse.ArgumentParser(description="APB RAM Regression Runner")
    parser.add_argument("--sim", choices=["vcs", "questa", "vivado", "xcelium"], help="Simulator selection")
    parser.add_argument("--test", choices=TEST_SUITE + ["all"], default="all", help="Target testcase or 'all'")
    parser.add_argument("--seed", type=int, default=1, help="Randomization seed")
    args = parser.parse_args()

    sim = args.sim or detect_simulator()
    if not sim:
        print("\n[!] No supported commercial simulator (VCS, Questa/ModelSim, Vivado, Xcelium) detected in PATH.")
        print("[i] To run simulation locally, install a simulator or use the EDA Playground bundle in 'eda_playground/'!")
        print("[i] Available testcases in this testbench:")
        for t in TEST_SUITE:
            print(f"    - {t}")
        return

    tests = TEST_SUITE if args.test == "all" else [args.test]
    run_regression(sim, tests, args.seed)

if __name__ == "__main__":
    main()
