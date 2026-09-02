// =============================================================================
// File: test_b2b_stress.sv
// Description: Zero-Wait-State Back-to-Back Read/Write Burst Collision Stress Test
// Author: Antigravity DV Team
// =============================================================================

`ifndef TEST_B2B_STRESS_SV
`define TEST_B2B_STRESS_SV

`include "tb/classes/apb_env.sv"

class apb_b2b_generator extends apb_generator;

    function new(mailbox #(apb_transaction) gen2drv_mbx, event drv_done_event);
        super.new(gen2drv_mbx, drv_done_event);
    endfunction

    virtual task run();
        apb_transaction tr;
        apb_transaction tr_w;
        apb_transaction tr_r;

        apb_log(LOG_INFO, "B2B_GEN", "Executing Zero-Delay Back-to-Back Burst sequences...");

        // ---------------------------------------------------------------------
        // Phase 1: 100 Consecutive Back-to-Back WRITES (Zero idle cycles)
        // ---------------------------------------------------------------------
        for (int i = 0; i < 100; i++) begin
            tr            = new();
            tr.addr        = APB_BASE_ADDR + (i * 4);
            tr.trans_type  = APB_WRITE;
            tr.data        = 32'hA000_0000 | i;
            tr.strb        = 4'b1111;
            tr.idle_cycles = 0;
            gen2drv_mbx.put(tr);
            @(drv_done_event);
        end

        // ---------------------------------------------------------------------
        // Phase 2: 100 Consecutive Back-to-Back READS (Zero idle cycles)
        // ---------------------------------------------------------------------
        for (int i = 0; i < 100; i++) begin
            tr            = new();
            tr.addr        = APB_BASE_ADDR + (i * 4);
            tr.trans_type  = APB_READ;
            tr.idle_cycles = 0;
            gen2drv_mbx.put(tr);
            @(drv_done_event);
        end

        // ---------------------------------------------------------------------
        // Phase 3: Alternating Back-to-Back Write-Read Collisions
        // ---------------------------------------------------------------------
        for (int i = 0; i < 50; i++) begin
            tr_w            = new();
            tr_r            = new();

            tr_w.addr        = APB_BASE_ADDR + (i * 4);
            tr_w.trans_type  = APB_WRITE;
            tr_w.data        = $urandom();
            tr_w.strb        = 4'b1111;
            tr_w.idle_cycles = 0;
            gen2drv_mbx.put(tr_w);
            @(drv_done_event);

            tr_r.addr        = tr_w.addr;
            tr_r.trans_type  = APB_READ;
            tr_r.idle_cycles = 0;
            gen2drv_mbx.put(tr_r);
            @(drv_done_event);
        end

        apb_log(LOG_INFO, "B2B_GEN", "Back-to-back stress sequence generation completed.");
        -> gen_done_event;
    endtask

endclass : apb_b2b_generator

class test_b2b_stress;

    apb_env env;
    virtual apb_if.DRV vif_drv;
    virtual apb_if.MON vif_mon;

    function new(virtual apb_if.DRV vif_drv, virtual apb_if.MON vif_mon);
        this.vif_drv = vif_drv;
        this.vif_mon = vif_mon;
        this.env     = new(vif_drv, vif_mon);
    endfunction

    virtual task run();
        apb_b2b_generator custom_gen;
        apb_log(LOG_INFO, "TEST_B2B", "========== Starting test_b2b_stress ==========");
        env.build();

        custom_gen = new(env.gen2drv_mbx, env.drv_done_event);
        env.gen    = custom_gen;

        env.run();
        env.report();
        apb_log(LOG_INFO, "TEST_B2B", "========== Finished test_b2b_stress ==========");
    endtask

endclass : test_b2b_stress

`endif // TEST_B2B_STRESS_SV
