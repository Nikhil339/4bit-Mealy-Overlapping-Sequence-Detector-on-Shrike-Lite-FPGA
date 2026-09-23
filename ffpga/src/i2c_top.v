// Custom Module
`timescale 1ns/1ps

(* top *) module i2c_top #( parameter I2C_SLAVE_ADR = 7'h32 )(
	(* iopad_external_pin, clkbuf_inhibit *) input i_clk,
	//(* iopad_external_pin *) input i_rst,
	(* iopad_external_pin *) input i_scl,
	(* iopad_external_pin *) input i_sda,
	(* iopad_external_pin *) output o_sda,
	(* iopad_external_pin *) output o_sda_oe,
	(* iopad_external_pin *) output o_led,
	(* iopad_external_pin *) output o_led_en,
	(* iopad_external_pin *) output o_clk_en
);

	assign o_clk_en = 1'b1;
	assign o_led_en = 1'b1;
	
	wire w_busy, w_int_tx, w_int_rx;
	wire [7:0]w_data_rx;
	
i2c_slave #( .I2C_TARGET_ADR(I2C_SLAVE_ADR)) u_i2c (
	.i_clk		(i_clk),
	.i_rst 		(1'b0),
	.i_en  		(1'b1),
	.o_busy		(w_busy),
	.i_scl		(i_scl),
	.i_sda		(i_sda),
	.o_sda		(o_sda),
	.o_sda_oe	(o_sda_oe),
	.i_data_tx	(8'h00),
	.o_data_rx	(w_data_rx),
	.o_int_tx	(w_int_tx),
	.o_int_rx	(w_int_rx)
);
		
	reg [7:0] sh;
	reg [3:0] cnt;
	wire step = |cnt;
	wire x = sh[7];
	
	always @( posedge i_clk) begin
		if (w_int_rx) begin
			sh <= w_data_rx;
			cnt <= 4'd8;
		end else if (step) begin
			sh <= {sh[6:0], 1'b0};
			cnt <= cnt - 4'd1;
		end
	end
	
	wire hit;
	main u_fsm(.clk(i_clk), .en(step), .x(x), .y(hit));
	
	reg led;
	always @( posedge i_clk) begin
		if (hit) led <= ~led;
	end
	
	assign o_led = led;

endmodule
