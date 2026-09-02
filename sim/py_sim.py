#!/usr/bin/env python3
"""
=============================================================================
File: py_sim.py
Description: Cycle-Accurate Python Digital Simulation Engine & Regression Runner
             Implements exact RTL cycle semantics, SVA protocol checks,
             CRV test scenarios, VCD waveform generation, and functional coverage.
Author: Antigravity DV Team
=============================================================================
"""

import sys
import os
import random
import time
import argparse

# -----------------------------------------------------------------------------
# 1. VCD Waveform Dumper (IEEE 1364 Standard)
# -----------------------------------------------------------------------------
class VcdDumper:
    def __init__(self, filename="waveform.vcd"):
        self.filename = filename
        self.file = open(filename, "w")
        self.vars = {}
        self.var_id_counter = 33 # ASCII printable
        self.current_time = 0
        self.last_values = {}

    def register_var(self, name, size):
        var_id = chr(self.var_id_counter)
        self.var_id_counter += 1
        self.vars[name] = {"id": var_id, "size": size}
        return var_id

    def write_header(self):
        self.file.write("$date\n   " + time.asctime() + "\n$end\n")
        self.file.write("$version\n   Cycle-Accurate APB Simulation Engine v1.0\n$end\n")
        self.file.write("$timescale\n   1ns\n$end\n")
        self.file.write("$scope module tb_top $end\n")
        self.file.write("$scope module apb_bus $end\n")
        for name, info in self.vars.items():
            self.file.write(f"$var wire {info['size']} {info['id']} {name} $end\n")
        self.file.write("$upscope $end\n")
        self.file.write("$upscope $end\n")
        self.file.write("$enddefinitions $end\n")
        self.file.write("$dumpvars\n")
        for name, info in self.vars.items():
            val = "0" if info['size'] == 1 else f"b{'0'*info['size']}"
            self.file.write(f"{val} {info['id']}\n")
            self.last_values[name] = 0
        self.file.write("$end\n")

    def dump(self, time_ns, signal_dict):
        if time_ns != self.current_time:
            self.file.write(f"#{time_ns}\n")
            self.current_time = time_ns

        for name, val in signal_dict.items():
            if name in self.vars and (name not in self.last_values or self.last_values[name] != val):
                info = self.vars[name]
                if info['size'] == 1:
                    self.file.write(f"{int(val)} {info['id']}\n")
                else:
                    bin_str = bin(int(val))[2:].zfill(info['size'])
                    self.file.write(f"b{bin_str} {info['id']}\n")
                self.last_values[name] = val

    def close(self):
        self.file.close()

# -----------------------------------------------------------------------------
# 2. Synthesizable APB4 RAM Controller RTL Model
# -----------------------------------------------------------------------------
class ApbSlaveRamRtl:
    def __init__(self, addr_width=32, data_width=32, mem_depth=1024, base_addr=0x00000000, wait_cycles=0):
        self.addr_width = addr_width
        self.data_width = data_width
        self.mem_depth = mem_depth
        self.base_addr = base_addr
        self.wait_cycles = wait_cycles
        self.bytes_per_word = data_width // 8
        self.mem_size_bytes = mem_depth * self.bytes_per_word
        self.max_addr = base_addr + self.mem_size_bytes - 1

        # Memory array: 1024 words x 4 bytes
        self.mem = bytearray(self.mem_size_bytes)

        # State and outputs
        self.wait_cnt = 0
        self.pready = 1
        self.prdata = 0
        self.pslverr = 0

    def step(self, presetn, psel, penable, pwrite, paddr, pwdata, pstrb, pprot):
        if not presetn:
            self.wait_cnt = 0
            self.pready = 1
            self.prdata = 0
            self.pslverr = 0
            return self.pready, self.prdata, self.pslverr

        # Address decoding & alignment checks
        addr_in_range = (paddr >= self.base_addr) and (paddr <= self.max_addr)
        addr_aligned = (paddr & (self.bytes_per_word - 1)) == 0
        valid_access = addr_in_range and addr_aligned
        byte_offset = paddr - self.base_addr

        # Wait-state counter
        if psel and penable:
            if self.wait_cnt < self.wait_cycles:
                self.wait_cnt += 1
            else:
                self.wait_cnt = 0
        else:
            self.wait_cnt = 0

        # Ready generation
        if psel and penable:
            self.pready = 1 if (self.wait_cycles == 0 or self.wait_cnt == self.wait_cycles) else 0
        else:
            self.pready = 1

        # Error response (PSLVERR)
        if psel and penable and self.pready:
            self.pslverr = 1 if not valid_access else 0
        else:
            self.pslverr = 0

        # Memory Read & Write execution at active ready edge
        if psel and penable and self.pready and valid_access:
            if pwrite:
                # Byte-enable write masking (PSTRB)
                for b in range(self.bytes_per_word):
                    if (pstrb >> b) & 1:
                        byte_val = (pwdata >> (b * 8)) & 0xFF
                        self.mem[byte_offset + b] = byte_val
            else:
                # Read 32-bit word
                rval = 0
                for b in range(self.bytes_per_word):
                    rval |= (self.mem[byte_offset + b] << (b * 8))
                self.prdata = rval
        elif psel and (not pwrite) and valid_access:
            # Combinational read data preview
            rval = 0
            for b in range(self.bytes_per_word):
                rval |= (self.mem[byte_offset + b] << (b * 8))
            self.prdata = rval
        else:
            self.prdata = 0

        return self.pready, self.prdata, self.pslverr

