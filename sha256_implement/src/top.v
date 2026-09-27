`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: top
// Target Board: Tang Nano 20K (GW2AR-LV18QN88C8)
// Description:
//   - Tách module chuẩn: gọi uart_top và sha256_core.
//   - FSM nhận 64 Bytes -> băm -> gửi 32 Bytes kết quả chuẩn xác 100%.
//   - LED 16 (RX) và LED 15 (TX) sáng rõ ràng.
//////////////////////////////////////////////////////////////////////////////////

module top (
    input  wire clk,         // PIN 4 (27 MHz)
    input  wire sys_rst_n,   // PIN 88 (Nút S1: Nhấn = 1, Thả = 0)
    input  wire RX_PIN,      // PIN 70
    output wire TX_PIN,      // PIN 69
    output wire led_tx,      // PIN 15 (Active-Low)
    output wire led_rx       // PIN 16 (Active-Low)
);

    // -------------------------------------------------------------
    // 1. MẠCH POWER-ON RESET (Tự động khởi động an toàn)
    // -------------------------------------------------------------
    reg [15:0] por_cnt = 16'd0;
    always @(posedge clk) begin
        if (por_cnt != 16'hFFFF)
            por_cnt <= por_cnt + 16'd1;
    end

    wire sys_reset = (sys_rst_n == 1'b1) || (por_cnt != 16'hFFFF);
    wire rst_n = !sys_reset;

    // -------------------------------------------------------------
    // 2. BỘ ĐIỀU KHIỂN ĐÈN LED (Kéo dài 100ms)
    // -------------------------------------------------------------
    reg [21:0] rx_led_timer = 22'd0;
    reg [21:0] tx_led_timer = 22'd0;

    assign led_rx = (rx_led_timer == 22'd0); // 0 = Sáng, 1 = Tắt
    assign led_tx = (tx_led_timer == 22'd0);

    // -------------------------------------------------------------
    // 3. KHỞI TẠO BỘ UART TỔNG (115200 Baud @ 27MHz)
    // -------------------------------------------------------------
    wire [7:0] rx_data;
    wire       rx_rdy;
    reg  [7:0] tx_data;
    reg        writeEN;
    wire       txBusy;

    uart_top #(
        .CLK_FREQ(27_000_000),
        .BAUDRATE(115200)
    ) u_uart (
        .clk(clk),
        .rst_n(rst_n),
        .rx_pin(RX_PIN),
        .tx_pin(TX_PIN),
        .rx_data(rx_data),
        .rx_rdy(rx_rdy),
        .tx_data(tx_data),
        .tx_wr_en(writeEN),
        .tx_busy(txBusy)
    );

    // -------------------------------------------------------------
    // 4. KHỞI TẠO LÕI SHA-256
    // -------------------------------------------------------------
    reg          sha_start;
    wire         sha_done;
    wire [255:0] sha_hash_out;
    reg  [511:0] sha_block_in;

    sha256_core u_sha256 (
        .clk(clk),
        .rst_n(rst_n),
        .start(sha_start),
        .block_in(sha_block_in),
        .done(sha_done),
        .hash_out(sha_hash_out)
    );

    // -------------------------------------------------------------
    // 5. FSM NHẬN DỮ LIỆU & BĂM (Khớp 100% bản chạy chuẩn)
    // -------------------------------------------------------------
    localparam ST_IDLE      = 3'd0,
               ST_RECV      = 3'd1,
               ST_START_SHA = 3'd2,
               ST_WAIT_SHA  = 3'd3,
               ST_SEND      = 3'd4;

    reg [2:0]   state;
    reg [511:0] rx_block_buf;
    reg [255:0] tx_hash_buf;
    reg [5:0]   rx_byte_cnt;
    reg [5:0]   tx_byte_cnt;
    reg [24:0]  timeout_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= ST_IDLE;
            writeEN      <= 1'b0;
            tx_data      <= 8'h00;
            sha_start    <= 1'b0;
            sha_block_in <= 512'd0;
            rx_block_buf <= 512'd0;
            tx_hash_buf  <= 256'd0;
            rx_byte_cnt  <= 6'd0;
            tx_byte_cnt  <= 6'd0;
            timeout_cnt  <= 25'd0;
            rx_led_timer <= 22'd0;
            tx_led_timer <= 22'd0;
        end else begin
            writeEN   <= 1'b0;
            sha_start <= 1'b0;

            if (rx_led_timer > 0) rx_led_timer <= rx_led_timer - 22'd1;
            if (tx_led_timer > 0) tx_led_timer <= tx_led_timer - 22'd1;

            case (state)
                ST_IDLE: begin
                    rx_byte_cnt <= 6'd0;
                    timeout_cnt <= 25'd0;
                    if (rx_rdy) begin
                        rx_block_buf[511 -: 8] <= rx_data; // Nhận byte 0
                        rx_byte_cnt            <= 6'd1;
                        rx_led_timer           <= 22'd2_700_000; // Giữ LED RX sáng 100ms
                        state                  <= ST_RECV;
                    end
                end

                ST_RECV: begin
                    timeout_cnt <= timeout_cnt + 25'd1;
                    if (timeout_cnt >= 25'd27_000_000) begin
                        // Quá 1 giây không nhận đủ 64 bytes -> Tự reset
                        state <= ST_IDLE;
                    end else if (rx_rdy) begin
                        timeout_cnt  <= 25'd0;
                        rx_led_timer <= 22'd2_700_000;
                        rx_block_buf[511 - (rx_byte_cnt * 8) -: 8] <= rx_data;
                        if (rx_byte_cnt == 6'd63) begin
                            state <= ST_START_SHA; // Đã nhận đủ 64 Bytes
                        end else begin
                            rx_byte_cnt <= rx_byte_cnt + 6'd1;
                        end
                    end
                end

                ST_START_SHA: begin
                    sha_block_in <= rx_block_buf;
                    sha_start    <= 1'b1; // Kích hoạt băm
                    state        <= ST_WAIT_SHA;
                end

                ST_WAIT_SHA: begin
                    if (sha_done) begin
                        tx_hash_buf <= sha_hash_out; // Chốt trực tiếp giá trị băm
                        tx_byte_cnt <= 6'd0;
                        state       <= ST_SEND;
                    end
                end

                ST_SEND: begin
                    if (!txBusy && !writeEN) begin
                        tx_data      <= tx_hash_buf[255 - (tx_byte_cnt * 8) -: 8];
                        writeEN      <= 1'b1;
                        tx_led_timer <= 22'd2_700_000; // Giữ LED TX sáng 100ms khi gửi
                        if (tx_byte_cnt == 6'd31) begin
                            state <= ST_IDLE; // Đã gửi xong 32 Bytes
                        end else begin
                            tx_byte_cnt <= tx_byte_cnt + 6'd1;
                        end
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule




//`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Module Name: top
// Target Board: Tang Nano 20K (GW2AR-LV18QN88C8)
// Description:
//   - LED 16 (PIN 16): Nháy khi NHẬN dữ liệu từ PC (RX).
//   - LED 15 (PIN 15): Nháy khi GỬI dữ liệu về PC (TX).
//   - Tự động Reset & Đồng bộ hóa toàn bộ miền xung 27MHz.
////////////////////////////////////////////////////////////////////////////////

