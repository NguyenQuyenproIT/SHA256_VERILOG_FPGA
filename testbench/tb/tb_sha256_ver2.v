`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: tb_sha256_ver2
// Module Under Test: sha256_core_ver2
// Description:
//   Ch?y tu?n t? 3 Test Case:
//   1. "quyen"
//   2. "ngoc"
//   3. "nguyen"
//   T? ??ng in giá tr? hash_out ra Tcl Console khi module tính xong.
//////////////////////////////////////////////////////////////////////////////////

module tb_sha256_ver2 ();

    reg          clk;
    reg          rst_n;       // Active-Low Reset (0: Reset, 1: Normal)
    reg          start;
    reg  [511:0] block_in;
    wire         done;
    wire [255:0] hash_out;

    // Kh?i t?o Module SHA-256 Core Ver2
    sha256_core_ver2 uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .block_in(block_in),
        .done(done),
        .hash_out(hash_out)
    );

    // Xung Clock 100MHz (Chu k? 10ns)
    always #5 clk = ~clk;

    // Task ch?y t?ng test case
    task run_test(
        input [511:0]   in_block,
        input [128*8:1] string_name
    );
        begin
            $display("==================================================");
            $display("[TEST CASE] Input: \"%0s\"", string_name);
            block_in = in_block;
            @(posedge clk);
            start = 1'b1;     // Kích xung start
            @(posedge clk);
            start = 1'b0;

            // ??i module tính xong
            @(posedge done);
            @(posedge clk);

            $display("[RESULT]    hash_out = %064h", hash_out);
            $display("==================================================\n");
            
            repeat(5) @(posedge clk);
        end
    endtask

    initial begin
        // 1. Kh?i t?o
        clk      = 0;
        rst_n    = 0;         // Reset
        start    = 0;
        block_in = 0;

        #30;
        rst_n = 1;           // Nh? Reset
        #20;

        // ------------------------------------------------------------
        // CASE 1: "quyen" (5 bytes = 40 bits = 0x28)
        // ------------------------------------------------------------
        run_test(
            {
                8'h71, 8'h75, 8'h79, 8'h65, 8'h6e, // "quyen"
                8'h80,                              // 1-bit padding (0x80)
                400'd0,                             // Zero padding
                64'd40                              // Chi?u dài 40 bits
            },
            "quyen"
        );

        // ------------------------------------------------------------
        // CASE 2: "ngoc" (4 bytes = 32 bits = 0x20)
        // 01101110 01100111 01101111 01100011
        // ------------------------------------------------------------
        run_test(
            {
                8'h6e, 8'h67, 8'h6f, 8'h63,         // "ngoc"
                8'h80,                              // 1-bit padding (0x80)
                408'd0,                             // Zero padding
                64'd32                              // Chi?u dài 32 bits
            },
            "ngoc"
        );

        // ------------------------------------------------------------
        // CASE 3: "nguyen" (6 bytes = 48 bits = 0x30)
        // 01101110 01100111 01110101 01111001 01100101 01101110
        // ------------------------------------------------------------
        run_test(
            {
                8'h6e, 8'h67, 8'h75, 8'h79, 8'h65, 8'h6e, // "nguyen"
                8'h80,                                     // 1-bit padding (0x80)
                392'd0,                                    // Zero padding
                64'd48                                     // Chi?u dài 48 bits
            },
            "nguyen"
        );

        $display(">> HOAN THANH MO PHONG <<");
        #100;
        $finish;
    end

endmodule