# -----------------------------------------------------------------------------
# 3. SystemVerilog Assertions (SVA) Protocol Checker
# -----------------------------------------------------------------------------
class ApbSvaChecker:
    def __init__(self):
        self.prev_psel = 0
        self.prev_penable = 0
        self.prev_pready = 1
        self.prev_paddr = 0
        self.prev_pwrite = 0
        self.prev_pwdata = 0
        self.prev_pstrb = 0
        self.assertion_violations = 0
        self.assertions_checked = 0

    def check(self, time_ns, presetn, psel, penable, pwrite, paddr, pwdata, pstrb, pprot, pready, prdata, pslverr):
        if not presetn:
            if pslverr != 0:
                print(f"{time_ns} | [SVA ERROR] Rule 5 Violation: PSLVERR active during reset!")
                self.assertion_violations += 1
            self.prev_psel = psel
            self.prev_penable = penable
            self.prev_pready = pready
            return

        self.assertions_checked += 1

        # SVA Rule 1: (PSEL && !PENABLE) |=> (PSEL && PENABLE)
        if self.prev_psel and (not self.prev_penable):
            if not (psel and penable):
                print(f"{time_ns} | [SVA ERROR] Rule 1 Violation: SETUP phase did not transition to ACCESS phase!")
                self.assertion_violations += 1

        # SVA Rule 2: (PSEL && PENABLE && PREADY) |=> (!PENABLE)
        if self.prev_psel and self.prev_penable and self.prev_pready:
            if penable:
                print(f"{time_ns} | [SVA ERROR] Rule 2 Violation: PENABLE held after handshake completion!")
                self.assertion_violations += 1

        # SVA Rule 3: Signal stability during wait states (PSEL && PENABLE && !PREADY)
        if self.prev_psel and self.prev_penable and (not self.prev_pready):
            if paddr != self.prev_paddr:
                print(f"{time_ns} | [SVA ERROR] Rule 3 Violation: PADDR changed during wait state!")
                self.assertion_violations += 1
            if pwrite != self.prev_pwrite:
                print(f"{time_ns} | [SVA ERROR] Rule 3 Violation: PWRITE changed during wait state!")
                self.assertion_violations += 1
            if pwrite and (pwdata != self.prev_pwdata or pstrb != self.prev_pstrb):
                print(f"{time_ns} | [SVA ERROR] Rule 3 Violation: PWDATA/PSTRB changed during write wait state!")
                self.assertion_violations += 1

        # SVA Rule 4: PSLVERR |-> (PSEL && PENABLE && PREADY)
        if pslverr:
            if not (psel and penable and pready):
                print(f"{time_ns} | [SVA ERROR] Rule 4 Violation: PSLVERR asserted outside valid access handshake!")
                self.assertion_violations += 1

        self.prev_psel = psel
        self.prev_penable = penable
        self.prev_pready = pready
        self.prev_paddr = paddr
        self.prev_pwrite = pwrite
        self.prev_pwdata = pwdata
        self.prev_pstrb = pstrb

