module ROM_Wrapper (
	addr_x,
	addr_y,
	i_VGA_request,
	clk,
	o_red,
	o_green,
	o_blue);

input	[12:0]  addr_x;
input	[12:0]  addr_y;
input i_VGA_request;
input	  clk;
output [9:0] o_red;
output [9:0] o_green;
output [9:0] o_blue;

wire [16:0] rom_addr;
assign rom_addr = (i_VGA_request) ? addr_x[12:1] + addr_y[12:1] * 400: 0;
wire [15:0] rgb_565;
assign o_red = {rgb_565[15:11],5'b00};
assign o_green = {rgb_565[10:5],4'b00};
assign o_blue = {rgb_565[4:0],5'b00};




ROM	ROM_inst (
	.address ( rom_addr ),
	.inclock ( clk ),
	.outclock ( clk ),
	.q ( rgb_565 )
	);



endmodule

