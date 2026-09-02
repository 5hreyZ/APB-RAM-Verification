// =============================================================================
// File: apb_slave_ram.sv
// Description: Synthesizable AMBA APB4 Slave RAM Memory Controller
// Standard: AMBA APB Protocol Specification v2.0 (ARM IHI 0024E)
// Author: Antigravity DV Team
// =============================================================================

`timescale 1ns / 1ps

module apb_slave_ram #(
    parameter int ADDR_WIDTH   = 32,
    parameter int DATA_WIDTH   = 32,
    parameter int MEM_DEPTH    = 1024,
    parameter logic [ADDR_WIDTH-1:0] BASE_ADDR = 32'h0000_0000,
    parameter int WAIT_CYCLES  = 0,
    parameter int STRB_WIDTH   = DATA_WIDTH / 8
) (
    // Clock and Reset
    input  logic                    PCLK,
    input  logic                    PRESETn,

    // APB Slave Interface Signals
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

    // -------------------------------------------------------------------------
    // Local Parameters & Derived Constants
    // -------------------------------------------------------------------------
    localparam int BYTES_PER_WORD  = DATA_WIDTH / 8;
    localparam int ALIGN_SHIFT     = $clog2(BYTES_PER_WORD);
    localparam int MEM_SIZE_BYTES  = MEM_DEPTH * BYTES_PER_WORD;
    localparam logic [ADDR_WIDTH-1:0] MAX_ADDR = BASE_ADDR + MEM_SIZE_BYTES - 1;

    // -------------------------------------------------------------------------
    // Internal Signals & State Tracking
    // -------------------------------------------------------------------------
    logic                  addr_in_range;
    logic                  addr_aligned;
    logic                  valid_access;
    logic [ADDR_WIDTH-1:0] word_addr;
    logic                  ram_write_en;
    logic [DATA_WIDTH-1:0] ram_rdata;
    int unsigned           wait_cnt;

    // -------------------------------------------------------------------------
    // Address Decoding and Alignment Check
    // -------------------------------------------------------------------------
    assign addr_in_range = (PADDR >= BASE_ADDR) && (PADDR <= MAX_ADDR);
    assign addr_aligned  = (PADDR[ALIGN_SHIFT-1:0] == '0);
    assign valid_access  = addr_in_range && addr_aligned;
    assign word_addr     = (PADDR - BASE_ADDR) >> ALIGN_SHIFT;

    // -------------------------------------------------------------------------
    // Wait-State Generation Engine
    // -------------------------------------------------------------------------
    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            wait_cnt <= 0;
        end else if (PSEL && PENABLE) begin
            if (wait_cnt < WAIT_CYCLES) begin
                wait_cnt <= wait_cnt + 1;
            end else begin
                wait_cnt <= 0;
            end
        end else begin
            wait_cnt <= 0;
        end
    end

    // Ready handshake generation
    always_comb begin
        if (!PRESETn) begin
            PREADY = 1'b1;
        end else if (PSEL && PENABLE) begin
            if (WAIT_CYCLES == 0) begin
                PREADY = 1'b1;
            end else begin
                PREADY = (wait_cnt == WAIT_CYCLES);
            end
        end else begin
            // Ready during SETUP or IDLE
            PREADY = 1'b1;
        end
    end

    // -------------------------------------------------------------------------
    // Error Generation (PSLVERR)
    // Asserted during ACCESS phase when ready and access is invalid/unmapped
    // -------------------------------------------------------------------------
    always_comb begin
        if (!PRESETn) begin
            PSLVERR = 1'b0;
        end else if (PSEL && PENABLE && PREADY) begin
            PSLVERR = !valid_access;
        end else begin
            PSLVERR = 1'b0;
        end
    end

    // -------------------------------------------------------------------------
    // Memory Write Enable & Read Data Routing
    // -------------------------------------------------------------------------
    // Write occurs at the end of the ACCESS phase when PREADY is high
    assign ram_write_en = PSEL && PENABLE && PREADY && PWRITE && valid_access;

    // Read Data output multiplexing
    always_comb begin
        if (!PRESETn) begin
            PRDATA = '0;
        end else if (PSEL && !PWRITE && valid_access) begin
            PRDATA = ram_rdata;
        end else begin
            PRDATA = '0;
        end
    end

    // -------------------------------------------------------------------------
    // Instantiate Core RAM Memory Array
    // -------------------------------------------------------------------------
    apb_ram_memory_array #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .MEM_DEPTH  (MEM_DEPTH),
        .STRB_WIDTH (STRB_WIDTH)
    ) u_ram_core (
        .clk        (PCLK),
        .rst_n      (PRESETn),
        .write_en   (ram_write_en),
        .word_addr  (word_addr),
        .byte_strb  (PSTRB),
        .wdata      (PWDATA),
        .rdata      (ram_rdata)
    );

endmodule