# -----------------------------------------------------------------------------
# 4. Functional Coverage Engine
# -----------------------------------------------------------------------------
class ApbCoverageCollector:
    def __init__(self, base_addr=0x00000000, max_addr=0x00000FFF):
        self.base_addr = base_addr
        self.max_addr = max_addr

        # Coverpoints
        self.cp_type = {"WRITE": 0, "READ": 0}
        self.cp_addr = {
            "min_addr": 0, "max_addr": 0, "low_range": 0,
            "mid_range": 0, "high_range": 0, "out_of_bounds": 0
        }
        self.cp_strb = {
            "single_byte_0": 0, "single_byte_1": 0, "single_byte_2": 0, "single_byte_3": 0,
            "lower_half": 0, "upper_half": 0, "full_word": 0, "other": 0
        }
        self.cp_resp = {"OKAY": 0, "ERROR": 0}
        self.cp_idle = {"b2b": 0, "delay_1": 0, "delay_2": 0, "delay_multi": 0}

        # Cross coverage
        self.cross_type_x_strb = {}
        for t in ["WRITE", "READ"]:
            for s in self.cp_strb.keys():
                self.cross_type_x_strb[(t, s)] = 0

        self.cross_type_x_addr = {}
        for t in ["WRITE", "READ"]:
            for a in self.cp_addr.keys():
                self.cross_type_x_addr[(t, a)] = 0

    def sample(self, trans_type, addr, strb, resp, idle_cycles):
        # Type
        self.cp_type[trans_type] += 1

        # Addr
        if addr == self.base_addr:
            self.cp_addr["min_addr"] += 1
            a_key = "min_addr"
        elif addr == (self.max_addr - 3):
            self.cp_addr["max_addr"] += 1
            a_key = "max_addr"
        elif self.base_addr <= addr <= (self.base_addr + 0x3FC):
            self.cp_addr["low_range"] += 1
            a_key = "low_range"
        elif (self.base_addr + 0x400) <= addr <= (self.base_addr + 0xBFC):
            self.cp_addr["mid_range"] += 1
            a_key = "mid_range"
        elif (self.base_addr + 0xC00) <= addr <= self.max_addr:
            self.cp_addr["high_range"] += 1
            a_key = "high_range"
        else:
            self.cp_addr["out_of_bounds"] += 1
            a_key = "out_of_bounds"

        # Strb
        if strb == 0b0001: str_key = "single_byte_0"
        elif strb == 0b0010: str_key = "single_byte_1"
        elif strb == 0b0100: str_key = "single_byte_2"
        elif strb == 0b1000: str_key = "single_byte_3"
        elif strb == 0b0011: str_key = "lower_half"
        elif strb == 0b1100: str_key = "upper_half"
        elif strb == 0b1111: str_key = "full_word"
        else: str_key = "other"
        self.cp_strb[str_key] += 1

        # Resp
        self.cp_resp[resp] += 1

        # Idle
        if idle_cycles == 0: self.cp_idle["b2b"] += 1
        elif idle_cycles == 1: self.cp_idle["delay_1"] += 1
        elif idle_cycles == 2: self.cp_idle["delay_2"] += 1
        else: self.cp_idle["delay_multi"] += 1

        self.cross_type_x_strb[(trans_type, str_key)] += 1
        self.cross_type_x_addr[(trans_type, a_key)] += 1

    def calculate_coverage(self):
        def hit_ratio(d):
            hits = sum(1 for v in d.values() if v > 0)
            return (hits / len(d)) * 100.0

        cov_type = hit_ratio(self.cp_type)
        cov_addr = hit_ratio(self.cp_addr)
        cov_strb = hit_ratio(self.cp_strb)
        cov_resp = hit_ratio(self.cp_resp)
        cov_idle = hit_ratio(self.cp_idle)
        cov_cross_strb = hit_ratio(self.cross_type_x_strb)
        cov_cross_addr = hit_ratio(self.cross_type_x_addr)

        overall = (cov_type + cov_addr + cov_strb + cov_resp + cov_idle + cov_cross_strb + cov_cross_addr) / 7.0
        return {
            "overall": overall,
            "type": cov_type,
            "addr": cov_addr,
            "strb": cov_strb,
            "resp": cov_resp,
            "idle": cov_idle,
            "cross_strb": cov_cross_strb,
            "cross_addr": cov_cross_addr
        }

    def print_report(self):
        cov = self.calculate_coverage()
        print("\n===============================================================================")
        print("                          FUNCTIONAL COVERAGE REPORT                           ")
        print("===============================================================================")
        print(f" Overall Coverage Achieved     : {cov['overall']:0.2f}%")
        print(f" Type Coverpoint Coverage       : {cov['type']:0.2f}%")
        print(f" Address Space Coverage         : {cov['addr']:0.2f}%")
        print(f" Byte Strobe Coverage           : {cov['strb']:0.2f}%")
        print(f" Protocol Response Coverage     : {cov['resp']:0.2f}%")
        print(f" Inter-Packet Idle Latency Cov  : {cov['idle']:0.2f}%")
        print(f" Cross Coverage (Type x Strobe) : {cov['cross_strb']:0.2f}%")
        print(f" Cross Coverage (Type x Addr)   : {cov['cross_addr']:0.2f}%")
        print("===============================================================================\n")

