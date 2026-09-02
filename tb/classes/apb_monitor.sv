// =============================================================================
// File: apb_monitor.sv
// Description: Passive APB4 Protocol Monitor & Packet Broadcaster
// Author: Antigravity DV Team
// =============================================================================

`ifndef APB_MONITOR_SV
`define APB_MONITOR_SV

import apb_pkg::*;
`include "tb/classes/apb_transaction.sv"

class apb_monitor;

    // Virtual Interface with monitor clocking block
    virtual apb_if.MON vif;
    mailbox #(apb_transaction) mon2sb_mbx;
    mailbox #(apb_transaction) mon2cov_mbx;

    function new(
        virtual apb_if.MON vif,
        mailbox #(apb_transaction) mon2sb_mbx,
        mailbox #(apb_transaction) mon2cov_mbx
    );
        this.vif         = vif;
        this.mon2sb_mbx  = mon2sb_mbx;
        this.mon2cov_mbx = mon2cov_mbx;
    endfunction

    // Continuous passive bus monitoring
    virtual task run();
        apb_transaction tr;
        apb_log(LOG_INFO, "MONITOR", "Passive APB Monitor started.");

        forever begin
            @(vif.cb_mon);
            // Detect valid handshake when PSEL, PENABLE, and PREADY are all asserted
            if (vif.cb_mon.PSEL === 1'b1 &&
                vif.cb_mon.PENABLE === 1'b1 &&
                vif.cb_mon.PREADY === 1'b1 &&
                vif.cb_mon.PRESETn === 1'b1) begin

                tr = new();
                tr.addr       = vif.cb_mon.PADDR;
                tr.trans_type = (vif.cb_mon.PWRITE === 1'b1) ? APB_WRITE : APB_READ;
                tr.data       = vif.cb_mon.PWDATA;
                tr.strb       = vif.cb_mon.PSTRB;
                tr.prot       = vif.cb_mon.PPROT;
                tr.rdata      = vif.cb_mon.PRDATA;
                tr.resp       = (vif.cb_mon.PSLVERR === 1'b1) ? APB_ERROR : APB_OKAY;

                // Broadcast to Scoreboard and Functional Coverage
                if (mon2sb_mbx != null)  mon2sb_mbx.put(tr.clone());
                if (mon2cov_mbx != null) mon2cov_mbx.put(tr.clone());
            end
        end
    endtask

endclass : apb_monitor

`endif // APB_MONITOR_SV