//module top (
//    input  wire clk,         // PIN 4 (27 MHz)
//    input  wire sys_rst_n,   // PIN 88 (Nút S1: Nhấn = 1, Thả = 0)
//    input  wire RX_PIN,      // PIN 70
//    output wire TX_PIN,      // PIN 69
//    output wire led_tx,      // PIN 15 (Active-Low: Sáng khi TX gửi dữ liệu)
//    output wire led_rx       // PIN 16 (Active-Low: Sáng khi RX nhận dữ liệu)
//);

//     -------------------------------------------------------------
//     1. MẠCH TỰ ĐỘNG RESET (POWER-ON RESET)
//     -------------------------------------------------------------
//    reg [15:0] por_cnt = 16'd0;
//    always @(posedge clk) begin
//        if (por_cnt != 16'hFFFF)
//            por_cnt <= por_cnt + 16'd1;
//    end

//    wire sys_reset = (sys_rst_n == 1'b1) || (por_cnt != 16'hFFFF);
//    wire rst_n = !sys_reset;

//     -------------------------------------------------------------
//     2. BỘ ĐIỀU KHIỂN ĐÈN LED (KÉO DÀI XUNG ĐỂ MẮT NHÌN RÕ)
//     -------------------------------------------------------------
//    reg [21:0] rx_led_timer = 22'd0;
//    reg [21:0] tx_led_timer = 22'd0;

