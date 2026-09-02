// =============================================================================
// File: apb_ram_memory_array.sv
// Description: Parameterized Byte-Addressable RAM Core
// Standard: Synthesizable SystemVerilog (IEEE 1800-2017)
// Author: Antigravity DV Team
// =============================================================================

`timescale 1ns / 1ps

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

    // Memory array: MEM_DEPTH words of DATA_WIDTH bits (divided into 8-bit bytes)
    logic [STRB_WIDTH-1:0][7:0] mem [0:MEM_DEPTH-1];

    // Combinational read for zero-wait-state APB access
    always_comb begin
        if (word_addr < MEM_DEPTH) begin
            for (int b = 0; b < STRB_WIDTH; b++) begin
                rdata[(b*8) +: 8] = mem[word_addr][b];
            end
        end else begin
            rdata = {DATA_WIDTH{1'b0}};
        end
    end

    // Byte-masked synchronous write
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Synchronous/Asynchronous reset clearing or memory state init
            // Note: In synthesis, memory array reset is typically omitted for BRAM inference,
            // but initialized for simulation determinism.
        end else if (write_en && (word_addr < MEM_DEPTH)) begin
            for (int b = 0; b < STRB_WIDTH; b++) begin
                if (byte_strb[b]) begin
                    mem[word_addr][b] <= wdata[(b*8) +: 8];
                end
            end
        end
    end

endmodule
