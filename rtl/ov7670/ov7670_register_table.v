/*
 * Module      : ov7670_register_table.v
 * Purpose     : ROM of OV7670 register-value pairs used to initialize camera.
 * Author      : twwang97 <twwang97@gmail.com>
 * Created     : 2025-12-10
 * Platform    : FPGA Basys-3, Vivado 2025.2
 *
 * Notes:
 *  - rom[x] stores {reg_addr[7:0], reg_value[7:0]}.
 *  - END_CODE = 16'hFFFF marks end of table; DELAY_CODE = 16'hFFF0 inserts delay.
 *
 * References:
 *  - OV7670 register map and init sequences, ExampleSite — register addresses and recommended init sequence: https://www.voti.nl/docs/OV7670.pdf (used for rom[0..76])
 *  - Jacobo’s GitHub: https://github.com/AngeloJacobo/FPGA_OV7670_Camera_Interface/blob/main/src/camera_interface.v
 *  - Chen’s GitHub: https://github.com/donctchen/ov7670_vga_display/blob/main/ov7670_setup_rom.v
 *
 * Change Log:
 *  - 2025-12-10  Initial version
 */

module ov7670_register_table (
    input  wire        clk,
    input  wire [7:0]  current_idx,
    output reg  [15:0] dev_register_pair
);

    // Special codes
    localparam [15:0] END_CODE   = 16'hFFFF;
    localparam [15:0] DELAY_CODE = 16'hFFF0;

    // ROM depth must match current_idx width (here 80 entries)
    reg [15:0] rom [0:79];

    integer iter;
    // Fill ROM at elaboration time
    initial begin
        rom[0] = 16'h1280; // reset
        rom[1] = 16'hFFF0; // delay
        rom[2] = 16'hFFF0; // delay
        rom[3] = 16'h1214; // Set output format and basic COM7 flags (selects RGB mode, normal operation).  
        rom[4] = 16'h1180; // Internal clock prescaler / PLL configuration for pixel clock.  
        rom[5] = 16'h0C00; // Disable scaling and special COM3 features; default sensor path.  
        rom[6] = 16'h3E00; // COM14 disables manual scaling; normal timing path.  
        rom[7] = 16'h0400; // COM1
        rom[8] = 16'h40D0; // COM15 selects RGB565 and full dynamic range.  
        rom[9] = 16'h3A04; // TSLB: Line buffer order and UV swap control for output sequence.  
        rom[10] = 16'h1418; // COM9 - MAX AGC value x4
        rom[11] = 16'h4FB3; // MTX1 - Color matrix coefficient (matrix tuning for R/G/B conversion)
        rom[12] = 16'h50B3; // MTX2 - Color matrix coefficient (matrix tuning for R/G/B conversion)
        rom[13] = 16'h5100; // MTX3 - Color matrix coefficient (matrix tuning for R/G/B conversion)
        rom[14] = 16'h523D; // MTX4 - Color matrix coefficient (matrix tuning for R/G/B conversion)
        rom[15] = 16'h53A7; // MTX5 - Color matrix coefficient (matrix tuning for R/G/B conversion)
        rom[16] = 16'h54E4; // MTX6 - Color matrix coefficient (matrix tuning for R/G/B conversion)
        rom[17] = 16'h589E; // MTXS - Color matrix sign/polarity bits for matrix coefficients.  
        rom[18] = 16'h3DC0; // COM13 - Controls gamma/UV/edge enhancement and related ISP flags.
        rom[19] = 16'h1714; // Horizontal window start (defines left edge of active window).
        rom[20] = 16'h1802; // Horizontal window stop (defines right edge of active window).
        rom[21] = 16'h3280; // HREF control: windowing, mirror and related horizontal flags.
        rom[22] = 16'h1903; // Vertical window start (defines top edge of active window).  
        rom[23] = 16'h1A7B; // Vertical window stop (defines bottom edge of active window).  
        rom[24] = 16'h030A; // Vertical reference / fine vertical offset for windowing.  
        rom[25] = 16'h0F41; // COM6: System control bits affecting PCLK polarity and misc features.  
        rom[26] = 16'h1E00; // disables mirror/flip
        rom[27] = 16'h330B; // Timing/sample-hold tuning; fine timing adjustment.
        rom[28] = 16'h3C78; // COM12: Automatic gain/exposure tuning and banding control.  
        rom[29] = 16'h6900; // Fixed gain register; zero disables fixed gain (use auto gain).  
        rom[30] = 16'h7400; // reserved
        rom[31] = 16'hB084; // reserved
        rom[32] = 16'hB10C; // reserved
        rom[33] = 16'hB20E; // reserved
        rom[34] = 16'hB380; // reserved
        rom[35] = 16'h703A; // reserved
        rom[36] = 16'h7135; // reserved
        rom[37] = 16'h7211; // reserved
        rom[38] = 16'h73F0; // reserved
        rom[39] = 16'hA202; // Auto white balance control bits and enable/disable flags
        rom[40] = 16'h7A20; // Gamma table entry 1 (part of gamma curve LUT).
        rom[41] = 16'h7B10; // Gamma table entry 2 (part of gamma curve LUT).
        rom[42] = 16'h7C1E; // Gamma table entry 3 (part of gamma curve LUT).
        rom[43] = 16'h7D35; // Gamma table entry 4 (part of gamma curve LUT).
        rom[44] = 16'h7E5A; // Gamma table entry 5 (part of gamma curve LUT).
        rom[45] = 16'h7F69; // Gamma table entry 6 (part of gamma curve LUT).
        rom[46] = 16'h8076; // Gamma table entry 7 (part of gamma curve LUT).
        rom[47] = 16'h8180; // Gamma table entry 8 (part of gamma curve LUT).
        rom[48] = 16'h8288; // Gamma table entry 9 (part of gamma curve LUT).
        rom[49] = 16'h838F; // Gamma table entry 10 (part of gamma curve LUT).
        rom[50] = 16'h8496; // Gamma table entry 11 (part of gamma curve LUT).
        rom[51] = 16'h85A3; // Gamma table entry 12 (part of gamma curve LUT).
        rom[52] = 16'h86AF; // Gamma table entry 13 (part of gamma curve LUT).
        rom[53] = 16'h87C4; // Gamma table entry 14 (part of gamma curve LUT).
        rom[54] = 16'h88D7; // Gamma table entry 15 (part of gamma curve LUT).
        rom[55] = 16'h89E8; // Gamma table entry 16 (part of gamma curve LUT).
        rom[56] = 16'h13E0; // Enable AGC/AEC and other common controls in COM8.  
        rom[57] = 16'h0000; // Default/zero register; often unused in init sequences.  
        rom[58] = 16'h1000; // set ARCJ reg to 0
        rom[59] = 16'h0D40; // PCLK divider and scaling options; affects pixel clock division.
        rom[60] = 16'h1418; // AGC/AEC control repeated; sets gain ceiling and exposure behavior.  
        rom[61] = 16'hA505; // Auto white balance tuning register 2. 
        rom[62] = 16'hAB07; // Auto white balance tuning register 3.  
        rom[63] = 16'h2495; // AEW/AEB thresholds for AGC/AEC windowing. 
        rom[64] = 16'h2533; // AGC/AEC speed or target tuning parameter.  
        rom[65] = 16'h26E3; // Histogram/AGC related tuning parameter. 
        rom[66] = 16'h9F78; // ISP tuning block: contrast/brightness or related processing.  
        rom[67] = 16'hA068; // ISP tuning parameter for color processing.  
        rom[68] = 16'hA103; // ISP small tuning value for color/processing.  
        rom[69] = 16'hA6D8; // ISP color/gain tuning parameter.  
        rom[70] = 16'hA7D8; // ISP color/gain tuning parameter.  
        rom[71] = 16'hA8F0; // ISP tuning for saturation/contrast. 
        rom[72] = 16'hA990; // ISP tuning for color balance.  
        rom[73] = 16'hAA94; // ISP tuning final color adjustment.  
        rom[74] = 16'h13E5; // Alternate COM8 flags for AGC/AEC and related features.  
        rom[75] = 16'h6906; // Enable fixed gain and set fixed gain value.
        rom[76] = 16'h1E23; // Mirror/flip
        // ... fill remaining entries or leave as END_CODE
        rom[77] = END_CODE;
	// Optionally initialize rest to END_CODE
        for (iter = 78; iter < 80; iter = iter + 1) rom[iter] = END_CODE;
    end

    // Synchronous read to match original behavior
    always @(posedge clk) begin
        dev_register_pair <= rom[current_idx];
    end

endmodule