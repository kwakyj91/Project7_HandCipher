`timescale 1ns / 1ps


module font_rom(
    
    input wire          clk,
    input wire [9:0]    addr,       // 0~1023 (128자 * 8픽셀 * 1바이트)
    output reg [7:0]    data        // 해당 행의 8픽셀 비트맵

    );

    (* rom_style = "block" *) reg [7:0] mem[0:1023]; // 128자 * 8픽셀 * 1바이트

    initial begin
        $readmemh("font_rom.mem", mem);

    end

    always @(posedge clk) begin
        data <= mem[addr];
    end


endmodule
