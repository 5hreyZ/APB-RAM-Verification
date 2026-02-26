`timescale 1ns/1ps

module tb_ram;

    parameter ADDR_WIDTH = 8;
    parameter DATA_WIDTH = 32;

    reg  PCLK;
    reg  PRESETn;
    reg  PSEL;
    reg  PENABLE;
    reg  PWRITE;
    reg  [ADDR_WIDTH-1:0] PADDR;
    reg  [DATA_WIDTH-1:0] PWDATA;
    wire [DATA_WIDTH-1:0] PRDATA;
    wire PREADY;
    wire PSLVERR;

    // DUT
    apb_ram #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .PCLK(PCLK),
        .PRESETn(PRESETn),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PADDR(PADDR),
        .PWDATA(PWDATA),
        .PRDATA(PRDATA),
        .PREADY(PREADY),
        .PSLVERR(PSLVERR)
    );

    // Clock
    always #5 PCLK = ~PCLK;

    // APB Write Task
    task apb_write(input [ADDR_WIDTH-1:0] addr,
                   input [DATA_WIDTH-1:0] data);
    begin
        @(posedge PCLK);
        PSEL   = 1;
        PWRITE = 1;
        PADDR  = addr;
        PWDATA = data;
        PENABLE = 0;

        @(posedge PCLK);
        PENABLE = 1;

        @(posedge PCLK);
        PSEL = 0;
        PENABLE = 0;
    end
    endtask

    // APB Read Task
    task apb_read(input [ADDR_WIDTH-1:0] addr);
    begin
        @(posedge PCLK);
        PSEL   = 1;
        PWRITE = 0;
        PADDR  = addr;
        PENABLE = 0;

        @(posedge PCLK);
        PENABLE = 1;

        @(posedge PCLK);
        PSEL = 0;
        PENABLE = 0;
    end
    endtask

    // Test
    initial begin
        PCLK = 0;
        PRESETn = 0;
        PSEL = 0;
        PENABLE = 0;
        PWRITE = 0;

        #20 PRESETn = 1;

        apb_write(8'h10, 32'hDEADBEEF);
        apb_read(8'h10);

        #50 $finish;
    end

endmodule
