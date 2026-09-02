// =============================================================================
// File: tb_top.sv
// Description: Top-Level Simulation Harness & Test Dispatcher
// Author: Antigravity DV Team
// =============================================================================

`timescale 1ns / 1ps

import apb_pkg::*;

`include "tb/if/apb_if.sv"
`include "tb/assertions/apb_sva.sv"
`include "tb/tests/test_base.sv"
`include "tb/tests/test_random.sv"
`include "tb/tests/test_byte_strobe.sv"
`include "tb/tests/test_error_handling.sv"
`include "tb/tests/test_b2b_stress.sv"
`include "tb/tests/test_wait_states.sv"

module tb_top;

    // -------------------------------------------------------------------------
    // Clock & Reset Generation
    // -------------------------------------------------------------------------
    logic PCLK;
    logic PRESETn;

    // 100 MHz clock (10ns period)
    initial begin
        PCLK = 1'b0;
        forever #5 PCLK = ~PCLK;
    end

    // Active-low asynchronous reset pulse
    initial begin
        PRESETn = 1'b0;
        #25;
        @(posedge PCLK);
        PRESETn = 1'b1;
        $display("[TB_TOP] Reset deasserted at time %0t", $time);
    end

    // -------------------------------------------------------------------------
    // APB Virtual Interface Instantiation
    // -------------------------------------------------------------------------
    apb_if #(
        .ADDR_WIDTH (32),
        .DATA_WIDTH (32),
        .STRB_WIDTH (4)
    ) apb_bus (
        .PCLK (PCLK)
    );

    // Connect global reset to interface
    assign apb_bus.PRESETn = PRESETn;

    // -------------------------------------------------------------------------
    // Device Under Test (DUT) Instantiation
    // -------------------------------------------------------------------------
    apb_slave_ram #(
        .ADDR_WIDTH  (32),
        .DATA_WIDTH  (32),
        .MEM_DEPTH   (1024),
        .BASE_ADDR   (32'h0000_0000),
        .WAIT_CYCLES (0),
        .STRB_WIDTH  (4)
    ) u_dut (
        .PCLK        (apb_bus.PCLK),
        .PRESETn     (apb_bus.PRESETn),
        .PSEL        (apb_bus.PSEL),
        .PENABLE     (apb_bus.PENABLE),
        .PWRITE      (apb_bus.PWRITE),
        .PADDR       (apb_bus.PADDR),
        .PWDATA      (apb_bus.PWDATA),
        .PSTRB       (apb_bus.PSTRB),
        .PPROT       (apb_bus.PPROT),
        .PREADY      (apb_bus.PREADY),
        .PRDATA      (apb_bus.PRDATA),
        .PSLVERR     (apb_bus.PSLVERR)
    );

    // -------------------------------------------------------------------------
    // SystemVerilog Assertions (SVA) Protocol Checker (Direct Instantiation)
    // -------------------------------------------------------------------------
    apb_sva u_sva (
        .PCLK    (PCLK),
        .PRESETn (PRESETn),
        .PSEL    (apb_bus.PSEL),
        .PENABLE (apb_bus.PENABLE),
        .PWRITE  (apb_bus.PWRITE),
        .PADDR   (apb_bus.PADDR),
        .PWDATA  (apb_bus.PWDATA),
        .PSTRB   (apb_bus.PSTRB),
        .PPROT   (apb_bus.PPROT),
        .PREADY  (apb_bus.PREADY),
        .PRDATA  (apb_bus.PRDATA),
        .PSLVERR (apb_bus.PSLVERR)
    );

    // -------------------------------------------------------------------------
    // Dynamic Testcase Selection & Execution
    // -------------------------------------------------------------------------
    string test_name = "test_base";

    initial begin
        // Optional waveform dumping for GTKWave / Vivado
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_top);

        // Retrieve testcase name from simulator command-line plusargs
        if ($value$plusargs("TESTNAME=%s", test_name)) begin
            $display("\n===============================================================================");
            $display(" [TB_TOP] Executing Test: %s", test_name);
            $display("===============================================================================\n");
        end else begin
            $display("[TB_TOP] No +TESTNAME provided. Defaulting to test_base.");
        end

        // Wait for reset release before starting test
        @(posedge PRESETn);
        @(posedge PCLK);

        // Instantiate and run selected testcase
        begin
            automatic test_base           tb;
            automatic test_random         tr;
            automatic test_byte_strobe    tbs;
            automatic test_error_handling teh;
            automatic test_b2b_stress     tb2b;
            automatic test_wait_states    tw;

            case (test_name)
                "test_base": begin
                    tb = new(apb_bus.DRV, apb_bus.MON);
                    tb.run();
                end
                "test_random": begin
                    tr = new(apb_bus.DRV, apb_bus.MON);
                    tr.run();
                end
                "test_byte_strobe": begin
                    tbs = new(apb_bus.DRV, apb_bus.MON);
                    tbs.run();
                end
                "test_error_handling": begin
                    teh = new(apb_bus.DRV, apb_bus.MON);
                    teh.run();
                end
                "test_b2b_stress": begin
                    tb2b = new(apb_bus.DRV, apb_bus.MON);
                    tb2b.run();
                end
                "test_wait_states": begin
                    tw = new(apb_bus.DRV, apb_bus.MON);
                    tw.run();
                end
                default: begin
                    $fatal(1, "[TB_TOP] FATAL: Unrecognized TESTNAME '%s' specified!", test_name);
                end
            endcase
        end

        #100ns;
        $display("\n[TB_TOP] Simulation successfully finished at time %0t\n", $time);
        $finish;
    end

    // Simulation safety timeout watchdog (tightened to prevent squished waveforms)
    initial begin
        #50000ns; // 50us safety timeout
        $fatal(1, "[TB_TOP] ERROR: Simulation safety watchdog timeout reached!");
    end

endmodule
