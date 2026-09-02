// =============================================================================
// File: apb_generator.sv
// Description: Scenario & Stimulus Generator with Event Synchronization
// Author: Antigravity DV Team
// =============================================================================

`ifndef APB_GENERATOR_SV
`define APB_GENERATOR_SV

import apb_pkg::*;
`include "tb/classes/apb_transaction.sv"

class apb_generator;

    // Mailbox & Event handles
    mailbox #(apb_transaction) gen2drv_mbx;
    event drv_done_event;
    event gen_done_event;

    // Configuration
    int unsigned trans_count;
    apb_transaction tr_blueprint;

    function new(mailbox #(apb_transaction) gen2drv_mbx, event drv_done_event);
        this.gen2drv_mbx    = gen2drv_mbx;
        this.drv_done_event = drv_done_event;
        this.trans_count    = 10;
        this.tr_blueprint   = new();
    endfunction

    // Run task to generate and dispatch transactions
    virtual task run();
        apb_transaction tr;
        apb_log(LOG_INFO, "GENERATOR", $sformatf("Starting generation of %0d transactions...", trans_count));
        for (int i = 0; i < trans_count; i++) begin
            tr = new();
            if (!tr.randomize()) begin
                apb_log(LOG_FATAL, "GENERATOR", "Transaction randomization failed!");
            end
            
            gen2drv_mbx.put(tr.clone());
            // Wait for driver to complete handshake before producing next (unless pipelined)
            @ (drv_done_event);
        end
        apb_log(LOG_INFO, "GENERATOR", "Stimulus generation completed.");
        -> gen_done_event;
    endtask

endclass : apb_generator

`endif // APB_GENERATOR_SV
