`timescale 1ns / 1ps

module tb_npu_axi;

    reg clk = 1'b0;
    reg resetn = 1'b0;

    reg  [3:0]  awaddr = 4'd0;
    reg         awvalid = 1'b0;
    wire        awready;
    reg  [31:0] wdata = 32'd0;
    reg  [3:0]  wstrb = 4'hF;
    reg         wvalid = 1'b0;
    wire        wready;
    wire [1:0]  bresp;
    wire        bvalid;
    reg         bready = 1'b1;

    reg  [3:0]  araddr = 4'd0;
    reg         arvalid = 1'b0;
    wire        arready;
    wire [31:0] rdata;
    wire [1:0]  rresp;
    wire        rvalid;
    reg         rready = 1'b1;

    wire [9:0] canvas_addrb;
    wire       canvas_enb;
    reg        canvas_doutb = 1'b0;

    reg canvas_mem [0:783];
    integer i;
    integer timeout;
    reg [31:0] rd;

    always #5 clk = ~clk; // 100MHz

    npu_axi dut(
        .canvas_addrb(canvas_addrb),
        .canvas_enb(canvas_enb),
        .canvas_doutb(canvas_doutb),
        .S_AXI_ACLK(clk),
        .S_AXI_ARESETN(resetn),
        .S_AXI_AWADDR(awaddr),
        .S_AXI_AWVALID(awvalid),
        .S_AXI_AWREADY(awready),
        .S_AXI_WDATA(wdata),
        .S_AXI_WSTRB(wstrb),
        .S_AXI_WVALID(wvalid),
        .S_AXI_WREADY(wready),
        .S_AXI_BRESP(bresp),
        .S_AXI_BVALID(bvalid),
        .S_AXI_BREADY(bready),
        .S_AXI_ARADDR(araddr),
        .S_AXI_ARVALID(arvalid),
        .S_AXI_ARREADY(arready),
        .S_AXI_RDATA(rdata),
        .S_AXI_RRESP(rresp),
        .S_AXI_RVALID(rvalid),
        .S_AXI_RREADY(rready)
    );

    // BRAM Generator의 synchronous read처럼 주소가 들어온 다음 클록에 데이터가 나온다.
    always @(posedge clk) begin
        if (canvas_enb)
            canvas_doutb <= canvas_mem[canvas_addrb];
    end

    task axi_write;
        input [3:0] addr;
        input [31:0] data;
        begin
            @(posedge clk);
            awaddr  <= addr;
            wdata   <= data;
            awvalid <= 1'b1;
            wvalid  <= 1'b1;
            wait (awready && wready);
            @(posedge clk);
            awvalid <= 1'b0;
            wvalid  <= 1'b0;
            wait (bvalid);
            if (bresp != 2'b00) begin
                $display("FAIL: AXI write response is not OKAY");
                $finish;
            end
            @(posedge clk);
        end
    endtask

    task axi_read;
        input [3:0] addr;
        output [31:0] data;
        begin
            @(posedge clk);
            araddr  <= addr;
            arvalid <= 1'b1;
            wait (arready);
            @(posedge clk);
            arvalid <= 1'b0;
            wait (rvalid);
            data = rdata;
            if (rresp != 2'b00) begin
                $display("FAIL: AXI read response is not OKAY");
                $finish;
            end
            @(posedge clk);
        end
    endtask

    initial begin
        // ROM 모듈의 기본 $readmemh 상대 경로와 무관하게 테스트벤치에서 확실히 로드한다.
        #1;
        $readmemh("training/exported/weights_l1.mem", dut.npu_core_inst.w1_rom_inst.mem);
        $readmemh("training/exported/biases_l1.mem",  dut.npu_core_inst.b1_rom_inst.mem);
        $readmemh("training/exported/weights_l2.mem", dut.npu_core_inst.w2_rom_inst.mem);
        $readmemh("training/exported/biases_l2.mem",  dut.npu_core_inst.b2_rom_inst.mem);

        // 간단한 대각선/격자 패턴을 28x28 입력으로 넣는다.
        for (i = 0; i < 784; i = i + 1)
            canvas_mem[i] = ((i % 29) == 0) || ((i % 28) == 7);

        repeat (10) @(posedge clk);
        resetn <= 1'b1;
        repeat (5) @(posedge clk);

        axi_read(4'h0, rd);
        if (rd !== 32'd0) begin
            $display("FAIL: CTRL reset value mismatch. got=%h", rd);
            $finish;
        end

        $display("[tb_npu_axi] write CTRL.start");
        axi_write(4'h0, 32'h0000_0001);

        timeout = 0;
        rd = 32'd0;
        while (rd[0] == 1'b0 && timeout < 25000) begin
            axi_read(4'h4, rd); // STATUS: [0]=done, [1]=busy
            timeout = timeout + 1;
        end

        if (timeout >= 25000) begin
            $display("FAIL: NPU done timeout");
            $finish;
        end

        axi_read(4'h8, rd); // RESULT
        if (rd[4:0] > 5'd25) begin
            $display("FAIL: RESULT out of range. result=%0d", rd[4:0]);
            $finish;
        end

        $display("PASS: tb_npu_axi completed. result=%0d (0=A, 25=Z)", rd[4:0]);
        $finish;
    end

endmodule