//     LED Active-Low (Mức 0 = Sáng, Mức 1 = Tắt)
//    assign led_rx = (rx_led_timer == 22'd0);
//    assign led_tx = (tx_led_timer == 22'd0);

//     -------------------------------------------------------------
//     3. BỘ UART RX (234 CLOCK/BIT = 115200 BAUD @ 27MHz)
//     -------------------------------------------------------------
//    localparam CLKS_PER_BIT = 16'd234;

//    reg rx_sync1, rx_sync2;
//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            rx_sync1 <= 1'b1;
//            rx_sync2 <= 1'b1;
//        end else begin
//            rx_sync1 <= RX_PIN;
//            rx_sync2 <= rx_sync1;
//        end
//    end

//    localparam RX_IDLE  = 2'd0,
//               RX_START = 2'd1,
//               RX_DATA  = 2'd2,
//               RX_STOP  = 2'd3;

//    reg [1:0]  rx_state;
//    reg [15:0] rx_clk_cnt;
//    reg [2:0]  rx_bit_idx;
//    reg [7:0]  rx_byte_buf;
//    reg [7:0]  rx_data;
//    reg        rx_rdy;

//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            rx_state     <= RX_IDLE;
//            rx_rdy       <= 1'b0;
//            rx_data      <= 8'h00;
//            rx_clk_cnt   <= 16'd0;
//            rx_bit_idx   <= 3'd0;
//            rx_byte_buf  <= 8'h00;
//            rx_led_timer <= 22'd0;
//        end else begin
//            rx_rdy <= 1'b0;

//            if (rx_led_timer > 0)
//                rx_led_timer <= rx_led_timer - 22'd1;

//            case (rx_state)
//                RX_IDLE: begin
//                    rx_clk_cnt <= 16'd0;
//                    rx_bit_idx <= 3'd0;
//                    if (!rx_sync2) rx_state <= RX_START;
//                end

//                RX_START: begin
//                    if (rx_clk_cnt == (CLKS_PER_BIT / 2)) begin
//                        if (!rx_sync2) begin
//                            rx_clk_cnt <= 16'd0;
//                            rx_state   <= RX_DATA;
//                        end else begin
//                            rx_state <= RX_IDLE;
//                        end
//                    end else begin
//                        rx_clk_cnt <= rx_clk_cnt + 16'd1;
//                    end
//                end

//                RX_DATA: begin
//                    if (rx_clk_cnt == CLKS_PER_BIT - 1) begin
//                        rx_clk_cnt              <= 16'd0;
//                        rx_byte_buf[rx_bit_idx] <= rx_sync2;
//                        if (rx_bit_idx == 3'd7) begin
//                            rx_state <= RX_STOP;
//                        end else begin
//                            rx_bit_idx <= rx_bit_idx + 3'd1;
//                        end
//                    end else begin
//                        rx_clk_cnt <= rx_clk_cnt + 16'd1;
//                    end
//                end

