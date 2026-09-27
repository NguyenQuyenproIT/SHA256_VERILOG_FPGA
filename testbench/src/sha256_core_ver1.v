`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////

module sha256_core(
    input  wire         clk,
    input  wire         rst,
    input  wire         start,        
    input  wire [511:0] block_in,     // data input 512-bit (16 word 32-bit) // ASCII
    output reg          done,         // caculator-complete
    output reg  [255:0] hash_out      // results hash 256-bit
);
    reg [31:0] W [0:63];  
    reg [31:0] a,b,c,d,e,f,g,h;  // 8 reg loop
    reg [31:0] H_reg [0:7];      // value H after each block

    reg [6:0] round;

    wire [31:0] K_value;
    reg  [5:0]  K_addr; // 00 - 63
// read ROM - K (64 word)
    rom_K dut1 (
        .clk(clk),
        .addr(K_addr),
        .dout(K_value)
    );

    wire [31:0] H_value;
    reg  [2:0]  H_addr;
// 8 WORD
    rom_H dut2 (
        .clk(clk),
        .addr(H_addr),
        .dout(H_value)
    );
    
    localparam IDLE            = 4'd0,
			   LOAD_H_SET      = 4'd1,   // load a-h ban dau
			   LOAD_H_CAPTURE  = 4'd2,
			   LOAD_H_DONE     = 4'd3,
			   LOAD_W0         = 4'd4,   // load 16 word dau vào
			   EXPAND_CALC     = 4'd5,   // tính W[t] t?m
			   EXPAND_W        = 4'd6,   // ghi W[t] vào register
			   //COMPRESS_CALC   = 3'd5,   // tính T1, T2, a_next … h_next
			   COMPRESS_CALC_1  = 4'd7,
			   COMPRESS_CALC_2_WAIT = 4'd8,
			   COMPRESS_CALC_2  = 4'd9,
			   
			   
			   COMPRESS_UPDATE = 4'd10,   // ghi a-h
			   FINISH          = 4'd11;   // xuat ket qua

    reg [3:0] status = IDLE;
    reg [2:0] h_idx;
    reg [6:0] w_idx;
    
    reg [31:0] t_S0, t_S1, t_ch, t_temp1, t_maj, t_temp2;
    integer i;
    
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            status <= IDLE;
            done <= 1'b0;
            {a,b,c,d,e,f,g,h} <= 0;
			h_idx <= 0; 
			H_addr <= 0; 
			K_addr <= 0;
			round <= 0; 
			w_idx <= 0;      
          end
      else begin  
          case(status)   
          
          IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        h_idx  <= 3'd0;
                        H_addr <= 3'd0;         // request rom[0] now (dout valid next posedge)
                        status <= LOAD_H_SET;
                    end
                end
                
                // gi? addr ?n ??nh; sang posedge k? s? capture H_value
             LOAD_H_SET: begin
                    // nothing else here, just wait for next clock edge where H_value is valid
                    status <= LOAD_H_CAPTURE;
                end
                
                // capture the H_value corresponding to the previously set H_addr
               LOAD_H_CAPTURE: begin
                    H_reg[h_idx] <= H_value;   // sample ROM output for addr set on previous cycle
                    if (h_idx == 3'd7) begin
                        status <= LOAD_H_DONE; // all 8 words captured
                    end else begin
                        H_addr <= h_idx + 1;   // request next ROM word (will be valid next posedge)
                        h_idx  <= h_idx + 1;
                        status <= LOAD_H_SET;  // go to SET so next cycle we'll capture it
                    end
                end
                
               LOAD_H_DONE: begin
                    // H_reg[0..7] now valid and stable
                    status <= LOAD_W0;
                end
    

                LOAD_W0: begin // 16 value from 512 value input
                    for (i=0; i<16; i=i+1) begin
                    
                  W[i] <= block_in[511 - i*32 -: 32];
                       end
                    w_idx <= 16;
//                    t_S0 <= ( {W[w_idx-15][6:0],  W[w_idx-15][31:7]} ) ^ ( {W[w_idx-15][17:0], W[w_idx-15][31:18]} ) ^ ({3'b0, W[w_idx-15][31:3]} );
//                    t_S1 <= ( {W[w_idx-2][16:0],  W[w_idx-2][31:17]} ) ^ ( {W[w_idx-2][18:0],  W[w_idx-2][31:19]} ) ^ ( {10'b0, W[w_idx-2][31:10]} );
					
					 status <= EXPAND_CALC;
                end
 
				EXPAND_CALC: begin
						t_S0 <= ( {W[w_idx-15][6:0],  W[w_idx-15][31:7]} ) ^ ( {W[w_idx-15][17:0], W[w_idx-15][31:18]} ) ^ ({3'b0, W[w_idx-15][31:3]});
						t_S1 <= ( {W[w_idx-2][16:0],  W[w_idx-2][31:17]} ) ^ ( {W[w_idx-2][18:0],  W[w_idx-2][31:19]} ) ^ ( {10'b0, W[w_idx-2][31:10]});
				
				status <= EXPAND_W;
					
				end

                EXPAND_W: begin
                    
                    W[w_idx] <= W[w_idx-16] + t_S0 + W[w_idx-7] + t_S1;

                    if (w_idx == 7'd63) begin // value 32 bit
                     {a,b,c,d,e,f,g,h} <= {H_reg[0], H_reg[1], H_reg[2], H_reg[3], H_reg[4], H_reg[5], H_reg[6], H_reg[7]};
                        round <= 0;
                        K_addr <= 0; // index 0..63 ROM
                        status <= COMPRESS_CALC_1;
                    end else begin
                        w_idx <= w_idx + 1;
						status <= EXPAND_CALC;
                    end
                end
				
				COMPRESS_CALC_1: begin
                                t_S1 <= ({e[5:0],  e[31:6]}) ^ ({e[10:0], e[31:11]}) ^ ({e[24:0], e[31:25]});
                                t_ch <= (e & f) ^ ((~e) & g);
                                t_S0 <= ({a[1:0], a[31:2]}) ^ ({a[12:0], a[31:13]}) ^ ({a[21:0], a[31:22]});
                                t_maj <= (a & b) ^ (a & c) ^ (b & c);
                                status <= COMPRESS_CALC_2_WAIT;
                        end
                        
                        COMPRESS_CALC_2_WAIT: begin
                                  status <= COMPRESS_CALC_2; // ch? ch? ROM ?n ??nh
                                end
                     
               COMPRESS_CALC_2: begin
                      t_temp1 <= h + t_S1 + t_ch + K_value + W[round];
                      t_temp2 <= t_S0 + t_maj;
                      status <= COMPRESS_UPDATE;
			   end	
			  
               COMPRESS_UPDATE: begin
                    h <= g;
                    g <= f;
                    f <= e;
                    e <= d + t_temp1;
                    d <= c;
                    c <= b;
                    b <= a;
                    a <= t_temp1 + t_temp2;
					
                    if(round == 6'd63) begin
                        status <= FINISH;
                    end 
                    else begin
						K_addr <= round + 1;
                        round <= round + 1;
						status <= COMPRESS_CALC_1;
                    end
                end

                FINISH: begin
                    H_reg[0] <= H_reg[0] + a;
                    H_reg[1] <= H_reg[1] + b;
                    H_reg[2] <= H_reg[2] + c;
                    H_reg[3] <= H_reg[3] + d;
                    H_reg[4] <= H_reg[4] + e;
                    H_reg[5] <= H_reg[5] + f;
                    H_reg[6] <= H_reg[6] + g;
                    H_reg[7] <= H_reg[7] + h;
                     hash_out <= { H_reg[0] + a, H_reg[1] + b, H_reg[2] + c, H_reg[3] + d, H_reg[4] + e, H_reg[5] + f, H_reg[6] + g, H_reg[7] + h };
                    done <= 1'b1;
                    status <= IDLE;
                end

                default: status <= IDLE;
            endcase
        end
     end
endmodule