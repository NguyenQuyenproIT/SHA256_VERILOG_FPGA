`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: uart_rx
// Description: Module nhận UART 8-N-1 tái sử dụng (Baudrate 115200 @ 27MHz)
//////////////////////////////////////////////////////////////////////////////////

module uart_rx #(
    parameter CLK_FREQ = 27_000_000,
    parameter BAUDRATE = 115200
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx_pin,
    output reg  [7:0] rx_data,
    output reg        rx_rdy
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUDRATE; // 234 clock/bit

    reg rx_sync1, rx_sync2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= rx_pin;
            rx_sync2 <= rx_sync1;
        end
    end

    localparam RX_IDLE  = 2'd0,
               RX_START = 2'd1,
               RX_DATA  = 2'd2,
               RX_STOP  = 2'd3;

    reg [1:0]  rx_state;
    reg [15:0] rx_clk_cnt;
    reg [2:0]  rx_bit_idx;
    reg [7:0]  rx_byte_buf;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state    <= RX_IDLE;
            rx_rdy      <= 1'b0;
            rx_data     <= 8'h00;
            rx_clk_cnt  <= 16'd0;
            rx_bit_idx  <= 3'd0;
            rx_byte_buf <= 8'h00;
        end else begin
            rx_rdy <= 1'b0;

            case (rx_state)
                RX_IDLE: begin
                    rx_clk_cnt <= 16'd0;
                    rx_bit_idx <= 3'd0;
                    if (!rx_sync2) rx_state <= RX_START;
                end

                RX_START: begin
                    if (rx_clk_cnt == (CLKS_PER_BIT / 2)) begin
                        if (!rx_sync2) begin
                            rx_clk_cnt <= 16'd0;
                            rx_state   <= RX_DATA;
                        end else begin
                            rx_state <= RX_IDLE;
                        end
                    end else begin
                        rx_clk_cnt <= rx_clk_cnt + 16'd1;
                    end
                end

                RX_DATA: begin
                    if (rx_clk_cnt == CLKS_PER_BIT - 1) begin
                        rx_clk_cnt              <= 16'd0;
                        rx_byte_buf[rx_bit_idx] <= rx_sync2;
                        if (rx_bit_idx == 3'd7) begin
                            rx_state <= RX_STOP;
                        end else begin
                            rx_bit_idx <= rx_bit_idx + 3'd1;
                        end
                    end else begin
                        rx_clk_cnt <= rx_clk_cnt + 16'd1;
                    end
                end

                RX_STOP: begin
                    if (rx_clk_cnt == CLKS_PER_BIT - 1) begin
                        rx_data  <= rx_byte_buf;
                        rx_rdy   <= 1'b1;
                        rx_state <= RX_IDLE;
                    end else begin
                        rx_clk_cnt <= rx_clk_cnt + 16'd1;
                    end
                end

                default: rx_state <= RX_IDLE;
            endcase
        end
    end

endmodule
