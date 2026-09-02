// =============================================================================
// File: apb_scoreboard.sv
// Description: Reference Model & Data Integrity Scoreboard with Byte Masking
// Author: Antigravity DV Team
// =============================================================================

`ifndef APB_SCOREBOARD_SV
`define APB_SCOREBOARD_SV

import apb_pkg::*;
`include "tb/classes/apb_transaction.sv"

class apb_scoreboard;

    // Mailbox handle from Monitor
    mailbox #(apb_transaction) mon2sb_mbx;

    // Golden Reference Memory (Byte-Addressable Associative Array)
    bit [7:0] ref_mem [int unsigned];

    // Verification Statistics
    int unsigned total_trans_cnt;
    int unsigned write_cnt;
    int unsigned read_cnt;
    int unsigned match_cnt;
    int unsigned mismatch_cnt;
    int unsigned expected_err_cnt;
    int unsigned unexpected_err_cnt;

    function new(mailbox #(apb_transaction) mon2sb_mbx);
        this.mon2sb_mbx         = mon2sb_mbx;
        this.total_trans_cnt    = 0;
        this.write_cnt          = 0;
        this.read_cnt           = 0;
        this.match_cnt          = 0;
        this.mismatch_cnt       = 0;
        this.expected_err_cnt   = 0;
        this.unexpected_err_cnt = 0;
    endfunction

    // Main Scoreboard checking loop
    virtual task run();
        apb_log(LOG_INFO, "SCOREBOARD", "Scoreboard active and waiting for transactions.");

        forever begin
            apb_transaction tr;
            mon2sb_mbx.get(tr);
            total_trans_cnt++;

            check_transaction(tr);
        end
    endtask

    // Check individual transaction against reference model
    virtual function void check_transaction(apb_transaction tr);
        bit is_in_range;
        bit is_aligned;
        bit is_valid;
        bit [31:0] exp_rdata;

        is_in_range = (tr.addr >= APB_BASE_ADDR) && (tr.addr <= APB_MAX_ADDR);
        is_aligned  = (tr.addr[1:0] == 2'b00);
        is_valid    = is_in_range && is_aligned;
        exp_rdata   = 32'h0;

        // ---------------------------------------------------------------------
        // Case 1: Out-of-bounds or Unaligned Error Injection
        // ---------------------------------------------------------------------
        if (!is_valid) begin
            if (tr.resp == APB_ERROR) begin
                expected_err_cnt++;
                match_cnt++;
                apb_log(LOG_INFO, "SCOREBOARD", $sformatf("[PASS] Correct PSLVERR asserted for invalid access at Addr: 0x%08h (In-range:%0b, Aligned:%0b)",
                                                          tr.addr, is_in_range, is_aligned));
            end else begin
                unexpected_err_cnt++;
                mismatch_cnt++;
                apb_log(LOG_ERROR, "SCOREBOARD", $sformatf("[FAIL] PSLVERR not asserted for invalid access! Addr: 0x%08h", tr.addr));
            end
            return;
        end

        // ---------------------------------------------------------------------
        // Case 2: Valid APB WRITE Transaction (Apply Byte Masking to Ref Memory)
        // ---------------------------------------------------------------------
        if (tr.trans_type == APB_WRITE) begin
            write_cnt++;
            if (tr.resp != APB_OKAY) begin
                unexpected_err_cnt++;
                mismatch_cnt++;
                apb_log(LOG_ERROR, "SCOREBOARD", $sformatf("[FAIL] Unexpected PSLVERR on valid WRITE to Addr: 0x%08h", tr.addr));
            end else begin
                match_cnt++;
                // Apply byte strobes to golden memory
                for (int b = 0; b < 4; b++) begin
                    if (tr.strb[b]) begin
                        ref_mem[tr.addr + b] = tr.data[(b*8) +: 8];
                    end
                end
            end
        end

        // ---------------------------------------------------------------------
        // Case 3: Valid APB READ Transaction (Compare DUT PRDATA with Ref Model)
        // ---------------------------------------------------------------------
        else if (tr.trans_type == APB_READ) begin
            read_cnt++;

            if (tr.resp != APB_OKAY) begin
                unexpected_err_cnt++;
                mismatch_cnt++;
                apb_log(LOG_ERROR, "SCOREBOARD", $sformatf("[FAIL] Unexpected PSLVERR on valid READ from Addr: 0x%08h", tr.addr));
                return;
            end

            // Construct expected 32-bit data from byte reference model
            for (int b = 0; b < 4; b++) begin
                if (ref_mem.exists(tr.addr + b)) begin
                    exp_rdata[(b*8) +: 8] = ref_mem[tr.addr + b];
                end else begin
                    exp_rdata[(b*8) +: 8] = 8'h00; // Default uninitialized memory
                end
            end

            if (tr.rdata === exp_rdata) begin
                match_cnt++;
            end else begin
                mismatch_cnt++;
                apb_log(LOG_ERROR, "SCOREBOARD",
                        $sformatf("[FAIL DATA MISMATCH] Addr: 0x%08h | Expected: 0x%08h | Actual: 0x%08h",
                                  tr.addr, exp_rdata, tr.rdata));
            end
        end
    endfunction

    // Formatted verification summary report
    virtual function void report();
        $display("\n===============================================================================");
        $display("                          VERIFICATION SCOREBOARD REPORT                       ");
        $display("===============================================================================");
        $display(" Total Transactions Processed : %0d", total_trans_cnt);
        $display(" Total Writes Verified        : %0d", write_cnt);
        $display(" Total Reads Verified         : %0d", read_cnt);
        $display(" Total Matches (PASS)         : %0d", match_cnt);
        $display(" Total Mismatches (FAIL)      : %0d", mismatch_cnt);
        $display(" Expected Protocol Errors     : %0d", expected_err_cnt);
        $display(" Unexpected Errors            : %0d", unexpected_err_cnt);
        $display("-------------------------------------------------------------------------------");
        if (mismatch_cnt == 0 && total_trans_cnt > 0) begin
            $display("                    >>> TEST STATUS: PASSED (ALL CHECKS OK) <<<                ");
        end else begin
            $display("                    >>> TEST STATUS: FAILED (%0d ERRORS) <<<                   ", mismatch_cnt);
        end
        $display("===============================================================================\n");
    endfunction

endclass : apb_scoreboard

`endif // APB_SCOREBOARD_SV
