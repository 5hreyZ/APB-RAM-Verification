// =============================================================================
// File: test_error_handling.sv
// Description: Negative Testing & Protocol Error (PSLVERR) Verification Test
// Author: Antigravity DV Team
// =============================================================================

`ifndef TEST_ERROR_HANDLING_SV
`define TEST_ERROR_HANDLING_SV

`include "tb/classes/apb_env.sv"

class apb_error_generator extends apb_generator;

    function new(mailbox #(apb_transaction) gen2drv_mbx, event drv_done_event);
        super.new(gen2drv_mbx, drv_done_event);
    endfunction

    virtual task run();
        bit [31:0] out_of_bounds_addrs[4];
        apb_transaction tr_w;
        apb_transaction tr_r;
        apb_transaction tr;

        out_of_bounds_addrs[0] = APB_MAX_ADDR + 4;
        out_of_bounds_addrs[1] = 32'h0001_0000;
        out_of_bounds_addrs[2] = 32'h1000_0000;
        out_of_bounds_addrs[3] = 32'hFFFF_FFF0;

        apb_log(LOG_INFO, "ERR_GEN", "Executing Negative Testing & Error Injection sequences...");

        // ---------------------------------------------------------------------
        // Scenario 1: Out-of-bounds Write & Read injections
        // ---------------------------------------------------------------------
        for (int i = 0; i < 4; i++) begin
            // Out-of-bounds Write
            tr_w                 = new();
            tr_w.addr            = out_of_bounds_addrs[i];
            tr_w.trans_type      = APB_WRITE;
            tr_w.data            = 32'hDEAD_BEEF;
            tr_w.strb            = 4'b1111;
            tr_w.is_err_expected = 1'b1;
            gen2drv_mbx.put(tr_w);
            @(drv_done_event);

            // Out-of-bounds Read
            tr_r                 = new();
            tr_r.addr            = out_of_bounds_addrs[i];
            tr_r.trans_type      = APB_READ;
            tr_r.is_err_expected = 1'b1;
            gen2drv_mbx.put(tr_r);
            @(drv_done_event);
        end

        // ---------------------------------------------------------------------
        // Scenario 2: Unaligned Address Injections (non-4-byte aligned)
        // ---------------------------------------------------------------------
        for (int offset = 1; offset <= 3; offset++) begin
            tr                 = new();
            tr.addr            = APB_BASE_ADDR + offset;
            tr.trans_type      = APB_WRITE;
            tr.data            = 32'hCAFE_BABE;
            tr.strb            = 4'b1111;
            tr.is_err_expected = 1'b1;
            gen2drv_mbx.put(tr);
            @(drv_done_event);
        end

        // ---------------------------------------------------------------------
        // Scenario 3: Valid Access Recovery after Error (Sanity verification)
        // ---------------------------------------------------------------------
        for (int i = 0; i < 5; i++) begin
            tr                 = new();
            tr.addr            = APB_BASE_ADDR + (i * 4);
            tr.trans_type      = APB_WRITE;
            tr.data            = 32'h55AA_55AA + i;
            tr.strb            = 4'b1111;
            tr.is_err_expected = 1'b0;
            gen2drv_mbx.put(tr);
            @(drv_done_event);

            tr                 = new();
            tr.addr            = APB_BASE_ADDR + (i * 4);
            tr.trans_type      = APB_READ;
            tr.is_err_expected = 1'b0;
            gen2drv_mbx.put(tr);
            @(drv_done_event);
        end

        apb_log(LOG_INFO, "ERR_GEN", "Negative testing sequence generation completed.");
        -> gen_done_event;
    endtask

endclass : apb_error_generator

class test_error_handling;

    apb_env env;
    virtual apb_if.DRV vif_drv;
    virtual apb_if.MON vif_mon;

    function new(virtual apb_if.DRV vif_drv, virtual apb_if.MON vif_mon);
        this.vif_drv = vif_drv;
        this.vif_mon = vif_mon;
        this.env     = new(vif_drv, vif_mon);
    endfunction

    virtual task run();
        apb_error_generator custom_gen;
        apb_log(LOG_INFO, "TEST_ERROR", "========== Starting test_error_handling ==========");
        env.build();

        custom_gen = new(env.gen2drv_mbx, env.drv_done_event);
        env.gen    = custom_gen;

        env.run();
        env.report();
        apb_log(LOG_INFO, "TEST_ERROR", "========== Finished test_error_handling ==========");
    endtask

endclass : test_error_handling

`endif // TEST_ERROR_HANDLING_SV