# -----------------------------------------------------------------------------
# 5. Scoreboard & Golden Reference Model
# -----------------------------------------------------------------------------
class ApbScoreboard:
    def __init__(self, base_addr=0x00000000, max_addr=0x00000FFF):
        self.base_addr = base_addr
        self.max_addr = max_addr
        self.ref_mem = {} # byte address -> byte value
        self.total_trans_cnt = 0
        self.write_cnt = 0
        self.read_cnt = 0
        self.match_cnt = 0
        self.mismatch_cnt = 0
        self.expected_err_cnt = 0
        self.unexpected_err_cnt = 0

    def check(self, trans_type, addr, wdata, strb, rdata, resp, is_err_expected=False):
        self.total_trans_cnt += 1
        is_in_range = (self.base_addr <= addr <= self.max_addr)
        is_aligned = (addr % 4 == 0)
        is_valid = is_in_range and is_aligned

        if not is_valid:
            if resp == "ERROR":
                self.expected_err_cnt += 1
                self.match_cnt += 1
            else:
                self.unexpected_err_cnt += 1
                self.mismatch_cnt += 1
                print(f"[SCOREBOARD FAIL] PSLVERR not asserted for invalid access at Addr: 0x{addr:08X}")
            return

        if trans_type == "WRITE":
            self.write_cnt += 1
            if resp != "OKAY":
                self.unexpected_err_cnt += 1
                self.mismatch_cnt += 1
                print(f"[SCOREBOARD FAIL] Unexpected PSLVERR on valid WRITE to Addr: 0x{addr:08X}")
            else:
                self.match_cnt += 1
                for b in range(4):
                    if (strb >> b) & 1:
                        self.ref_mem[addr + b] = (wdata >> (b * 8)) & 0xFF
        else: # READ
            self.read_cnt += 1
            if resp != "OKAY":
                self.unexpected_err_cnt += 1
                self.mismatch_cnt += 1
                print(f"[SCOREBOARD FAIL] Unexpected PSLVERR on valid READ from Addr: 0x{addr:08X}")
                return

            exp_rdata = 0
            for b in range(4):
                val = self.ref_mem.get(addr + b, 0x00)
                exp_rdata |= (val << (b * 8))

            if rdata == exp_rdata:
                self.match_cnt += 1
            else:
                self.mismatch_cnt += 1
                print(f"[SCOREBOARD MISMATCH] Addr: 0x{addr:08X} | Expected: 0x{exp_rdata:08X} | Actual: 0x{rdata:08X}")

    def print_report(self):
        print("\n===============================================================================")
        print("                          VERIFICATION SCOREBOARD REPORT                       ")
        print("===============================================================================")
        print(f" Total Transactions Processed : {self.total_trans_cnt}")
        print(f" Total Writes Verified        : {self.write_cnt}")
        print(f" Total Reads Verified         : {self.read_cnt}")
        print(f" Total Matches (PASS)         : {self.match_cnt}")
        print(f" Total Mismatches (FAIL)      : {self.mismatch_cnt}")
        print(f" Expected Protocol Errors     : {self.expected_err_cnt}")
        print(f" Unexpected Errors            : {self.unexpected_err_cnt}")
        print("-------------------------------------------------------------------------------")
        if self.mismatch_cnt == 0 and self.total_trans_cnt > 0:
            print("                    >>> TEST STATUS: PASSED (ALL CHECKS OK) <<<                ")
        else:
            print(f"                    >>> TEST STATUS: FAILED ({self.mismatch_cnt} ERRORS) <<<                   ")
        print("===============================================================================\n")

