// =============================================================================
// File: apb_env.sv
// Description: Top Verification Environment Layer
// Author: Antigravity DV Team
// =============================================================================

`ifndef APB_ENV_SV
`define APB_ENV_SV

import apb_pkg::*;
`include "tb/classes/apb_transaction.sv"
`include "tb/classes/apb_generator.sv"
`include "tb/classes/apb_driver.sv"
`include "tb/classes/apb_monitor.sv"
`include "tb/classes/apb_scoreboard.sv"
`include "tb/classes/apb_coverage.sv"

class apb_env;

    // Virtual Interface Connections
    virtual apb_if.DRV vif_drv;
    virtual apb_if.MON vif_mon;

    // Communication Channels & Events
    mailbox #(apb_transaction) gen2drv_mbx;
    mailbox #(apb_transaction) mon2sb_mbx;
    mailbox #(apb_transaction) mon2cov_mbx;
    event                      drv_done_event;

    // Sub-components
    apb_generator  gen;
    apb_driver     drv;
    apb_monitor    mon;
    apb_scoreboard sb;
    apb_coverage   cov;

    function new(virtual apb_if.DRV vif_drv, virtual apb_if.MON vif_mon);
        this.vif_drv = vif_drv;
        this.vif_mon = vif_mon;
    endfunction

    // -------------------------------------------------------------------------
    // Build Phase: Instantiate Mailboxes & Components
    // -------------------------------------------------------------------------
    virtual function void build();
        apb_log(LOG_INFO, "ENV", "Executing Environment Build Phase...");
        gen2drv_mbx = new();
        mon2sb_mbx  = new();
        mon2cov_mbx = new();

        gen = new(gen2drv_mbx, drv_done_event);
        drv = new(vif_drv, gen2drv_mbx, drv_done_event);
        mon = new(vif_mon, mon2sb_mbx, mon2cov_mbx);
        sb  = new(mon2sb_mbx);
        cov = new(mon2cov_mbx);
    endfunction

    // -------------------------------------------------------------------------
    // Run Phase: Start Concurrent Execution of All Verification Components
    // -------------------------------------------------------------------------
    virtual task run();
        apb_log(LOG_INFO, "ENV", "Executing Environment Run Phase...");

        fork
            drv.run();
            mon.run();
            sb.run();
            cov.run();
        join_none

        // Run generator to produce transactions
        gen.run();

        // Wait for pipeline to drain
        #100ns;
        wait (gen2drv_mbx.num() == 0);
        #200ns;
    endtask

    // -------------------------------------------------------------------------
    // Report Phase: Summarize Results & Coverage
    // -------------------------------------------------------------------------
    virtual function void report();
        apb_log(LOG_INFO, "ENV", "Executing Environment Report Phase...");
        sb.report();
        cov.report();
    endfunction

endclass : apb_env

`endif // APB_ENV_SV
