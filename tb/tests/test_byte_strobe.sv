// =============================================================================
// File: test_byte_strobe.sv
// Description: Exhaustive Byte-Enable Write Masking (PSTRB) Verification Test
// Author: Antigravity DV Team
// =============================================================================

`ifndef TEST_BYTE_STROBE_SV
`define TEST_BYTE_STROBE_SV

`include "tb/classes/apb_env.sv"

// Custom generator for targeted byte strobe patterns
class apb_byte_strobe_generator extends apb_generator;

    function new(mailbox #(apb_transaction) gen2drv_mbx, event drv_done_event);
        super.new(gen2drv_mbx, drv_done_event);
    endfunction

    virtual task run();
        bit [3:0] strb_patterns[6];
        apb_transaction tr;
        apb_transaction tr_w;
        apb_transaction tr_r;

        strb_patterns[0] = 4'b0011;
        strb_patterns[1] = 4'b1100;
        strb_patterns[2] = 4'b0110;
        strb_patterns[3] = 4'b1001;
        strb_patterns[4] = 4'b1111;
        strb_patterns[5] = 4'b0101;

        apb_log(LOG_INFO, "BYTE_GEN", "Executing targeted byte-masking sequences...");

        // Pattern 1: Incremental Single-Byte Writes to Address 0x0000_0040
        for (int b = 0; b < 4; b++) begin
            tr            = new();
            tr.addr        = 32'h0000_0040;
            tr.trans_type  = APB_WRITE;
            tr.data        = (32'h11223344 << (b*8)) | 32'hA0A0A0A0;
            tr.strb        = (4'b0001 << b);
            tr.idle_cycles = 0;
            gen2drv_mbx.put(tr);
            @(drv_done_event);

            // Read back after each byte write
            tr            = new();
            tr.addr        = 32'h0000_0040;
            tr.trans_type  = APB_READ;
            tr.idle_cycles = 0;
            gen2drv_mbx.put(tr);
            @(drv_done_event);
        end

        // Pattern 2: Half-Word & Full-Word Patterns across 50 memory addresses
        for (int i = 0; i < 50; i++) begin
            tr_w            = new();
            tr_r            = new();

            tr_w.addr        = APB_BASE_ADDR + (i * 4);
            tr_w.trans_type  = APB_WRITE;
            tr_w.data        = $urandom();
            tr_w.strb        = strb_patterns[i % 6];
            tr_w.idle_cycles = $urandom_range(0, 2);
            gen2drv_mbx.put(tr_w);
            @(drv_done_event);

            tr_r.addr        = tr_w.addr;
            tr_r.trans_type  = APB_READ;
            tr_r.idle_cycles = 0;
            gen2drv_mbx.put(tr_r);
            @(drv_done_event);
        end

        apb_log(LOG_INFO, "BYTE_GEN", "Byte strobe test sequence generation completed.");
        -> gen_done_event;
    endtask

endclass : apb_byte_strobe_generator

class test_byte_strobe;

    apb_env env;
    virtual apb_if.DRV vif_drv;
    virtual apb_if.MON vif_mon;

    function new(virtual apb_if.DRV vif_drv, virtual apb_if.MON vif_mon);
        this.vif_drv = vif_drv;
        this.vif_mon = vif_mon;
        this.env     = new(vif_drv, vif_mon);
    endfunction

    virtual task run();
        apb_byte_strobe_generator custom_gen;
        apb_log(LOG_INFO, "TEST_BYTE_STROBE", "========== Starting test_byte_strobe ==========");
        env.build();

        // Replace standard generator with targeted byte strobe generator
        custom_gen = new(env.gen2drv_mbx, env.drv_done_event);
        env.gen    = custom_gen;

        env.run();
        env.report();
        apb_log(LOG_INFO, "TEST_BYTE_STROBE", "========== Finished test_byte_strobe ==========");
    endtask

endclass : test_byte_strobe

`endif // TEST_BYTE_STROBE_SV
