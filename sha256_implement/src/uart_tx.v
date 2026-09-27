`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: uart_tx
// Description: Module truyền UART 8-N-1 tái sử dụng (Baudrate 115200 @ 27MHz)
//////////////////////////////////////////////////////////////////////////////////

module uart_tx #(
    parameter CLK_FREQ = 27_000_000,
    parameter BAUDRATE = 115200
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] tx_data,
    input  wire       tx_wr_en,
    output wire       tx_busy,
    output reg        tx_pin
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUDRATE; // 234 clock/bit

    localparam TX_IDLE  = 2'd0,
               TX_START = 2'd1,
               TX_DATA  = 2'd2,
               TX_STOP  = 2'd3;

    reg [1:0]  tx_state;
    reg [15:0] tx_clk_cnt;
    reg [2:0]  tx_bit_idx;
    reg [7:0]  tx_shift_buf;

    assign tx_busy = (tx_state != TX_IDLE) || tx_wr_en;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state     <= TX_IDLE;
            tx_pin       <= 1'b1;
            tx_clk_cnt   <= 16'd0;
            tx_bit_idx   <= 3'd0;
            tx_shift_buf <= 8'h00;
        end else begin
            case (tx_state)
                TX_IDLE: begin
                    tx_pin     <= 1'b1;
                    tx_clk_cnt <= 16'd0;
                    tx_bit_idx <= 3'd0;
                    if (tx_wr_en) begin
                        tx_shift_buf <= tx_data;
                        tx_pin       <= 1'b0; // Start bit
                        tx_state     <= TX_START;
                    end
                end

                TX_START: begin
                    tx_pin <= 1'b0;
                    if (tx_clk_cnt == CLKS_PER_BIT - 1) begin
                        tx_clk_cnt <= 16'd0;
                        tx_pin     <= tx_shift_buf[0];
                        tx_state   <= TX_DATA;
                    end else begin
                        tx_clk_cnt <= tx_clk_cnt + 16'd1;
                    end
                end

                TX_DATA: begin
                    tx_pin <= tx_shift_buf[tx_bit_idx];
                    if (tx_clk_cnt == CLKS_PER_BIT - 1) begin
                        tx_clk_cnt <= 16'd0;
                        if (tx_bit_idx == 3'd7) begin
                            tx_pin   <= 1'b1; // Stop bit
                            tx_state <= TX_STOP;
                        end else begin
                            tx_bit_idx <= tx_bit_idx + 3'd1;
                        end
                    end else begin
                        tx_clk_cnt <= tx_clk_cnt + 16'd1;
                    end
                end

                TX_STOP: begin
                    tx_pin <= 1'b1;
                    if (tx_clk_cnt == CLKS_PER_BIT - 1) begin
                        tx_state <= TX_IDLE;
                    end else begin
                        tx_clk_cnt <= tx_clk_cnt + 16'd1;
                    end
                end

                default: tx_state <= TX_IDLE;
            endcase
        end
    end

endmodule
