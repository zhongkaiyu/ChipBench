I would like you to implement a module named TopModule with the following
interface. All input and output ports are one bit unless otherwise
specified.

 - input  clk
 - input  rst_n
 - input  a
 - output match

The module should implement a sequence detection circuit that detects the
pattern "011XXX110" in the input data stream. The pattern consists of 9 bits
where the first 3 bits are "011", the last 3 bits are "110", and the middle
3 bits can be any value (don't care).

The sequence detection should work as follows:
- Monitor the input data stream continuously
- Detect when the pattern "011XXX110" appears in the input
- Output match signal should be high when the pattern is detected
- Output match signal should be low at all other times

Implementation approach:
The module should use a 9-bit shift register to store the last 9 input bits.
The match signal should be asserted when:
- The first 3 bits (bits 8:6) equal "011" AND
- The last 3 bits (bits 2:0) equal "110"
- The middle 3 bits (bits 5:3) can be any value

### Timing and Behavior:
- When rst_n is low, the module should reset to its initial state
- On every positive clock edge (clk), the module should shift in the new input bit
- The output match is updated sequentially
- The detection is continuous - the module checks for the pattern on every clock cycle
