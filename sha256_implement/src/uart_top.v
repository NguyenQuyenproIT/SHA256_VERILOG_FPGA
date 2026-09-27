`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: uart_top
// Description: Giao diện UART Full-Duplex dùng chung cho mọi dự án
//////////////////////////////////////////////////////////////////////////////////

module uart_top #(
    parameter CLK_FREQ = 27_000_000,
    parameter BAUDRATE = 115200
)(
    input  wire       clk,
    input  wire       rst_n,
    
    // Physical UART Pins
    input  wire       rx_pin,
    output wire       tx_pin,
    
    // RX Interface
    output wire [7:0] rx_data,
    output wire       rx_rdy,
    
    // TX Interface
    input  wire [7:0] tx_data,
    input  wire       tx_wr_en,
    output wire       tx_busy
);

    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUDRATE(BAUDRATE)
    ) u_uart_rx (
        .clk(clk),
        .rst_n(rst_n),
        .rx_pin(rx_pin),
        .rx_data(rx_data),
        .rx_rdy(rx_rdy)
    );

    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUDRATE(BAUDRATE)
    ) u_uart_tx (
        .clk(clk),
        .rst_n(rst_n),
        .tx_data(tx_data),
        .tx_wr_en(tx_wr_en),
        .tx_busy(tx_busy),
        .tx_pin(tx_pin)
    );

endmodule