//                RX_STOP: begin
//                    if (rx_clk_cnt == CLKS_PER_BIT - 1) begin
//                        rx_data      <= rx_byte_buf;
//                        rx_rdy       <= 1'b1;
//                        rx_led_timer <= 22'd2_700_000; // Giữ LED RX sáng 100ms khi nhận
//                        rx_state     <= RX_IDLE;
//                    end else begin
//                        rx_clk_cnt <= rx_clk_cnt + 16'd1;
//                    end
//                end

//                default: rx_state <= RX_IDLE;
//            endcase
//        end
//    end

//     -------------------------------------------------------------
//     4. BỘ UART TX (GỬI DỮ LIỆU)
//     -------------------------------------------------------------
//    localparam TX_IDLE  = 2'd0,
//               TX_START = 2'd1,
//               TX_DATA  = 2'd2,
//               TX_STOP  = 2'd3;

//    reg [1:0]  tx_state;
//    reg [15:0] tx_clk_cnt;
//    reg [2:0]  tx_bit_idx;
//    reg [7:0]  tx_data;
//    reg [7:0]  tx_shift_buf;
//    reg        writeEN;
//    reg        tx_pin_reg;

//    assign TX_PIN = tx_pin_reg;
//    wire txBusy = (tx_state != TX_IDLE) || writeEN;

//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            tx_state     <= TX_IDLE;
//            tx_pin_reg   <= 1'b1;
//            tx_clk_cnt   <= 16'd0;
//            tx_bit_idx   <= 3'd0;
//            tx_shift_buf <= 8'h00;
//            tx_led_timer <= 22'd0;
//        end else begin
//            if (tx_led_timer > 0)
//                tx_led_timer <= tx_led_timer - 22'd1;

//            case (tx_state)
//                TX_IDLE: begin
//                    tx_pin_reg <= 1'b1;
//                    tx_clk_cnt <= 16'd0;
//                    tx_bit_idx <= 3'd0;
//                    if (writeEN) begin
//                        tx_shift_buf <= tx_data;
//                        tx_pin_reg   <= 1'b0; // Start bit
//                        tx_led_timer <= 22'd2_700_000; // Giữ LED TX sáng 100ms khi gửi
//                        tx_state     <= TX_START;
//                    end
//                end

//                TX_START: begin
//                    tx_pin_reg <= 1'b0;
//                    if (tx_clk_cnt == CLKS_PER_BIT - 1) begin
//                        tx_clk_cnt <= 16'd0;
//                        tx_pin_reg <= tx_shift_buf[0];
//                        tx_state   <= TX_DATA;
//                    end else begin
//                        tx_clk_cnt <= tx_clk_cnt + 16'd1;
//                    end
//                end

//                TX_DATA: begin
//                    tx_pin_reg <= tx_shift_buf[tx_bit_idx];
//                    if (tx_clk_cnt == CLKS_PER_BIT - 1) begin
//                        tx_clk_cnt <= 16'd0;
//                        if (tx_bit_idx == 3'd7) begin
//                            tx_pin_reg <= 1'b1; // Stop bit
//                            tx_state   <= TX_STOP;
//                        end else begin
//                            tx_bit_idx <= tx_bit_idx + 3'd1;
//                        end
//                    end else begin
//                        tx_clk_cnt <= tx_clk_cnt + 16'd1;
//                    end
//                end

//                TX_STOP: begin
//                    tx_pin_reg <= 1'b1;
//                    if (tx_clk_cnt == CLKS_PER_BIT - 1) begin
//                        tx_state <= TX_IDLE;
//                    end else begin
//                        tx_clk_cnt <= tx_clk_cnt + 16'd1;
//                    end
//                end

//                default: tx_state <= TX_IDLE;
//            endcase
//        end
//    end