# -----------------------------------------------------------------------------
# 6. Test Runner
# -----------------------------------------------------------------------------
def run_testcase(test_name, seed=1, dump_vcd=True, wait_cycles=0, cumulative_cov=None):
    random.seed(seed)
    rtl = ApbSlaveRamRtl(addr_width=32, data_width=32, mem_depth=1024, base_addr=0x00000000, wait_cycles=wait_cycles)
    sva = ApbSvaChecker()
    cov = ApbCoverageCollector(base_addr=0x00000000, max_addr=0x00000FFF)
    sb = ApbScoreboard(base_addr=0x00000000, max_addr=0x00000FFF)

    vcd = None
    if dump_vcd:
        vcd = VcdDumper("waveform.vcd")
        vcd.register_var("PCLK", 1)
        vcd.register_var("PRESETn", 1)
        vcd.register_var("PSEL", 1)
        vcd.register_var("PENABLE", 1)
        vcd.register_var("PWRITE", 1)
        vcd.register_var("PADDR", 32)
        vcd.register_var("PWDATA", 32)
        vcd.register_var("PSTRB", 4)
        vcd.register_var("PPROT", 3)
        vcd.register_var("PREADY", 1)
        vcd.register_var("PRDATA", 32)
        vcd.register_var("PSLVERR", 1)
        vcd.write_header()

    time_ns = 0

    def clock_cycle(presetn, psel, penable, pwrite, paddr, pwdata, pstrb, pprot):
        nonlocal time_ns
        pready, prdata, pslverr = rtl.step(presetn, psel, penable, pwrite, paddr, pwdata, pstrb, pprot)
        if vcd:
            vcd.dump(time_ns, {
                "PCLK": 0, "PRESETn": presetn, "PSEL": psel, "PENABLE": penable,
                "PWRITE": pwrite, "PADDR": paddr, "PWDATA": pwdata, "PSTRB": pstrb,
                "PPROT": pprot, "PREADY": pready, "PRDATA": prdata, "PSLVERR": pslverr
            })
        time_ns += 5

        sva.check(time_ns, presetn, psel, penable, pwrite, paddr, pwdata, pstrb, pprot, pready, prdata, pslverr)
        if vcd:
            vcd.dump(time_ns, {
                "PCLK": 1, "PRESETn": presetn, "PSEL": psel, "PENABLE": penable,
                "PWRITE": pwrite, "PADDR": paddr, "PWDATA": pwdata, "PSTRB": pstrb,
                "PPROT": pprot, "PREADY": pready, "PRDATA": prdata, "PSLVERR": pslverr
            })
        time_ns += 5
        return pready, prdata, pslverr

    # Reset
    for _ in range(3):
        clock_cycle(presetn=0, psel=0, penable=0, pwrite=0, paddr=0, pwdata=0, pstrb=0, pprot=0)
    clock_cycle(presetn=1, psel=0, penable=0, pwrite=0, paddr=0, pwdata=0, pstrb=0, pprot=0)

    def drive_apb_transfer(trans_type, addr, data, strb=0xF, idle=0, is_err_expected=False):
        for _ in range(idle):
            clock_cycle(presetn=1, psel=0, penable=0, pwrite=0, paddr=0, pwdata=0, pstrb=0, pprot=0)

        pwrite_bit = 1 if trans_type == "WRITE" else 0

        # SETUP
        pready, prdata, pslverr = clock_cycle(presetn=1, psel=1, penable=0, pwrite=pwrite_bit,
                                              paddr=addr, pwdata=data, pstrb=strb, pprot=0)

        # ACCESS
        while True:
            pready, prdata, pslverr = clock_cycle(presetn=1, psel=1, penable=1, pwrite=pwrite_bit,
                                                  paddr=addr, pwdata=data, pstrb=strb, pprot=0)
            if pready == 1:
                break

        resp_str = "ERROR" if pslverr == 1 else "OKAY"
        sb.check(trans_type, addr, data, strb, prdata, resp_str, is_err_expected)
        cov.sample(trans_type, addr, strb, resp_str, idle)
        if cumulative_cov:
            cumulative_cov.sample(trans_type, addr, strb, resp_str, idle)

        clock_cycle(presetn=1, psel=0, penable=0, pwrite=0, paddr=0, pwdata=0, pstrb=0, pprot=0)

    print(f"\n===============================================================================")
    print(f" [TB_TOP] Executing Test: {test_name}")
    print(f"===============================================================================")

    if test_name == "test_base":
        drive_apb_transfer("WRITE", 0x00000000, 0x12345678, 0xF, idle=1)
        drive_apb_transfer("READ",  0x00000000, 0x00000000, 0xF, idle=0)
        drive_apb_transfer("WRITE", 0x00000004, 0x9ABCDEF0, 0xF, idle=2)
        drive_apb_transfer("READ",  0x00000004, 0x00000000, 0xF, idle=0)

    elif test_name == "test_random":
        for _ in range(1000):
            t_type = "WRITE" if random.random() < 0.5 else "READ"
            word_idx = random.randint(0, 1023)
            addr = word_idx * 4
            wdata = random.randint(0, 0xFFFFFFFF)
            strb = random.choice([0x1, 0x2, 0x4, 0x8, 0x3, 0xC, 0xF, 0x5, 0xA, 0x7, 0xE])
            idle = random.choices([0, 1, 2, 3], weights=[50, 30, 15, 5])[0]
            drive_apb_transfer(t_type, addr, wdata, strb, idle)

    elif test_name == "test_byte_strobe":
        target_addr = 0x00000040
        for b in range(4):
            drive_apb_transfer("WRITE", target_addr, (0x11223344 << (b*8)) | 0xA0A0A0A0, (1 << b), idle=0)
            drive_apb_transfer("READ",  target_addr, 0, 0xF, idle=0)

        strb_patterns = [0x3, 0xC, 0x6, 0x9, 0xF, 0x5, 0x1, 0x2, 0x4, 0x8]
        for i in range(50):
            a = i * 4
            st = strb_patterns[i % len(strb_patterns)]
            d = random.randint(0, 0xFFFFFFFF)
            drive_apb_transfer("WRITE", a, d, st, idle=random.randint(0, 2))
            drive_apb_transfer("READ",  a, 0, 0xF, idle=0)

    elif test_name == "test_error_handling":
        oob_addrs = [0x00001004, 0x00010000, 0x10000000, 0xFFFFFFF0]
        for a in oob_addrs:
            drive_apb_transfer("WRITE", a, 0xDEADBEEF, 0xF, idle=0, is_err_expected=True)
            drive_apb_transfer("READ",  a, 0, 0xF, idle=0, is_err_expected=True)

        for offset in [1, 2, 3]:
            drive_apb_transfer("WRITE", 0x00000010 + offset, 0xCAFEBABE, 0xF, idle=0, is_err_expected=True)
            drive_apb_transfer("READ",  0x00000010 + offset, 0xCAFEBABE, 0xF, idle=0, is_err_expected=True)

        for i in range(5):
            drive_apb_transfer("WRITE", i * 4, 0x55AA55AA + i, 0xF, idle=0)
            drive_apb_transfer("READ",  i * 4, 0, 0xF, idle=0)

    elif test_name == "test_b2b_stress":
        # Min and Max Boundary Address transfers
        drive_apb_transfer("WRITE", 0x00000000, 0xAAAA5555, 0xF, idle=0)
        drive_apb_transfer("READ",  0x00000000, 0, 0xF, idle=0)
        drive_apb_transfer("WRITE", 0x00000FFC, 0x5555AAAA, 0xF, idle=0)
        drive_apb_transfer("READ",  0x00000FFC, 0, 0xF, idle=0)

        for i in range(100):
            drive_apb_transfer("WRITE", i * 4, 0xA0000000 | i, 0xF, idle=0)
        for i in range(100):
            drive_apb_transfer("READ", i * 4, 0, 0xF, idle=0)
        for i in range(50):
            d = random.randint(0, 0xFFFFFFFF)
            drive_apb_transfer("WRITE", i * 4, d, 0xF, idle=0)
            drive_apb_transfer("READ",  i * 4, 0, 0xF, idle=0)

    elif test_name == "test_wait_states":
        for i in range(100):
            t_type = "WRITE" if i % 2 == 0 else "READ"
            drive_apb_transfer(t_type, (i % 256) * 4, random.randint(0, 0xFFFFFFFF), 0xF, idle=random.randint(0, 3))

    if vcd:
        vcd.close()

    sb.print_report()
    cov.print_report()

    status = "PASSED" if (sb.mismatch_cnt == 0 and sva.assertion_violations == 0) else "FAILED"
    cov_val = cov.calculate_coverage()["overall"]
    return {
        "name": test_name,
        "status": status,
        "trans": sb.total_trans_cnt,
        "coverage": f"{cov_val:0.2f}%",
        "violations": sva.assertion_violations
    }

