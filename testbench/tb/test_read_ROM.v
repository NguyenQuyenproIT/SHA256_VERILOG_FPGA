`timescale 1ns / 1ps

module tb_test_read_ROM();

    parameter DATA_WIDTH_K = 32;
    parameter MEM_SIZE_K   = 64;
    parameter DATA_WIDTH_H = 32;
    parameter MEM_SIZE_H   = 8;

    // ======================
    // Signal declarations
    // ======================
    reg clk = 0;
    reg rst_n;
    reg [$clog2(MEM_SIZE_K)-1:0] addr_K;
    reg [$clog2(MEM_SIZE_H)-1:0] addr_H;
    wire [DATA_WIDTH_K-1:0] dout_K;
    wire [DATA_WIDTH_H-1:0] dout_H;

    rom_K #(.DATA_WIDTH(DATA_WIDTH_K), .MEM_SIZE(MEM_SIZE_K)) ROMK (
        .clk(clk),
        .addr(addr_K),
        .dout(dout_K)
    );

    rom_H #(.DATA_WIDTH(DATA_WIDTH_H), .MEM_SIZE(MEM_SIZE_H)) ROMH (
        .clk(clk),
        .addr(addr_H),
        .dout(dout_H)
    );
    
    always #5 clk = ~clk; 
    
    initial begin
        rst_n = 0;
        addr_K = 0;
        addr_H = 0;
        #20;
        rst_n = 1; 
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            addr_K <= 0;
            addr_H <= 0;
        end
        else begin
            addr_K <= addr_K + 1'b1;
            if(addr_H < MEM_SIZE_H - 1) begin
                addr_H <= addr_H + 1'b1;
               end
            else begin
                addr_H <= 0; 
         end
        end
  end
  
  initial begin
        #500;
   end


endmodule
