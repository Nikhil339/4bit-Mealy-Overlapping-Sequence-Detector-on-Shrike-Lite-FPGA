// implementation of 4bit mealy overlapping sequence detector (1011)
// dataflow modelling

module main(
	input wire clk,
	input wire en,
	input wire x,
	output wire y
);

	reg q1, q0;
	
	wire x_n = ~x;
	wire q0_n = ~q0;
	
	wire a1 = x_n & q0;
	wire a2 = x & q1 & q0_n;
	wire d1 = a1 | a2;
	wire d0 = x;
	
	assign y = x & q0 & q1;
	
	always @(posedge clk) begin
		if (en) begin
			q1 <= d1;
			q0 <= d0;
		end
	end
	
endmodule