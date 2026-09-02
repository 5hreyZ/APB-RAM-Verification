// =============================================================================
// File: apb_coverage.sv
// Description: Functional Coverage Collector with Covergroups & Cross Coverage
// Author: Antigravity DV Team
// =============================================================================

`ifndef APB_COVERAGE_SV
`define APB_COVERAGE_SV

import apb_pkg::*;
`include "tb/classes/apb_transaction.sv"

class apb_coverage;

    mailbox #(apb_transaction) mon2cov_mbx;
    apb_transaction tr_sampled;

    // -------------------------------------------------------------------------
    // Functional Covergroup Definition
    // -------------------------------------------------------------------------
    covergroup cg_apb;
        option.per_instance = 1;
        option.comment      = "AMBA APB4 Protocol & Functional Coverage";

        // Operation Direction (Read / Write)
        cp_type: coverpoint tr_sampled.trans_type {
            bins write = {APB_WRITE};
            bins read  = {APB_READ};
        }

        // Memory Address Space & Boundary Coverage
        cp_addr: coverpoint tr_sampled.addr {
            bins min_addr       = {APB_BASE_ADDR};
            bins max_addr       = {APB_MAX_ADDR - 3};
            bins low_range      = {[APB_BASE_ADDR : APB_BASE_ADDR + 32'h0000_03FC]};
            bins mid_range      = {[APB_BASE_ADDR + 32'h0000_0400 : APB_BASE_ADDR + 32'h0000_0BFC]};
            bins high_range     = {[APB_BASE_ADDR + 32'h0000_0C00 : APB_MAX_ADDR]};
            bins out_of_bounds  = {[APB_MAX_ADDR + 1 : 32'hFFFF_FFFF]};
        }

        // Byte Strobe (Masking) Combinations
        cp_strb: coverpoint tr_sampled.strb {
            bins single_byte_0 = {4'b0001};
            bins single_byte_1 = {4'b0010};
            bins single_byte_2 = {4'b0100};
            bins single_byte_3 = {4'b1000};
            bins lower_half    = {4'b0011};
            bins upper_half    = {4'b1100};
            bins full_word     = {4'b1111};
            bins other_combos  = default;
        }

        // Transfer Response (OKAY / PSLVERR)
        cp_resp: coverpoint tr_sampled.resp {
            bins okay_resp  = {APB_OKAY};
            bins error_resp = {APB_ERROR};
        }

        // Inter-transaction Idle Cycle Latency
        cp_idle: coverpoint tr_sampled.idle_cycles {
            bins back_to_back = {0};
            bins delay_1      = {1};
            bins delay_2      = {2};
            bins delay_multi  = {[3:10]};
        }

        // Cross Coverage Matrix
        cross_type_x_strb: cross cp_type, cp_strb;
        cross_type_x_addr: cross cp_type, cp_addr;
        cross_type_x_resp: cross cp_type, cp_resp;
    endgroup

    function new(mailbox #(apb_transaction) mon2cov_mbx);
        this.mon2cov_mbx = mon2cov_mbx;
        this.cg_apb      = new();
    endfunction

    // Continuous Coverage Sampling Loop
    virtual task run();
        apb_log(LOG_INFO, "COVERAGE", "Coverage collector initialized.");

        forever begin
            mon2cov_mbx.get(tr_sampled);
            cg_apb.sample();
        end
    endtask

    // Display Coverage Report
    virtual function void report();
        real total_cov = cg_apb.get_coverage();
        $display("\n===============================================================================");
        $display("                          FUNCTIONAL COVERAGE REPORT                           ");
        $display("===============================================================================");
        $display(" Overall Coverage Achieved     : %0.2f%%", total_cov);
        $display(" Type Coverpoint Coverage       : %0.2f%%", cg_apb.cp_type.get_coverage());
        $display(" Address Space Coverage         : %0.2f%%", cg_apb.cp_addr.get_coverage());
        $display(" Byte Strobe Coverage           : %0.2f%%", cg_apb.cp_strb.get_coverage());
        $display(" Protocol Response Coverage     : %0.2f%%", cg_apb.cp_resp.get_coverage());
        $display(" Cross Coverage (Type x Strobe) : %0.2f%%", cg_apb.cross_type_x_strb.get_coverage());
        $display(" Cross Coverage (Type x Addr)   : %0.2f%%", cg_apb.cross_type_x_addr.get_coverage());
        $display("===============================================================================\n");
    endfunction

endclass : apb_coverage

`endif // APB_COVERAGE_SV
