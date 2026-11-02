module clk_rst(
    input       sys_clk,
    input       sys_rst_n,
    output      clk_100m,
    output      clk_50m,
    output      clk_25m,
    output      sys_rst
);

wire locked;
reg [1:0] rst_sync_r;

// PLL时钟IP核例化
clk_wiz_0 u_clk_wiz(
    .clk_in1(sys_clk),
    .reset(~sys_rst_n),
    .clk_out1(clk_100m),
    .clk_out2(clk_50m),
    .clk_out3(clk_25m),
    .locked(locked)
);

// 异步复位、同步释放，两级同步器避免跨时钟域亚稳态
always @(posedge clk_100m or negedge locked) begin
    if(!locked)
        rst_sync_r <= 2'b00;
    else
        rst_sync_r <= {rst_sync_r[0], 1'b1};
end

assign sys_rst = ~rst_sync_r[1];

endmodule