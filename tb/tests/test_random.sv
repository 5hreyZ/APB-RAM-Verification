// =============================================================================
// File: test_random.sv
// Description: Large-Scale Constrained-Random Verification (CRV) Stress Test
// Author: Antigravity DV Team
// =============================================================================

`ifndef TEST_RANDOM_SV
`define TEST_RANDOM_SV

`include "tb/classes/apb_env.sv"

class test_random;

    apb_env env;
    virtual apb_if.DRV vif_drv;
    virtual apb_if.MON vif_mon;

    function new(virtual apb_if.DRV vif_drv, virtual apb_if.MON vif_mon);
        this.vif_drv = vif_drv;
        this.vif_mon = vif_mon;
        this.env     = new(vif_drv, vif_mon);
    endfunction

    virtual task run();
        apb_log(LOG_INFO, "TEST_RANDOM", "========== Starting test_random (1000+ CRV Stress Test) ==========");
        env.build();
        env.gen.trans_count = 1000;
        env.run();
        env.report();
        apb_log(LOG_INFO, "TEST_RANDOM", "========== Finished test_random ==========");
    endtask

endclass : test_random

`endif // TEST_RANDOM_SV
