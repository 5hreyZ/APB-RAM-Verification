// =============================================================================
// File: apb_if.sv
// Description: SystemVerilog APB4 Interface with Clocking Blocks & Modports
// Author: Antigravity DV Team
// =============================================================================

`ifndef APB_IF_SV
`define APB_IF_SV

`timescale 1ns / 1ps

interface apb_if #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int STRB_WIDTH = DATA_WIDTH / 8
) (
    input logic PCLK
);

    // APB Protocol Signals
    logic                  PRESETn;
    logic                  PSEL;
    logic                  PENABLE;
    logic                  PWRITE;
    logic [ADDR_WIDTH-1:0] PADDR;
    logic [DATA_WIDTH-1:0] PWDATA;
    logic [STRB_WIDTH-1:0] PSTRB;
    logic [2:0]            PPROT;

    logic                  PREADY;
    logic [DATA_WIDTH-1:0] PRDATA;
    logic                  PSLVERR;

    // -------------------------------------------------------------------------
    // Driver Clocking Block (Synchronous stimulus generation, eliminates race)
    // -------------------------------------------------------------------------
    clocking cb_drv @(posedge PCLK);
        default input #1step output #1ns;
        output PSEL;
        output PENABLE;
        output PWRITE;
        output PADDR;
        output PWDATA;
        output PSTRB;
        output PPROT;
        input  PREADY;
        input  PRDATA;
        input  PSLVERR;
        input  PRESETn;
    endclocking

    // -------------------------------------------------------------------------
    // Monitor Clocking Block (Race-free sampling at active clock edge)
    // -------------------------------------------------------------------------
    clocking cb_mon @(posedge PCLK);
        default input #1step output #1ns;
        input  PSEL;
        input  PENABLE;
        input  PWRITE;
        input  PADDR;
        input  PWDATA;
        input  PSTRB;
        input  PPROT;
        input  PREADY;
        input  PRDATA;
        input  PSLVERR;
        input  PRESETn;
    endclocking

    // -------------------------------------------------------------------------
    // Modports for Structural Encapsulation
    // -------------------------------------------------------------------------
    modport DRV (
        clocking cb_drv,
        input    PCLK,
        input    PRESETn
    );

    modport MON (
        clocking cb_mon,
        input    PCLK,
        input    PRESETn
    );

    modport DUT (
        input  PCLK,
        input  PRESETn,
        input  PSEL,
        input  PENABLE,
        input  PWRITE,
        input  PADDR,
        input  PWDATA,
        input  PSTRB,
        input  PPROT,
        output PREADY,
        output PRDATA,
        output PSLVERR
    );

endinterface : apb_if

`endif // APB_IF_SV
