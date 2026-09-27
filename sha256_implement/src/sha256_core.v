`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: sha256_core
// Description:
//   SHA-256 Core chuẩn xác cho FPGA Kit (2-Stage FSM: Expand W -> Compress 64 Rounds).
//   - Tự chứa hằng số K_t và H_init (tổng hợp 100% thành công trên mọi dòng FPGA).
//   - Lưu mảng W[0:63] chuẩn, xử lý băm khối 512-bit (Big-Endian).
//////////////////////////////////////////////////////////////////////////////////

module sha256_core (
    input  wire         clk,
    input  wire         rst_n,      // Active-low asynchronous reset (0 = Reset)
    input  wire         start,      // 1-pulse start signal
    input  wire [511:0] block_in,   // 512-bit block message (Big-Endian)
    output reg          done,       // 1-pulse active when hash is ready
    output reg  [255:0] hash_out    // 256-bit hash result
);

    // Initial Hash Constants (H0 - H7)
    localparam [31:0] H0_INIT = 32'h6a09e667,
                      H1_INIT = 32'hbb67ae85,
                      H2_INIT = 32'h3c6ef372,
                      H3_INIT = 32'ha54ff53a,
                      H4_INIT = 32'h510e527f,
                      H5_INIT = 32'h9b05688c,
                      H6_INIT = 32'h1f83d9ab,
                      H7_INIT = 32'h5be0cd19;

    // FSM States
    localparam [1:0] ST_IDLE   = 2'd0,
                     ST_EXPAND = 2'd1,
                     ST_ROUNDS = 2'd2,
                     ST_FINISH = 2'd3;

    reg [1:0]  state;
    reg [6:0]  w_idx;          // 16 to 63
    reg [5:0]  round_cnt;      // 0 to 63

    // Working variables a..h and Hash initial registers H_reg[0..7]
    reg [31:0] a, b, c, d, e, f, g, h;
    reg [31:0] H_reg [0:7];

    // Message schedule array W[0:63]
    reg [31:0] W [0:63];

    integer i;

    // Right Rotate 32-bit function
    function [31:0] ror;
        input [31:0] val;
        input integer shift;
        begin
            ror = (val >> shift) | (val << (32 - shift));
        end
    endfunction

    // Message expansion Sigma functions for W[w_idx]
    wire [31:0] s0 = ror(W[w_idx-15], 7)  ^ ror(W[w_idx-15], 18)  ^ (W[w_idx-15] >> 3);
    wire [31:0] s1 = ror(W[w_idx-2], 17)  ^ ror(W[w_idx-2], 19)  ^ (W[w_idx-2] >> 10);

    // Compression function components
    wire [31:0] S1  = ror(e, 6) ^ ror(e, 11) ^ ror(e, 25);
    wire [31:0] ch  = (e & f) ^ ((~e) & g);
    wire [31:0] S0  = ror(a, 2) ^ ror(a, 13) ^ ror(a, 22);
    wire [31:0] maj = (a & b) ^ (a & c) ^ (b & c);

    // Round Constants K_t Lookup Table (Combinational ROM)
    reg [31:0] k_val;
    always @(*) begin
        case (round_cnt)
            6'd0:  k_val = 32'h428a2f98; 6'd1:  k_val = 32'h71374491; 6'd2:  k_val = 32'hb5c0fbcf; 6'd3:  k_val = 32'he9b5dba5;
            6'd4:  k_val = 32'h3956c25b; 6'd5:  k_val = 32'h59f111f1; 6'd6:  k_val = 32'h923f82a4; 6'd7:  k_val = 32'hab1c5ed5;
            6'd8:  k_val = 32'hd807aa98; 6'd9:  k_val = 32'h12835b01; 6'd10: k_val = 32'h243185be; 6'd11: k_val = 32'h550c7dc3;
            6'd12: k_val = 32'h72be5d74; 6'd13: k_val = 32'h80deb1fe; 6'd14: k_val = 32'h9bdc06a7; 6'd15: k_val = 32'hc19bf174;
            6'd16: k_val = 32'he49b69c1; 6'd17: k_val = 32'hefbe4786; 6'd18: k_val = 32'h0fc19dc6; 6'd19: k_val = 32'h240ca1cc;
            6'd20: k_val = 32'h2de92c6f; 6'd21: k_val = 32'h4a7484aa; 6'd22: k_val = 32'h5cb0a9dc; 6'd23: k_val = 32'h76f988da;
            6'd24: k_val = 32'h983e5152; 6'd25: k_val = 32'ha831c66d; 6'd26: k_val = 32'hb00327c8; 6'd27: k_val = 32'hbf597fc7;
            6'd28: k_val = 32'hc6e00bf3; 6'd29: k_val = 32'hd5a79147; 6'd30: k_val = 32'h06ca6351; 6'd31: k_val = 32'h14292967;
            6'd32: k_val = 32'h27b70a85; 6'd33: k_val = 32'h2e1b2138; 6'd34: k_val = 32'h4d2c6dfc; 6'd35: k_val = 32'h53380d13;
            6'd36: k_val = 32'h650a7354; 6'd37: k_val = 32'h766a0abb; 6'd38: k_val = 32'h81c2c92e; 6'd39: k_val = 32'h92722c85;
            6'd40: k_val = 32'ha2bfe8a1; 6'd41: k_val = 32'ha81a664b; 6'd42: k_val = 32'hc24b8b70; 6'd43: k_val = 32'hc76c51a3;
            6'd44: k_val = 32'hd192e819; 6'd45: k_val = 32'hd6990624; 6'd46: k_val = 32'hf40e3585; 6'd47: k_val = 32'h106aa070;
            6'd48: k_val = 32'h19a4c116; 6'd49: k_val = 32'h1e376c08; 6'd50: k_val = 32'h2748774c; 6'd51: k_val = 32'h34b0bcb5;
            6'd52: k_val = 32'h391c0cb3; 6'd53: k_val = 32'h4ed8aa4a; 6'd54: k_val = 32'h5b9cca4f; 6'd55: k_val = 32'h682e6ff3;
            6'd56: k_val = 32'h748f82ee; 6'd57: k_val = 32'h78a5636f; 6'd58: k_val = 32'h84c87814; 6'd59: k_val = 32'h8cc70208;
            6'd60: k_val = 32'h90befffa; 6'd61: k_val = 32'ha4506ceb; 6'd62: k_val = 32'hbef9a3f7; 6'd63: k_val = 32'hc67178f2;
            default: k_val = 32'h00000000;
        endcase
    end

    // Intermediate Compression Values T1 and T2
    wire [31:0] t1 = h + S1 + ch + k_val + W[round_cnt];
    wire [31:0] t2 = S0 + maj;

    // FSM & Core Computation Process
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= ST_IDLE;
            done      <= 1'b0;
            hash_out  <= 256'd0;
            w_idx     <= 7'd0;
            round_cnt <= 6'd0;
            {a, b, c, d, e, f, g, h} <= 0;
            for (i = 0; i < 8; i = i + 1)  H_reg[i] <= 32'd0;
            for (i = 0; i < 64; i = i + 1) W[i]     <= 32'd0;
        end else begin
            case (state)
                ST_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // 1. Nạp hằng số khởi tạo H[0..7]
                        H_reg[0] <= H0_INIT; H_reg[1] <= H1_INIT;
                        H_reg[2] <= H2_INIT; H_reg[3] <= H3_INIT;
                        H_reg[4] <= H4_INIT; H_reg[5] <= H5_INIT;
                        H_reg[6] <= H6_INIT; H_reg[7] <= H7_INIT;

                        // 2. Nạp giá trị khởi tạo a..h
                        a <= H0_INIT; b <= H1_INIT;
                        c <= H2_INIT; d <= H3_INIT;
                        e <= H4_INIT; f <= H5_INIT;
                        g <= H6_INIT; h <= H7_INIT;

                        // 3. Nạp 16 từ đầu tiên W[0..15] từ 512-bit input (Big-Endian)
                        for (i = 0; i < 16; i = i + 1) begin
                            W[i] <= block_in[511 - (i * 32) -: 32];
                        end

                        w_idx <= 7'd16;
                        state <= ST_EXPAND;
                    end
                end

                ST_EXPAND: begin
                    // Mở rộng mảng W từ W[16] đến W[63] (1 cycle / word)
                    W[w_idx] <= W[w_idx-16] + s0 + W[w_idx-7] + s1;
                    if (w_idx == 7'd63) begin
                        round_cnt <= 6'd0;
                        state     <= ST_ROUNDS;
                    end else begin
                        w_idx <= w_idx + 7'd1;
                    end
                end

                ST_ROUNDS: begin
                    // Tính nén 64 round (1 cycle / round)
                    a <= t1 + t2;
                    b <= a;
                    c <= b;
                    d <= c;
                    e <= d + t1;
                    f <= e;
                    g <= f;
                    h <= g;

                    if (round_cnt == 6'd63) begin
                        state <= ST_FINISH;
                    end else begin
                        round_cnt <= round_cnt + 6'd1;
                    end
                end

                ST_FINISH: begin
                    // Xuất mã băm cuối cùng và bật tín hiệu done
                    hash_out <= {
                        H_reg[0] + a,
                        H_reg[1] + b,
                        H_reg[2] + c,
                        H_reg[3] + d,
                        H_reg[4] + e,
                        H_reg[5] + f,
                        H_reg[6] + g,
                        H_reg[7] + h
                    };
                    done  <= 1'b1;
                    state <= ST_IDLE;
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
