`timescale 1ns/1ps

module apb_ram #(
    parameter ADDR_WIDTH = 8,   // Address width
    parameter DATA_WIDTH = 32   // Data width
)(
    input  wire                  PCLK,
    input  wire                  PRESETn,

    // APB Interface
    input  wire                  PSEL,
    input  wire                  PENABLE,
    input  wire                  PWRITE,
    input  wire [ADDR_WIDTH-1:0] PADDR,
    input  wire [DATA_WIDTH-1:0] PWDATA,

    output reg  [DATA_WIDTH-1:0] PRDATA,
    output reg                   PREADY,
    output wire                  PSLVERR
);

    // ----------------------------
    // Memory declaration
    // ----------------------------
    localparam DEPTH = (1 << ADDR_WIDTH);
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    assign PSLVERR = 1'b0;  // No error response

    // ----------------------------
    // APB state: ready generation
    // ----------------------------
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            PREADY <= 1'b0;
        else
            PREADY <= PSEL & PENABLE; // single-cycle access
    end

    // ----------------------------
    // Write operation
    // ----------------------------
    always @(posedge PCLK) begin
        if (PSEL && PENABLE && PWRITE) begin
            mem[PADDR] <= PWDATA;
        end
    end

    // ----------------------------
    // Read operation
    // ----------------------------
    always @(posedge PCLK) begin
        if (PSEL && PENABLE && !PWRITE) begin
            PRDATA <= mem[PADDR];
        end
    end

endmodule
