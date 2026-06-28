`timescale 1ns / 1ps


module tb_font_rom;
    reg          clk = 0;
    reg [9:0]    addr = 0;       // 0~1023 (128자 * 8픽셀 * 1바이트)
    wire [7:0]    data;        // 해당 행의 8픽셀 비트맵

    font_rom uut(.clk(clk), .addr(addr), .data(data));
    always #5 clk = ~clk;
    initial begin
        // 'A' = ASCII 65, addr = 65*8 = 520~527

        #10 addr = 10'd520;
        #10 addr = 10'd521;
        #10 addr = 10'd522;        
        #10 addr = 10'd523;
        #10 addr = 10'd524;
        #10 addr = 10'd525;
        #10 addr = 10'd526;
        #10 addr = 10'd527;


        #100 $finish;
    end


endmodule
