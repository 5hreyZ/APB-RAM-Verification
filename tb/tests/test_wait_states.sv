// =============================================================================
// File: test_wait_states.sv
// Description: Multi-Cycle Handshake & Wait-State Response Verification Test
// Author: Antigravity DV Team
// =============================================================================

`ifndef TEST_WAIT_STATES_SV
`define TEST_WAIT_STATES_SV

`include "tb/classes/apb_env.sv"

class test_wait_states;

    apb_env env;
    virtual apb_if.DRV vif_drv;
    virtual apb_if.MON vif_mon;

    function new(virtual apb_if.DRV vif_drv, virtual apb_if.MON vif_mon);
        this.vif_drv = vif_drv;
        this.vif_mon = vif_mon;
        this.env     = new(vif_drv, vif_mon);
    endfunction

    virtual task run();
        apb_log(LOG_INFO, "TEST_WAIT", "========== Starting test_wait_states ==========");
        env.build();
        env.gen.trans_count = 100;
        env.run();
        env.report();
        apb_log(LOG_INFO, "TEST_WAIT", "========== Finished test_wait_states ==========");
    endtask

endclass : test_wait_states

`endif // TEST_WAIT_STATES_SV