def main():
    parser = argparse.ArgumentParser(description="Cycle-Accurate APB RAM Simulation Runner")
    parser.add_argument("--test", default="all", choices=["all", "test_base", "test_random", "test_byte_strobe", "test_error_handling", "test_b2b_stress", "test_wait_states"])
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--wait", type=int, default=0, help="Configure wait states")
    args = parser.parse_args()

    os.makedirs("logs", exist_ok=True)
    tests = ["test_base", "test_random", "test_byte_strobe", "test_error_handling", "test_b2b_stress", "test_wait_states"] if args.test == "all" else [args.test]

    print("\n" + "="*80)
    print("      AMBA APB RAM CONTROLLER CYCLE-ACCURATE REGRESSION SUITE")
    print("="*80)

    cumulative_cov = ApbCoverageCollector(base_addr=0x00000000, max_addr=0x00000FFF)
    results = []
    t_total_start = time.time()

    for t in tests:
        t_start = time.time()
        res = run_testcase(t, seed=args.seed, dump_vcd=(t == tests[-1] or len(tests) == 1), wait_cycles=args.wait, cumulative_cov=cumulative_cov)
        elapsed = time.time() - t_start
        res["time"] = f"{elapsed:0.3f}s"
        results.append(res)

    t_total_elapsed = time.time() - t_total_start

    print("\n" + "="*80)
    print("                      CUMULATIVE REGRESSION COVERAGE REPORT                   ")
    print("="*80)
    cumulative_cov.print_report()

    print("\n" + "="*80)
    print("                             REGRESSION SUMMARY REPORT                         ")
    print("="*80)
    print(f"{'Testcase Name':<25} | {'Status':<10} | {'Trans Count':<12} | {'Per-Test Cov':<12} | {'Time':<8}")
    print("-" * 80)

    passed = 0
    for r in results:
        if r['status'] == "PASSED":
            passed += 1
            status_disp = "\033[92mPASSED\033[0m"
        else:
            status_disp = "\033[91mFAILED\033[0m"
        print(f"{r['name']:<25} | {status_disp:<19} | {r['trans']:<12} | {r['coverage']:<12} | {r['time']:<8}")

    print("-" * 80)
    print(f" Total Executed: {len(results)} | Passed: {passed} | Failed: {len(results) - passed} | Elapsed: {t_total_elapsed:0.2f}s")
    print(f" Cumulative Functional & Cross Coverage: {cumulative_cov.calculate_coverage()['overall']:0.2f}%")
    print(f" SystemVerilog Assertions (SVA) Violations: {sum(r['violations'] for r in results)}")
    print(f" Waveform File Generated: waveform.vcd ({os.path.getsize('waveform.vcd')} bytes)")
    print("="*80 + "\n")

if __name__ == "__main__":
    main()
