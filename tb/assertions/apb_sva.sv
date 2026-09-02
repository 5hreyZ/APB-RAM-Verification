// =============================================================================
// File: apb_sva.sv
// Description: SystemVerilog Concurrent Assertions (SVA) for AMBA APB4 Protocol
// Author: Antigravity DV Team
// =============================================================================

`ifndef APB_SVA_SV
`define APB_SVA_SV

`timescale 1ns / 1ps

module apb_sva (
    input logic        PCLK,
    input logic        PRESETn,
    input logic        PSEL,
    input logic        PENABLE,
    input logic        PWRITE,
    input logic [31:0] PADDR,
    input logic [31:0] PWDATA,
    input logic [3:0]  PSTRB,
    input logic [2:0]  PPROT,
    input logic        PREADY,
    input logic [31:0] PRDATA,
    input logic        PSLVERR
);

    // -------------------------------------------------------------------------
    // Rule 1: Setup Phase must transition to Access Phase in next cycle
    // (PSEL=1 && PENABLE=0) |=> (PSEL=1 && PENABLE=1)
    // -------------------------------------------------------------------------
    property p_setup_to_access;
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && !PENABLE) |=> (PSEL && PENABLE);
    endproperty
    assert_setup_to_access: assert property (p_setup_to_access)
        else $error("[SVA ERROR] Protocol Violation: SETUP phase did not transition to ACCESS phase!");
    cover_setup_to_access: cover property (p_setup_to_access);

    // -------------------------------------------------------------------------
    // Rule 2: Access Phase must complete when PREADY is high
    // (PSEL=1 && PENABLE=1 && PREADY=1) |=> (PENABLE=0)
    // -------------------------------------------------------------------------
    property p_access_completion;
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && PENABLE && PREADY) |=> (!PENABLE);
    endproperty
    assert_access_completion: assert property (p_access_completion)
        else $error("[SVA ERROR] Protocol Violation: PENABLE remained asserted after handshake completion!");
    cover_access_completion: cover property (p_access_completion);

    // -------------------------------------------------------------------------
    // Rule 3: Signals must remain STABLE during wait states (PREADY=0)
    // -------------------------------------------------------------------------
    property p_stable_addr_during_wait;
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && PENABLE && !PREADY) |=> $stable(PADDR);
    endproperty
    assert_stable_addr: assert property (p_stable_addr_during_wait)
        else $error("[SVA ERROR] Protocol Violation: PADDR changed while waiting for PREADY!");

    property p_stable_ctrl_during_wait;
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && PENABLE && !PREADY) |=> ($stable(PWRITE) && $stable(PPROT));
    endproperty
    assert_stable_ctrl: assert property (p_stable_ctrl_during_wait)
        else $error("[SVA ERROR] Protocol Violation: PWRITE/PPROT changed while waiting for PREADY!");

    property p_stable_wdata_during_wait;
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && PENABLE && !PREADY && PWRITE) |=> ($stable(PWDATA) && $stable(PSTRB));
    endproperty
    assert_stable_wdata: assert property (p_stable_wdata_during_wait)
        else $error("[SVA ERROR] Protocol Violation: PWDATA/PSTRB changed during write wait state!");

    // -------------------------------------------------------------------------
    // Rule 4: PSLVERR must only be asserted during active transfer & PREADY
    // -------------------------------------------------------------------------
    property p_pslverr_validity;
        @(posedge PCLK) disable iff (!PRESETn)
        PSLVERR |-> (PSEL && PENABLE && PREADY);
    endproperty
    assert_pslverr_validity: assert property (p_pslverr_validity)
        else $error("[SVA ERROR] Protocol Violation: PSLVERR asserted outside of valid ACCESS handshake!");
    cover_pslverr_assertion: cover property (p_pslverr_validity);

    // -------------------------------------------------------------------------
    // Rule 5: Reset De-assertion of Error
    // -------------------------------------------------------------------------
    property p_reset_quiescent;
        @(posedge PCLK)
        !PRESETn |-> (PSLVERR == 1'b0);
    endproperty
    assert_reset_quiescent: assert property (p_reset_quiescent)
        else $error("[SVA ERROR] PSLVERR active during reset!");

endmodule

`endif // APB_SVA_SV
