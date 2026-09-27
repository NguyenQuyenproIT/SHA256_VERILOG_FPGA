`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////

module rom_K #(parameter DATA_WIDTH = 32, parameter MEM_SIZE = 64)(
    input clk,
    input [$clog2(MEM_SIZE)-1:0] addr,
    output reg [DATA_WIDTH-1:0] dout
);
    reg [DATA_WIDTH-1:0] rom [0:MEM_SIZE-1];
    
    initial begin
        $readmemh("hang_so_tron_K.mem", rom);
    end
    
    always @(posedge clk) begin
        dout <= rom[addr];
    end
endmodule

module rom_H #(parameter DATA_WIDTH = 32, parameter MEM_SIZE = 8)(
    input clk,
    input [$clog2(MEM_SIZE)-1:0] addr,
    output reg [DATA_WIDTH-1:0] dout
);
    reg [DATA_WIDTH-1:0] rom [0:MEM_SIZE-1];
    
    initial begin
        $readmemh("initial_hash_values.mem", rom);
    end
    
    always @(posedge clk) begin
        dout <= rom[addr];
    end
endmodule