//     -------------------------------------------------------------
//     5. KHỞI TẠO SHA-256 CORE
//     -------------------------------------------------------------
//    reg          sha_start;
//    wire         sha_done;
//    wire [255:0] sha_hash_out;
//    reg  [511:0] sha_block_in;

//    sha256_core u_sha256 (
//        .clk(clk),
//        .rst_n(rst_n),
//        .start(sha_start),
//        .block_in(sha_block_in),
//        .done(sha_done),
//        .hash_out(sha_hash_out)
//    );

//     -------------------------------------------------------------
//     6. FSM NHẬN DỮ LIỆU & TỰ ĐỘNG TIMEOUT
//     -------------------------------------------------------------
//    localparam ST_IDLE      = 3'd0,
//               ST_RECV      = 3'd1,
//               ST_START_SHA = 3'd2,
//               ST_WAIT_SHA  = 3'd3,
//               ST_SEND      = 3'd4;

//    reg [2:0]   state;
//    reg [511:0] rx_block_buf;
//    reg [255:0] tx_hash_buf;
//    reg [5:0]   rx_byte_cnt;
//    reg [5:0]   tx_byte_cnt;
//    reg [24:0]  timeout_cnt; // Timeout 1s nếu gửi thiếu byte

//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            state        <= ST_IDLE;
//            writeEN      <= 1'b0;
//            tx_data      <= 8'h00;
//            sha_start    <= 1'b0;
//            sha_block_in <= 512'd0;
//            rx_block_buf <= 512'd0;
//            tx_hash_buf  <= 256'd0;
//            rx_byte_cnt  <= 6'd0;
//            tx_byte_cnt  <= 6'd0;
//            timeout_cnt  <= 25'd0;
//        end else begin
//            writeEN   <= 1'b0;
//            sha_start <= 1'b0;

//            case (state)
//                ST_IDLE: begin
//                    rx_byte_cnt <= 6'd0;
//                    timeout_cnt <= 25'd0;
//                    if (rx_rdy) begin
//                        rx_block_buf[511 -: 8] <= rx_data; // Nhận byte 0
//                        rx_byte_cnt            <= 6'd1;
//                        state                  <= ST_RECV;
//                    end
//                end

//                ST_RECV: begin
//                    timeout_cnt <= timeout_cnt + 25'd1;
//                    if (timeout_cnt >= 25'd27_000_000) begin
         //               Quá 1 giây không nhận đủ byte -> tự reset về IDLE
//                        state <= ST_IDLE;
//                    end else if (rx_rdy) begin
//                        timeout_cnt <= 25'd0;
//                        rx_block_buf[511 - (rx_byte_cnt * 8) -: 8] <= rx_data;
//                        if (rx_byte_cnt == 6'd63) begin
//                            state <= ST_START_SHA; // Đã nhận đủ 64 Bytes
//                        end else begin
//                            rx_byte_cnt <= rx_byte_cnt + 6'd1;
//                        end
//                    end
//                end

//                ST_START_SHA: begin
//                    sha_block_in <= rx_block_buf;
//                    sha_start    <= 1'b1; // Kích hoạt băm
//                    state        <= ST_WAIT_SHA;
//                end

//                ST_WAIT_SHA: begin
//                    if (sha_done) begin
//                        tx_hash_buf <= sha_hash_out;
//                        tx_byte_cnt <= 6'd0;
//                        state       <= ST_SEND;
//                    end
//                end

//                ST_SEND: begin
//                    if (!txBusy && !writeEN) begin
//                        tx_data <= tx_hash_buf[255 - (tx_byte_cnt * 8) -: 8];
//                        writeEN <= 1'b1;
//                        if (tx_byte_cnt == 6'd31) begin
//                            state <= ST_IDLE; // Đã gửi xong 32 Bytes
//                        end else begin
//                            tx_byte_cnt <= tx_byte_cnt + 6'd1;
//                        end
//                    end
//                end

//                default: state <= ST_IDLE;
//            endcase
//        end
//    end

//endmodule
