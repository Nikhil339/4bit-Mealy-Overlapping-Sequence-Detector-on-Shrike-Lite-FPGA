"""Send a bit stream from the RP2040 to the FPGA over I2C (MicroPython, run from Thonny).

The FPGA on the Shrike-Lite (Renesas SLG47910) is an I2C target at address 0x32.
Every byte written to it is treated as 8 bits of a serial stream, MSB first.
The FPGA toggles its LED (FPGA GPIO16) each time the pattern 1011 is detected.

Wiring is already on the board (no external hardware needed):
    RP2040 GP14 (I2C1 SDA) <-> FPGA GPIO18 (package pin 9)
    RP2040 GP15 (I2C1 SCL) <-> FPGA GPIO17 (package pin 8)

Flash the FPGA bitstream first (see the README), then run this script.
"""

from machine import Pin, I2C

FPGA_ADDR = 0x32                                       # must match I2C_SLAVE_ADR in i2c_top.v
I2C_BUS = 1                                            # RP2040 I2C1
SDA_PIN = 14
SCL_PIN = 15
I2C_FREQ = 100_000

i2c = I2C(I2C_BUS, sda=Pin(SDA_PIN), scl=Pin(SCL_PIN), freq=I2C_FREQ)


def bits_to_bytes(bits):
    """Convert a string of 0/1 characters to bytes (MSB first).

    Spaces are ignored. The stream is padded with 0 bits at the END to a whole
    number of bytes, e.g. '1011 0110 1' -> b'\\xb6\\x80'.
    """
    bits = "".join(c for c in bits if c in "01")
    bits += "0" * (-len(bits) % 8)
    return bytes(int(bits[i:i + 8], 2) for i in range(0, len(bits), 8))


def send_bits(bits):
    """Write the bit string to the FPGA in one I2C transaction."""
    data = bits_to_bytes(bits)
    i2c.writeto(FPGA_ADDR, data)
    print("sent:", " ".join("{:08b}".format(b) for b in data))


found = i2c.scan()
print("I2C devices found:", [hex(a) for a in found])   # expect ['0x32']
if FPGA_ADDR not in found:
    print("FPGA not answering: flash the bitstream first and check the I2C1 pins (GP14/GP15).")

send_bits("00000000")            # flush the detector's memory once after power-up

while True:
    s = input("bits to send (e.g. 10110000, q to quit): ").strip()
    if s.lower() == "q":
        break
    if not s or any(c not in "01 " for c in s):
        print("use only 0 and 1")
        continue
    send_bits(s)
