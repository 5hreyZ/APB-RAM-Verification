// =============================================================================
// File: eda_playground_bundle.sv
// Description: Standalone Single-File SystemVerilog Verification Bundle
// Ready for 1-Click Simulation on EDA Playground (Aldec Riviera-PRO / VCS / Questa)
// Author: Antigravity DV Team
// =============================================================================

`timescale 1ns / 1ps

// =============================================================================
// 1. APB VERIFICATION PACKAGE
// =============================================================================
package apb_pkg;
    typedef enum bit { APB_READ = 1'b0, APB_WRITE = 1'b1 } apb_trans_type_e;
    typedef enum bit { APB_OKAY = 1'b0, APB_ERROR = 1'b1 } apb_resp_e;
    typedef enum { LOG_INFO, LOG_WARN, LOG_ERROR, LOG_FATAL } apb_log_level_e;

    parameter int APB_ADDR_WIDTH   = 32;
    parameter int APB_DATA_WIDTH   = 32;
    parameter int APB_STRB_WIDTH   = APB_DATA_WIDTH / 8;
    parameter int APB_MEM_DEPTH    = 1024;
    parameter bit [31:0] APB_BASE_ADDR = 32'h0000_0000;
    parameter bit [31:0] APB_MAX_ADDR  = APB_BASE_ADDR + (APB_MEM_DEPTH * APB_STRB_WIDTH) - 1;

    function automatic void apb_log(input apb_log_level_e level, input string tag, input string msg);
        string prefix = (level == LOG_INFO) ? "[INFO]" : (level == LOG_WARN) ? "[WARN]" : (level == LOG_ERROR) ? "[ERROR]" : "[FATAL]";
        $display("%0t | %-7s | %-12s | %s", $time, prefix, tag, msg);
        if (level == LOG_FATAL) $fatal(1, "%0t | Fatal in %s: %s", $time, tag, msg);
    endfunction
endpackage : apb_pkg

import apb_pkg::*;

// =============================================================================
// 2. RTL: BYTE-ADDRESSABLE MEMORY CORE
// =============================================================================
module apb_ram_memory_array #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int MEM_DEPTH  = 1024,
    parameter int STRB_WIDTH = DATA_WIDTH / 8
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  write_en,
    input  logic [ADDR_WIDTH-1:0] word_addr,
    input  logic [STRB_WIDTH-1:0] byte_strb,
    input  logic [DATA_WIDTH-1:0] wdata,
    output logic [DATA_WIDTH-1:0] rdata
);
    logic [STRB_WIDTH-1:0][7:0] mem [0:MEM_DEPTH-1];

    always_comb begin
        if (word_addr < MEM_DEPTH) begin
            for (int b = 0; b < STRB_WIDTH; b++) rdata[(b*8) +: 8] = mem[word_addr][b];
        end else begin
            rdata = {DATA_WIDTH{1'b0}};
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
        end else if (write_en && (word_addr < MEM_DEPTH)) begin
            for (int b = 0; b < STRB_WIDTH; b++) begin
                if (byte_strb[b]) mem[word_addr][b] <= wdata[(b*8) +: 8];
            end
        end
    end
endmodule

// =============================================================================
// 3. RTL: APB4 SLAVE RAM CONTROLLER
// =============================================================================
module apb_slave_ram #(
    parameter int ADDR_WIDTH   = 32,
    parameter int DATA_WIDTH   = 32,
    parameter int MEM_DEPTH    = 1024,
    parameter logic [ADDR_WIDTH-1:0] BASE_ADDR = 32'h0000_0000,
    parameter int WAIT_CYCLES  = 0,
    parameter int STRB_WIDTH   = DATA_WIDTH / 8
) (
    input  logic                    PCLK,
    input  logic                    PRESETn,
    input  logic                    PSEL,
    input  logic                    PENABLE,
    input  logic                    PWRITE,
    input  logic [ADDR_WIDTH-1:0]   PADDR,
    input  logic [DATA_WIDTH-1:0]   PWDATA,
    input  logic [STRB_WIDTH-1:0]   PSTRB,
    input  logic [2:0]              PPROT,
    output logic                    PREADY,
    output logic [DATA_WIDTH-1:0]   PRDATA,
    output logic                    PSLVERR
);
    localparam int BYTES_PER_WORD  = DATA_WIDTH / 8;
    localparam int ALIGN_SHIFT     = $clog2(BYTES_PER_WORD);
    localparam int MEM_SIZE_BYTES  = MEM_DEPTH * BYTES_PER_WORD;
    localparam logic [ADDR_WIDTH-1:0] MAX_ADDR = BASE_ADDR + MEM_SIZE_BYTES - 1;

    logic                  addr_in_range;
    logic                  addr_aligned;
    logic                  valid_access;
    logic [ADDR_WIDTH-1:0] word_addr;
    logic                  ram_write_en;
    logic [DATA_WIDTH-1:0] ram_rdata;
    int unsigned           wait_cnt;

    assign addr_in_range = (PADDR >= BASE_ADDR) && (PADDR <= MAX_ADDR);
    assign addr_aligned  = (PADDR[ALIGN_SHIFT-1:0] == '0);
    assign valid_access  = addr_in_range && addr_aligned;
    assign word_addr     = (PADDR - BASE_ADDR) >> ALIGN_SHIFT;

    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            wait_cnt <= 0;
        end else if (PSEL && PENABLE) begin
            if (wait_cnt < WAIT_CYCLES) wait_cnt <= wait_cnt + 1;
            else wait_cnt <= 0;
        end else begin
            wait_cnt <= 0;
        end
    end

    always_comb begin
        if (!PRESETn) PREADY = 1'b1;
        else if (PSEL && PENABLE) PREADY = (WAIT_CYCLES == 0) ? 1'b1 : (wait_cnt == WAIT_CYCLES);
        else PREADY = 1'b1;
    end

    always_comb begin
        if (!PRESETn) PSLVERR = 1'b0;
        else if (PSEL && PENABLE && PREADY) PSLVERR = !valid_access;
        else PSLVERR = 1'b0;
    end

    assign ram_write_en = PSEL && PENABLE && PREADY && PWRITE && valid_access;

    always_comb begin
        if (!PRESETn) PRDATA = '0;
        else if (PSEL && !PWRITE && valid_access) PRDATA = ram_rdata;
        else PRDATA = '0;
    end

    apb_ram_memory_array #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .MEM_DEPTH(MEM_DEPTH), .STRB_WIDTH(STRB_WIDTH)
    ) u_ram_core (
        .clk(PCLK), .rst_n(PRESETn), .write_en(ram_write_en), .word_addr(word_addr),
        .byte_strb(PSTRB), .wdata(PWDATA), .rdata(ram_rdata)
    );
endmodule

// =============================================================================
// 4. APB INTERFACE
// =============================================================================
interface apb_if #(parameter int ADDR_WIDTH = 32, parameter int DATA_WIDTH = 32, parameter int STRB_WIDTH = 4)(input logic PCLK);
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

    clocking cb_drv @(posedge PCLK);
        default input #1step output #1ns;
        output PSEL, PENABLE, PWRITE, PADDR, PWDATA, PSTRB, PPROT;
        input  PREADY, PRDATA, PSLVERR, PRESETn;
    endclocking

    clocking cb_mon @(posedge PCLK);
        default input #1step output #1ns;
        input  PSEL, PENABLE, PWRITE, PADDR, PWDATA, PSTRB, PPROT, PREADY, PRDATA, PSLVERR, PRESETn;
    endclocking

    modport DRV (clocking cb_drv, input PCLK, PRESETn);
    modport MON (clocking cb_mon, input PCLK, PRESETn);
endinterface

// =============================================================================
// 5. SYSTEMVERILOG ASSERTIONS (SVA)
// =============================================================================
module apb_sva (
    input logic PCLK, PRESETn, PSEL, PENABLE, PWRITE,
    input logic [31:0] PADDR, PWDATA, input logic [3:0] PSTRB, input logic [2:0] PPROT,
    input logic PREADY, input logic [31:0] PRDATA, input logic PSLVERR
);
    property p_setup_to_access;
        @(posedge PCLK) disable iff (!PRESETn) (PSEL && !PENABLE) |=> (PSEL && PENABLE);
    endproperty
    assert_setup_to_access: assert property (p_setup_to_access)
        else $error("[SVA ERROR] SETUP phase did not transition to ACCESS phase!");

    property p_access_completion;
        @(posedge PCLK) disable iff (!PRESETn) (PSEL && PENABLE && PREADY) |=> (!PENABLE);
    endproperty
    assert_access_completion: assert property (p_access_completion)
        else $error("[SVA ERROR] PENABLE held after handshake completion!");

    property p_pslverr_validity;
        @(posedge PCLK) disable iff (!PRESETn) PSLVERR |-> (PSEL && PENABLE && PREADY);
    endproperty
    assert_pslverr_validity: assert property (p_pslverr_validity)
        else $error("[SVA ERROR] PSLVERR active outside valid handshake!");
endmodule

// =============================================================================
// 6. OOP VERIFICATION COMPONENTS
// =============================================================================
class apb_transaction;
    rand bit [31:0]         addr;
    rand bit [31:0]         data;
    rand apb_trans_type_e   trans_type;
    rand bit [3:0]          strb;
    rand bit [2:0]          prot;
    rand int unsigned       idle_cycles;
    rand bit                is_err_expected;
    bit [31:0]              rdata;
    apb_resp_e              resp;
    int unsigned            trans_id;

    constraint c_default_addr  { addr inside {[APB_BASE_ADDR : APB_MAX_ADDR]}; }
    constraint c_default_align { addr[1:0] == 2'b00; }
    constraint c_default_strb  { strb inside {[4'b0001 : 4'b1111]}; }
    constraint c_default_idle  { idle_cycles dist { 0 := 50, [1:2] := 40, 3 := 10 }; }
    constraint c_rw_dist       { trans_type dist { APB_WRITE := 50, APB_READ := 50 }; }
    constraint c_prot_default  { prot == 3'b000; }
    constraint c_err_default   { is_err_expected == 1'b0; }

    function new();
        static int gid = 0;
        this.trans_id = ++gid;
        this.resp = APB_OKAY;
    endfunction

    virtual function apb_transaction clone();
        apb_transaction c = new();
        c.addr = this.addr; c.data = this.data; c.trans_type = this.trans_type;
        c.strb = this.strb; c.prot = this.prot; c.idle_cycles = this.idle_cycles;
        c.is_err_expected = this.is_err_expected; c.rdata = this.rdata;
        c.resp = this.resp; c.trans_id = this.trans_id;
        return c;
    endfunction
endclass

class apb_driver;
    virtual apb_if.DRV vif;
    mailbox #(apb_transaction) gen2drv_mbx;
    event drv_done_event;

    function new(virtual apb_if.DRV vif, mailbox #(apb_transaction) gen2drv_mbx, event drv_done_event);
        this.vif = vif; this.gen2drv_mbx = gen2drv_mbx; this.drv_done_event = drv_done_event;
    endfunction

    task run();
        @(vif.cb_drv);
        vif.cb_drv.PSEL <= 0; vif.cb_drv.PENABLE <= 0; vif.cb_drv.PWRITE <= 0;
        vif.cb_drv.PADDR <= 0; vif.cb_drv.PWDATA <= 0; vif.cb_drv.PSTRB <= 0;
        while (vif.cb_drv.PRESETn !== 1'b1) @(vif.cb_drv);

        forever begin
            apb_transaction tr;
            gen2drv_mbx.get(tr);
            if (tr.idle_cycles > 0) begin
                vif.cb_drv.PSEL <= 0; vif.cb_drv.PENABLE <= 0;
                repeat (tr.idle_cycles) @(vif.cb_drv);
            end
            @(vif.cb_drv);
            vif.cb_drv.PADDR <= tr.addr; vif.cb_drv.PWRITE <= (tr.trans_type == APB_WRITE);
            vif.cb_drv.PWDATA <= tr.data; vif.cb_drv.PSTRB <= tr.strb; vif.cb_drv.PPROT <= tr.prot;
            vif.cb_drv.PSEL <= 1'b1; vif.cb_drv.PENABLE <= 1'b0;

            @(vif.cb_drv);
            vif.cb_drv.PENABLE <= 1'b1;
            while (!vif.cb_drv.PREADY) @(vif.cb_drv);

            tr.resp = (vif.cb_drv.PSLVERR === 1'b1) ? APB_ERROR : APB_OKAY;
            if (tr.trans_type == APB_READ) tr.rdata = vif.cb_drv.PRDATA;

            @(vif.cb_drv);
            vif.cb_drv.PSEL <= 1'b0; vif.cb_drv.PENABLE <= 1'b0;
            -> drv_done_event;
        end
    endtask
endclass

class apb_monitor;
    virtual apb_if.MON vif;
    mailbox #(apb_transaction) mon2sb_mbx;

    function new(virtual apb_if.MON vif, mailbox #(apb_transaction) mon2sb_mbx);
        this.vif = vif; this.mon2sb_mbx = mon2sb_mbx;
    endfunction

    task run();
        forever begin
            @(vif.cb_mon);
            if (vif.cb_mon.PSEL === 1'b1 && vif.cb_mon.PENABLE === 1'b1 &&
                vif.cb_mon.PREADY === 1'b1 && vif.cb_mon.PRESETn === 1'b1) begin
                apb_transaction tr = new();
                tr.addr = vif.cb_mon.PADDR; tr.trans_type = (vif.cb_mon.PWRITE === 1'b1) ? APB_WRITE : APB_READ;
                tr.data = vif.cb_mon.PWDATA; tr.strb = vif.cb_mon.PSTRB; tr.prot = vif.cb_mon.PPROT;
                tr.rdata = vif.cb_mon.PRDATA; tr.resp = (vif.cb_mon.PSLVERR === 1'b1) ? APB_ERROR : APB_OKAY;
                mon2sb_mbx.put(tr.clone());
            end
        end
    endtask
endclass

class apb_scoreboard;
    mailbox #(apb_transaction) mon2sb_mbx;
    bit [7:0] ref_mem [int unsigned];
    int total_cnt = 0, match_cnt = 0, mismatch_cnt = 0, write_cnt = 0, read_cnt = 0;

    function new(mailbox #(apb_transaction) mon2sb_mbx);
        this.mon2sb_mbx = mon2sb_mbx;
    endfunction

    task run();
        forever begin
            apb_transaction tr;
            mon2sb_mbx.get(tr);
            total_cnt++;

            if (tr.addr > APB_MAX_ADDR || tr.addr[1:0] != 2'b00) begin
                if (tr.resp == APB_ERROR) match_cnt++;
                else begin mismatch_cnt++; $display("[SB FAIL] Expected PSLVERR for Addr 0x%08h", tr.addr); end
            end else if (tr.trans_type == APB_WRITE) begin
                write_cnt++;
                if (tr.resp == APB_OKAY) begin
                    match_cnt++;
                    for (int b = 0; b < 4; b++) if (tr.strb[b]) ref_mem[tr.addr + b] = tr.data[(b*8)+:8];
                end else mismatch_cnt++;
            end else begin
                bit [31:0] exp_data;
                read_cnt++;
                for (int b = 0; b < 4; b++) exp_data[(b*8)+:8] = ref_mem.exists(tr.addr + b) ? ref_mem[tr.addr + b] : 8'h00;
                if (tr.rdata === exp_data && tr.resp == APB_OKAY) match_cnt++;
                else begin
                    mismatch_cnt++;
                    $display("[SB DATA MISMATCH] Addr: 0x%08h | Exp: 0x%08h | Act: 0x%08h", tr.addr, exp_data, tr.rdata);
                end
            end
        end
    endtask

    function void report();
        $display("\n===============================================================================");
        $display("                          VERIFICATION SCOREBOARD REPORT                       ");
        $display("===============================================================================");
        $display(" Total Transactions Processed : %0d", total_cnt);
        $display(" Total Writes Verified        : %0d", write_cnt);
        $display(" Total Reads Verified         : %0d", read_cnt);
        $display(" Total Matches (PASS)         : %0d", match_cnt);
        $display(" Total Mismatches (FAIL)      : %0d", mismatch_cnt);
        $display("-------------------------------------------------------------------------------");
        if (mismatch_cnt == 0 && total_cnt > 0)
            $display("                    >>> TEST STATUS: PASSED (100%% MATCH) <<<                   ");
        else
            $display("                    >>> TEST STATUS: FAILED (%0d ERRORS) <<<                   ", mismatch_cnt);
        $display("===============================================================================\n");
    endfunction
endclass

// =============================================================================
// 7. SIMULATION TOP HARNESS & COMPREHENSIVE TEST SUITE
// =============================================================================
module tb_top;
    logic PCLK;
    logic PRESETn;

    initial begin PCLK = 0; forever #5 PCLK = ~PCLK; end
    initial begin PRESETn = 0; #25; @(posedge PCLK); PRESETn = 1; end

    apb_if apb_bus(PCLK);
    assign apb_bus.PRESETn = PRESETn;

    apb_slave_ram u_dut (
        .PCLK(apb_bus.PCLK), .PRESETn(apb_bus.PRESETn), .PSEL(apb_bus.PSEL),
        .PENABLE(apb_bus.PENABLE), .PWRITE(apb_bus.PWRITE), .PADDR(apb_bus.PADDR),
        .PWDATA(apb_bus.PWDATA), .PSTRB(apb_bus.PSTRB), .PPROT(apb_bus.PPROT),
        .PREADY(apb_bus.PREADY), .PRDATA(apb_bus.PRDATA), .PSLVERR(apb_bus.PSLVERR)
    );

    bind apb_if apb_sva u_sva (
        .PCLK(PCLK), .PRESETn(PRESETn), .PSEL(PSEL), .PENABLE(PENABLE), .PWRITE(PWRITE),
        .PADDR(PADDR), .PWDATA(PWDATA), .PSTRB(PSTRB), .PPROT(PPROT),
        .PREADY(PREADY), .PRDATA(PRDATA), .PSLVERR(PSLVERR)
    );

    initial begin
        mailbox #(apb_transaction) gen2drv_mbx = new();
        mailbox #(apb_transaction) mon2sb_mbx  = new();
        event drv_done_event;

        apb_driver     drv = new(apb_bus.DRV, gen2drv_mbx, drv_done_event);
        apb_monitor    mon = new(apb_bus.MON, mon2sb_mbx);
        apb_scoreboard sb  = new(mon2sb_mbx);

        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_top);

        @(posedge PRESETn);
        @(posedge PCLK);

        fork
            drv.run();
            mon.run();
            sb.run();
        join_none

        $display("\n[TB] === Starting Comprehensive Verification Regression ===");

        // Step 1: Byte Strobe Masking Verification
        $display("[TB] Step 1: Testing Byte-Masked Writes (PSTRB)...");
        for (int b = 0; b < 4; b++) begin
            apb_transaction tr = new();
            tr.addr = 32'h0000_0010; tr.trans_type = APB_WRITE;
            tr.data = 32'hAABBCCDD; tr.strb = (4'b0001 << b); tr.idle_cycles = 0;
            gen2drv_mbx.put(tr); @(drv_done_event);

            tr = new();
            tr.addr = 32'h0000_0010; tr.trans_type = APB_READ; tr.idle_cycles = 0;
            gen2drv_mbx.put(tr); @(drv_done_event);
        end

        // Step 2: Negative Testing (Error Injections)
        $display("[TB] Step 2: Testing Out-of-Bounds & Unaligned Error Injections (PSLVERR)...");
        begin
            apb_transaction tr = new();
            tr.addr = 32'h0001_0000; tr.trans_type = APB_WRITE; tr.data = 32'hDEAD_BEEF; tr.strb = 4'b1111;
            gen2drv_mbx.put(tr); @(drv_done_event);

            tr = new();
            tr.addr = 32'h0000_0003; tr.trans_type = APB_READ; // Unaligned
            gen2drv_mbx.put(tr); @(drv_done_event);
        end

        // Step 3: Constrained-Random Back-to-Back Read/Write Stress Test (200 transfers)
        $display("[TB] Step 3: Running Constrained-Random Stress Test...");
        for (int i = 0; i < 200; i++) begin
            apb_transaction tr = new();
            assert(tr.randomize());
            gen2drv_mbx.put(tr);
            @(drv_done_event);
        end

        #200ns;
        sb.report();
        $display("[TB] === Simulation Completed Successfully! ===");
        $finish;
    end
endmodule
