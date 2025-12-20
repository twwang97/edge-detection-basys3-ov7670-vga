// =============================================================================
// File : hex7seg_display.v
// Converted from VHDL : hex7seg_display.vhd
// Original Author (VHDL) : twwang97
// Conversion Author : twwang97
// Date : 2025-12-10
// Purpose : Drive a single 7-segment display (segments a..g) from a 4-bit value.
// Provides hex 0..F patterns. Designed for synchronous update on clk.
// Target : FPGA board Basys-3
// Clock : board clock (e.g., 50 MHz)
// Notes : active-low reset (rst_n); mapping assumes display_pins[6] -> a ... display_pins[0] -> g;
// segment polarity: '0' = ON for common-anode; verify your hardware.
// Depends : none (pure Verilog)
// Reference VHDL source:
// https://github.com/twwang97/altera-de2-115/blob/nycu2025/4bit-counter-jkff/quartus/src/hex7seg_display.vhd
// =============================================================================

module hex7seg_display (
    input  wire        clk,          // board clock (e.g., 50 MHz)
    input  wire        rst_n,        // active-low reset input
    input  wire [3:0]  input_state,  // 4-bit input value to display (0..15)
    output wire [6:0]  display_pins  // 7-bit segment outputs (a..g)
);

    // Registered digit (synchronous update)
    reg [3:0] digit;

    // 7-bit segment pattern: [6] = a, [5] = b, ... [0] = g
    reg [6:0] seg_pat;

    // Asynchronous active-low reset, synchronous load of input_state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            digit <= 4'b0000;
        else
            digit <= input_state;
    end

    // Combinational 7-segment decoder (common-anode: 0 = ON)
    always @(*) begin
        case (digit)
            4'b0000: seg_pat = 7'b0000001; // 0: a b c d e f ON, g OFF
            4'b0001: seg_pat = 7'b1001111; // 1
            4'b0010: seg_pat = 7'b0010010; // 2
            4'b0011: seg_pat = 7'b0000110; // 3
            4'b0100: seg_pat = 7'b1001100; // 4
            4'b0101: seg_pat = 7'b0100100; // 5
            4'b0110: seg_pat = 7'b0100000; // 6
            4'b0111: seg_pat = 7'b0001111; // 7
            4'b1000: seg_pat = 7'b0000000; // 8: all segments ON
            4'b1001: seg_pat = 7'b0000100; // 9
            4'b1010: seg_pat = 7'b0001000; // A
            4'b1011: seg_pat = 7'b1100000; // b
            4'b1100: seg_pat = 7'b0110001; // C
            4'b1101: seg_pat = 7'b1000010; // d
            4'b1110: seg_pat = 7'b0110000; // E
            4'b1111: seg_pat = 7'b0111000; // F
            default: seg_pat = 7'b1111111; // blank (all OFF)
        endcase
    end

    // Map seg_pat bits to outputs (seg_pat[6] -> a ... seg_pat[0] -> g)
    assign display_pins = seg_pat;

endmodule