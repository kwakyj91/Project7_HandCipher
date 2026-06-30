`timescale 1ns / 1ps

module tb_npu_patterns;
    reg clk = 1'b0;
    reg reset_p = 1'b1;
    reg start = 1'b0;
    wire [9:0] canvas_addrb;
    wire canvas_enb;
    reg canvas_doutb = 1'b0;
    wire [4:0] result;
    wire busy;
    wire done;

    reg canvas_mem [0:783];
    integer i;
    integer x;
    integer y;
    integer dx;
    integer dy;

    always #5 clk = ~clk;

    npu_ctrl dut(
        .clk(clk),
        .reset_p(reset_p),
        .start(start),
        .canvas_addrb(canvas_addrb),
        .canvas_enb(canvas_enb),
        .canvas_doutb(canvas_doutb),
        .result(result),
        .busy(busy),
        .done(done)
    );

    always @(posedge clk) begin
        if (canvas_enb)
            canvas_doutb <= canvas_mem[canvas_addrb];
    end

    task clear_canvas;
        begin
            for (i = 0; i < 784; i = i + 1)
                canvas_mem[i] = 1'b0;
        end
    endtask

    task set_px;
        input integer px;
        input integer py;
        begin
            for (dy = -1; dy <= 1; dy = dy + 1) begin
                for (dx = -1; dx <= 1; dx = dx + 1) begin
                    if ((px + dx) >= 0 && (px + dx) < 28 &&
                        (py + dy) >= 0 && (py + dy) < 28) begin
                        canvas_mem[(py + dy) * 28 + (px + dx)] = 1'b1;
                    end
                end
            end
        end
    endtask

    task line;
        input integer x0;
        input integer y0;
        input integer x1;
        input integer y1;
        integer steps;
        integer k;
        integer px;
        integer py;
        begin
            steps = ((x1 > x0) ? (x1 - x0) : (x0 - x1));
            if (((y1 > y0) ? (y1 - y0) : (y0 - y1)) > steps)
                steps = ((y1 > y0) ? (y1 - y0) : (y0 - y1));
            if (steps == 0) steps = 1;
            for (k = 0; k <= steps; k = k + 1) begin
                px = x0 + ((x1 - x0) * k) / steps;
                py = y0 + ((y1 - y0) * k) / steps;
                set_px(px, py);
            end
        end
    endtask

    task run_case;
        input [8*16-1:0] name;
        begin
            @(posedge clk);
            start <= 1'b1;
            @(posedge clk);
            start <= 1'b0;
            wait(done == 1'b1);
            $display("%0s result=%0d char=%c", name, result, "A" + result);
            repeat (5) @(posedge clk);
        end
    endtask

    initial begin
        #1;
        $readmemh("training/exported/weights_l1.mem", dut.w1_rom_inst.mem);
        $readmemh("training/exported/biases_l1.mem",  dut.b1_rom_inst.mem);
        $readmemh("training/exported/weights_l2.mem", dut.w2_rom_inst.mem);
        $readmemh("training/exported/biases_l2.mem",  dut.b2_rom_inst.mem);

        repeat (10) @(posedge clk);
        reset_p <= 1'b0;
        repeat (10) @(posedge clk);

        clear_canvas();
        line(6, 24, 14, 4);
        line(22, 24, 14, 4);
        line(9, 14, 19, 14);
        run_case("A");

        clear_canvas();
        line(5, 24, 5, 4);
        line(22, 24, 22, 4);
        line(5, 4, 14, 16);
        line(22, 4, 14, 16);
        run_case("M");

        clear_canvas();
        line(6, 24, 6, 4);
        line(22, 24, 22, 4);
        line(6, 4, 22, 24);
        run_case("N");

        clear_canvas();
        line(6, 4, 14, 24);
        line(22, 4, 14, 24);
        run_case("V");

        clear_canvas();
        line(5, 5, 23, 5);
        line(14, 5, 14, 24);
        run_case("T");

        $finish;
    end
endmodule
