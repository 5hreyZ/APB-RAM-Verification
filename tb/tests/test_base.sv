// =============================================================================
// File: test_base.sv
// Description: Base Verification Test & Sanity Smoke Test
// Author: Antigravity DV Team
// =============================================================================

`ifndef TEST_BASE_SV
`define TEST_BASE_SV

`include "tb/classes/apb_env.sv"

class test_base;

    apb_env env;
    virtual apb_if.DRV vif_drv;
    virtual apb_if.MON vif_mon;

    function new(virtual apb_if.DRV vif_drv, virtual apb_if.MON vif_mon);
        this.vif_drv = vif_drv;
        this.vif_mon = vif_mon;
        this.env     = new(vif_drv, vif_mon);
    endfunction

    virtual task run();
        apb_log(LOG_INFO, "TEST_BASE", "========== Starting test_base (Smoke Sanity Test) ==========");
        env.build();
        env.gen.trans_count = 30;
        env.run();
        env.report();
        apb_log(LOG_INFO, "TEST_BASE", "========== Finished test_base ==========");
    endtask

endclass : test_base

`endif // TEST_BASE_SV
