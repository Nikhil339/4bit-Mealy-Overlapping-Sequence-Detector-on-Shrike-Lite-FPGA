`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// Self-checking testbench for the complete design (i2c_top + main + i2c_slave).
// It plays the role of the RP2040: it is an I2C master that writes bytes to
// address 0x32, and it checks how many times the detector fired and where the
// LED ends up.
//
// Run with Icarus Verilog (from the repository root):
//   iverilog -g2005 -o sim ffpga/src/i2c_top.v ffpga/src/main.v \
//            ffpga/lib/i2c_slave.v ffpga/sim/tb_i2c_top.v
//   vvp sim
// -----------------------------------------------------------------------------
module tb_i2c_top;
    reg clk = 0;
    always #10 clk = ~clk;                 // 50 MHz FPGA clock

    reg  scl_m = 1, sda_m = 1;             // master drive: 1 = released, 0 = pulled low
    wire o_sda, o_sda_oe, o_led, o_led_en, o_clk_en;
    wire sda_line = sda_m & ~o_sda_oe;     // open-drain bus with pull-up
    wire scl_line = scl_m;

    i2c_top dut (
        .i_clk(clk), .i_scl(scl_line), .i_sda(sda_line),
        .o_sda(o_sda), .o_sda_oe(o_sda_oe),
        .o_led(o_led), .o_led_en(o_led_en), .o_clk_en(o_clk_en)
    );

    // Count detections inside the DUT (the 'hit' pulse of the FSM)
    integer hits = 0;
    always @(posedge clk) if (dut.hit === 1'b1) hits <= hits + 1;

    localparam HALF = 5000;                // 5 us per half period -> ~100 kHz SCL

    task i2c_start;
        begin sda_m = 1; scl_m = 1; #HALF; sda_m = 0; #HALF; scl_m = 0; #(HALF/2); end
    endtask
    task i2c_stop;
        begin sda_m = 0; #(HALF/2); scl_m = 1; #HALF; sda_m = 1; #(2*HALF); end
    endtask
    task send_bit(input b);
        begin sda_m = b; #(HALF/2); scl_m = 1; #HALF; scl_m = 0; #(HALF/2); end
    endtask
    task send_byte(input [7:0] d, output ack);
        integer i;
        begin
            for (i = 7; i >= 0; i = i - 1) send_bit(d[i]);
            sda_m = 1;                                   // release SDA for the ACK bit
            #(HALF/2); scl_m = 1; #(HALF/2);
            ack = ~sda_line;                             // target pulls SDA low = ACK
            #(HALF/2); scl_m = 0; #(HALF/2);
        end
    endtask

    // One I2C write transaction of 1 or 2 data bytes to address 0x32
    reg a0, a1, a2;
    task write_bytes(input integer n, input [7:0] b0, input [7:0] b1);
        begin
            i2c_start;
            send_byte({7'h32, 1'b0}, a0);
            send_byte(b0, a1);
            if (n == 2) send_byte(b1, a2); else a2 = 1;
            i2c_stop;
            if (!(a0 && a1 && a2)) $display("  !! missing ACK (%b %b %b)", a0, a1, a2);
        end
    endtask

    integer errors = 0;
    task check(input integer exp_hits, input exp_led, input [8*48-1:0] name);
        begin
            #(20*30);                                    // let the last bits shift through
            if (hits == exp_hits && o_led === exp_led)
                $display("PASS  %0s : total hits=%0d  led=%b", name, hits, o_led);
            else begin
                $display("FAIL  %0s : total hits=%0d (expected %0d)  led=%b (expected %b)",
                         name, hits, exp_hits, o_led, exp_led);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_i2c_top.vcd");
        $dumpvars(0, tb_i2c_top);
        dut.led = 1'b0;                 // simulation only: give the LED a defined start value
        #2000;

        write_bytes(1, 8'b0000_0000, 8'h00);                  // flush the FSM (it starts undefined in simulation)
        hits = 0;                                             // ignore anything before the flush
        check(0, 1'b0, "00000000  flush");

        write_bytes(1, 8'b1011_0000, 8'h00);
        check(1, 1'b1, "10110000  one hit, LED on");

        write_bytes(1, 8'b1011_0110, 8'h00);
        check(3, 1'b1, "10110110  two overlapping hits, LED unchanged");

        write_bytes(2, 8'b0000_0101, 8'b1000_0000);           // '000001011' padded to 2 bytes
        check(4, 1'b0, "000001011 hit across a byte boundary");

        write_bytes(1, 8'b0000_0000, 8'h00);
        check(4, 1'b0, "00000000  flush, no change");

        write_bytes(1, 8'b1011_0110, 8'h00);                  // leaves the FSM holding '10'
        check(6, 1'b0, "10110110  two hits, FSM keeps '10'");

        write_bytes(1, 8'b1100_0000, 8'h00);                  // '11' completes the leftover '10'
        check(7, 1'b1, "11000000  hit using the leftover '10'");

        write_bytes(1, 8'b0000_0000, 8'h00);
        check(7, 1'b1, "00000000  flush, no change");

        write_bytes(1, 8'b1100_0000, 8'h00);                  // same byte, but no leftover now
        check(7, 1'b1, "11000000  no hit after a flush");

        write_bytes(1, 8'b1010_1010, 8'h00);
        check(7, 1'b1, "10101010  no hit");

        write_bytes(1, 8'b0000_1011, 8'h00);
        check(8, 1'b0, "00001011  hit on the last bit");

        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d TEST(S) FAILED", errors);
        $finish;
    end
endmodule
