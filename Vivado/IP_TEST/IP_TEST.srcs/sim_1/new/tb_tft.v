`timescale 1ns / 1ps

module tb_tft;
    reg clk = 1'b0;
    reg resetn = 1'b0;

    reg  [5:0] awaddr = 6'd0;
    reg        awvalid = 1'b0;
    wire       awready;
    reg [31:0] wdata = 32'd0;
    reg [3:0]  wstrb = 4'hF;
    reg        wvalid = 1'b0;
    wire       wready;
    wire [1:0] bresp;
    wire       bvalid;
    reg        bready = 1'b1;

    reg  [5:0] araddr = 6'd0;
    reg        arvalid = 1'b0;
    wire       arready;
    wire [31:0] rdata;
    wire [1:0]  rresp;
    wire        rvalid;
    reg         rready = 1'b1;

    wire tft_sck;
    wire tft_sdi;
    wire tft_dc;
    wire tft_reset;
    wire tft_cs;
    wire dclk;
    wire din;
    wire cs_n;
    wire [9:0] canvas_addra;
    wire canvas_dina;
    wire canvas_wea;
    wire canvas_ena;

    reg penirq_n = 1'b1;
    reg dout = 1'b0;

    always #5 clk = ~clk;

    tft_axi dut(
        .tft_sdo(1'b0),
        .tft_sck(tft_sck),
        .tft_sdi(tft_sdi),
        .tft_dc(tft_dc),
        .tft_reset(tft_reset),
        .tft_cs(tft_cs),
        .PenIrq_n(penirq_n),
        .DCLK(dclk),
        .DIN(din),
        .DOUT(dout),
        .CS_N(cs_n),
        .canvas_addra(canvas_addra),
        .canvas_dina(canvas_dina),
        .canvas_wea(canvas_wea),
        .canvas_ena(canvas_ena),
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

    task axi_write;
        input [5:0] addr;
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
            @(posedge clk);
        end
    endtask

    task axi_read;
        input [5:0] addr;
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
            @(posedge clk);
        end
    endtask

    reg [31:0] rd;

    initial begin
        repeat (10) @(posedge clk);
        resetn <= 1'b1;
        repeat (10) @(posedge clk);

        axi_write(6'h00, 32'h0000_0003); // enable + clear
        wait (canvas_wea);
        if (canvas_dina !== 1'b0) begin
            $display("FAIL: clear should write zero");
            $finish;
        end

        wait (canvas_addra == 10'd783 && canvas_wea);
        repeat (5) @(posedge clk);

        axi_write(6'h10, 32'd783);
        repeat (2) @(posedge clk);
        axi_read(6'h14, rd);
        if (rd[0] !== 1'b0) begin
            $display("FAIL: cleared canvas readback is not zero");
            $finish;
        end

        axi_read(6'h0C, rd);
        if (rd[1] !== 1'b1) begin
            $display("FAIL: lcd_ready status should be 1");
            $finish;
        end

        $display("PASS: tb_tft completed");
        $finish;
    end

endmodule
