// =============================================================================
// File: apb_driver.sv
// Description: APB Bus Master Driver adhering to 2-phase protocol timings
// Author: Antigravity DV Team
// =============================================================================

`ifndef APB_DRIVER_SV
`define APB_DRIVER_SV

import apb_pkg::*;
`include "tb/classes/apb_transaction.sv"

class apb_driver;

    // Virtual Interface with driver clocking block
    virtual apb_if.DRV vif;
    mailbox #(apb_transaction) gen2drv_mbx;
    event drv_done_event;

    function new(virtual apb_if.DRV vif, mailbox #(apb_transaction) gen2drv_mbx, event drv_done_event);
        this.vif            = vif;
        this.gen2drv_mbx    = gen2drv_mbx;
        this.drv_done_event = drv_done_event;
    endfunction

    // Reset control signals to default quiescent state
    task reset_signals();
        @(vif.cb_drv);
        vif.cb_drv.PSEL    <= 1'b0;
        vif.cb_drv.PENABLE <= 1'b0;
        vif.cb_drv.PWRITE  <= 1'b0;
        vif.cb_drv.PADDR   <= '0;
        vif.cb_drv.PWDATA  <= '0;
        vif.cb_drv.PSTRB   <= 4'b0000;
        vif.cb_drv.PPROT   <= 3'b000;
        apb_log(LOG_INFO, "DRIVER", "Driver signals initialized to default state.");
    endtask

    // Main driver execution loop
    virtual task run();
        apb_transaction tr;
        reset_signals();

        // Wait for reset deassertion
        while (vif.cb_drv.PRESETn !== 1'b1) begin
            @(vif.cb_drv);
        end
        apb_log(LOG_INFO, "DRIVER", "Reset deasserted. Driver active.");

        forever begin
            gen2drv_mbx.get(tr);
            drive_transfer(tr);
        end
    endtask

    // Drive standard AMBA APB4 transfer
    virtual task drive_transfer(apb_transaction tr);
        // Inject configured idle wait states before transfer
        if (tr.idle_cycles > 0) begin
            vif.cb_drv.PSEL    <= 1'b0;
            vif.cb_drv.PENABLE <= 1'b0;
            repeat (tr.idle_cycles) @(vif.cb_drv);
        end

        // ---------------------------------------------------------------------
        // Phase 1: SETUP Phase (PSEL=1, PENABLE=0, drive address & control)
        // ---------------------------------------------------------------------
        @(vif.cb_drv);
        vif.cb_drv.PADDR   <= tr.addr;
        vif.cb_drv.PWRITE  <= (tr.trans_type == APB_WRITE);
        vif.cb_drv.PWDATA  <= tr.data;
        vif.cb_drv.PSTRB   <= tr.strb;
        vif.cb_drv.PPROT   <= tr.prot;
        vif.cb_drv.PSEL    <= 1'b1;
        vif.cb_drv.PENABLE <= 1'b0;

        // ---------------------------------------------------------------------
        // Phase 2: ACCESS Phase (PSEL=1, PENABLE=1, wait for PREADY)
        // ---------------------------------------------------------------------
        @(vif.cb_drv);
        vif.cb_drv.PENABLE <= 1'b1;

        // Wait until slave asserts PREADY
        while (!vif.cb_drv.PREADY) begin
            @(vif.cb_drv);
        end

        // Sample transfer status & Read Data at active handshake completion edge
        tr.resp = (vif.cb_drv.PSLVERR === 1'b1) ? APB_ERROR : APB_OKAY;
        if (tr.trans_type == APB_READ) begin
            tr.rdata = vif.cb_drv.PRDATA;
        end

        // Complete transfer
        @(vif.cb_drv);
        vif.cb_drv.PSEL    <= 1'b0;
        vif.cb_drv.PENABLE <= 1'b0;

        -> drv_done_event;
    endtask

endclass : apb_driver

`endif // APB_DRIVER_SV
