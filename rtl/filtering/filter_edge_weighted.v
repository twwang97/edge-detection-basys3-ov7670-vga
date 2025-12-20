/*
  Module: filter_edge_weighted
  Purpose:
    Real-time 3x3 Sobel edge detector for RGB444 video streams. Converts incoming
    RGB444 pixels to a 4-bit weighted grayscale, buffers three image lines using
    rotating line RAMs, forms a 3x3 sliding window with per-row shift registers,
    computes Sobel gradients (Gx, Gy) using shift/add operations, approximates
    gradient magnitude as |Gx|+|Gy|, scales/saturates the result to 4 bits and
    outputs a grayscale RGB444 edge image suitable for VGA or similar displays.

  Key features:
    - Weighted grayscale conversion using shift-add (approx. 0.299R + 0.587G + 0.114B)
    - Three rotating line buffers to support streaming 3-line window without external RAM
    - 3x3 shift-register window per row for horizontal neighborhood
    - Sobel operator implemented with integer arithmetic and bit shifts (no multipliers)
    - Magnitude approximation via Manhattan norm (|Gx| + |Gy|) and 4-bit compression
    - Zero-padding at horizontal line boundaries (shifts cleared when not visible)
    - Parameterizable visible resolution (VISIBLE_PIXELS, VISIBLE_LINES)

  Ports:
    - clk       : input clock (synchronous logic)
    - rst_n     : active-low reset (clears buffers and outputs)
    - enabled   : module enable (when low, outputs are driven black and internal state reset)
    - visible   : high during visible pixel periods (used to update line buffers and shifts)
    - rgb444_data : 12-bit input pixel in RGB444 format {R[3:0],G[3:0],B[3:0]}
    - red_out   : 4-bit red channel of output RGB444 edge pixel
    - green_out : 4-bit green channel of output RGB444 edge pixel
    - blue_out  : 4-bit blue channel of output RGB444 edge pixel

  Parameters:
    - VISIBLE_PIXELS : number of visible pixels per line (default 320)
    - VISIBLE_LINES  : number of visible lines per frame (default 240)
    - ADDR_WIDTH     : localparam computed as $clog2(VISIBLE_PIXELS)

  Implementation notes:
    - Input RGB444 components are zero-extended to 8 bits for weighted sum arithmetic.
    - Sobel kernels:
        Gx = -p00 - 2*p10 - p20 + p02 + 2*p12 + p22
        Gy = -p00 - 2*p01 - p02 + p20 + 2*p21 + p22
      where pij are 4-bit grayscale samples extended to signed values.
    - Magnitude is approximated as |Gx| + |Gy|, then compressed by shifting right
      (divide by 8) and saturating to 4 bits to produce the final edge intensity.

  Usage tips:
    - Match VISIBLE_PIXELS and VISIBLE_LINES to your video timing generator.
    - Ensure 'visible' is asserted only during active pixel periods and deasserted
      during horizontal/vertical blanking so line rotation and zero-padding behave correctly.
*/

module filter_edge_weighted (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enabled,
    input  wire        visible,       // active during visible pixels
    input  wire [11:0] rgb444_data,   // RGB444 input
    output reg  [3:0]  red_out,
    output reg  [3:0]  green_out,
    output reg  [3:0]  blue_out
);
    // Parameters: adjust to your resolution
    parameter VISIBLE_PIXELS = 320;
    parameter VISIBLE_LINES  = 240;
    localparam ADDR_WIDTH = $clog2(VISIBLE_PIXELS);

    // -------------------------
    // Grayscale conversion (4-bit)
    // weighted grayscale (0.299R + 0.587G + 0.114B)
    // -------------------------
    // r,g,b are 4-bit inputs (0..15)
    wire [7:0] r8 = {4'd0, rgb444_data}; // zero-extend to 8 bits
    wire [7:0] g8 = {4'd0, rgb444_data};
    wire [7:0] b8 = {4'd0, rgb444_data};

    // compute weighted sum using shift-adds to avoid multipliers
    // 0.299 * 256 = 77 = 64 + 8 + 4 + 1
    wire [15:0] r_term = (r8 << 6) + (r8 << 3) + (r8 << 2) + r8;
    // 0.587G * 256 = 150 = 128 + 16 + 4 + 2
    wire [15:0] g_term = (g8 << 7) + (g8 << 4) + (g8 << 2) + (g8 << 1);
    // 0.114B * 256 = 29 = 16 + 8 + 4 + 1
    wire [15:0] b_term = (b8 << 4) + (b8 << 3) + (b8 << 2) + b8;

    wire [15:0] lum_sum = r_term + g_term + b_term; // up to small value
    wire [3:0] gray = (lum_sum >> 8) > 15 ? 4'hF : (lum_sum >> 8); // clamp to 4 bits

    // -------------------------
    // Line buffers (3 rotating lines)
    // -------------------------
    // Three line buffers to hold three previous lines; rotate indices each line.
    reg [3:0] linebuf0 [0:VISIBLE_PIXELS-1];
    reg [3:0] linebuf1 [0:VISIBLE_PIXELS-1];
    reg [3:0] linebuf2 [0:VISIBLE_PIXELS-1];

    // Which buffer is being written this line (0..2)
    reg [1:0] write_buf_idx;

    // column counter within visible line
    reg [ADDR_WIDTH-1:0] col_cnt;
    reg line_active; // high while inside visible pixels for a line

    // read pixels from the two previous lines at current column
    wire [3:0] top_pixel;   // line N-2
    wire [3:0] mid_pixel;   // line N-1
    // bottom pixel is current gray

    // Map buffer index to actual arrays
    // read from buffers using combinational mapping
    function [3:0] read_buf;
        input [1:0] buf_idx;
        input [ADDR_WIDTH-1:0] addr;
        begin
            case (buf_idx)
                2'd0: read_buf = linebuf0[addr];
                2'd1: read_buf = linebuf1[addr];
                2'd2: read_buf = linebuf2[addr];
                default: read_buf = 4'd0;
            endcase
        end
    endfunction

    // compute indices for top and mid relative to write_buf_idx:
    // write_buf_idx holds the buffer we are currently writing the current line into.
    // mid = buffer that holds previous line = (write_buf_idx + 2) % 3
    // top = buffer that holds line before previous = (write_buf_idx + 1) % 3
    wire [1:0] mid_idx = (write_buf_idx + 2'd2) % 3;
    wire [1:0] top_idx = (write_buf_idx + 2'd1) % 3;

    assign mid_pixel = read_buf(mid_idx, col_cnt);
    assign top_pixel = read_buf(top_idx, col_cnt);

    // -------------------------
    // 3x3 shift registers per row to form window
    // -------------------------
    reg [3:0] shift_top [0:2];   // [0]=left, [1]=center, [2]=right
    reg [3:0] shift_mid [0:2];
    reg [3:0] shift_bot [0:2];

    // -------------------------
    // Sobel computation wires
    // -------------------------
    // p00 p01 p02  (top row)
    // p10 p11 p12  (mid row)
    // p20 p21 p22  (bot row)
    wire signed [6:0] p00 = {1'b0, shift_top[0]}; // extend to signed
    wire signed [6:0] p01 = {1'b0, shift_top[1]};
    wire signed [6:0] p02 = {1'b0, shift_top[2]};

    wire signed [6:0] p10 = {1'b0, shift_mid[0]};
    wire signed [6:0] p11 = {1'b0, shift_mid[1]};
    wire signed [6:0] p12 = {1'b0, shift_mid[2]};

    wire signed [6:0] p20 = {1'b0, shift_bot[0]};
    wire signed [6:0] p21 = {1'b0, shift_bot[1]};
    wire signed [6:0] p22 = {1'b0, shift_bot[2]};

    // Gx = -p00 -2*p10 - p20 + p02 + 2*p12 + p22
    wire signed [9:0] Gx = -p00 - (p10 <<< 1) - p20 + p02 + (p12 <<< 1) + p22;
    // Gy = -p00 -2*p01 - p02 + p20 + 2*p21 + p22
    wire signed [9:0] Gy = -p00 - (p01 <<< 1) - p02 + p20 + (p21 <<< 1) + p22;

    // magnitude approximation: |Gx| + |Gy|
    wire [9:0] absGx = (Gx[9] ? -Gx : Gx);
    wire [9:0] absGy = (Gy[9] ? -Gy : Gy);
    wire [10:0] mag = absGx + absGy; // up to ~120

    // Map magnitude to 4-bit edge: divide by 8 (mag[6:3]) to compress range 0..15, saturate
    wire [3:0] mag_scaled = (mag[10:6] != 0) ? 4'hF : mag[6:3];

    // final 12-bit RGB444 edge pixel
    wire [11:0] sobel_rgb = {mag_scaled, mag_scaled, mag_scaled};

    // -------------------------
    // Main sequential logic: buffering, shifting, sobel pipeline
    // -------------------------
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || !enabled) begin
            write_buf_idx <= 2'd0;
            col_cnt <= {ADDR_WIDTH{1'b0}};
            line_active <= 1'b0;
            // clear line buffers and shifts
            for (i = 0; i < VISIBLE_PIXELS; i = i + 1) begin
                linebuf0[i] <= 4'd0;
                linebuf1[i] <= 4'd0;
                linebuf2[i] <= 4'd0;
            end
            for (i = 0; i < 3; i = i + 1) begin
                shift_top[i] <= 4'd0;
                shift_mid[i] <= 4'd0;
                shift_bot[i] <= 4'd0;
            end
        end
        else begin
            // Only process when visible; when not visible we keep counters and shifts reset at line boundaries
            if (visible) begin
                // Update shift registers: shift left, insert new pixels at right
                // top and mid come from line buffers; bottom is current gray
                shift_top[0] <= shift_top[1];
                shift_top[1] <= shift_top[2];
                shift_top[2] <= top_pixel;

                shift_mid[0] <= shift_mid[1];
                shift_mid[1] <= shift_mid[2];
                shift_mid[2] <= mid_pixel;

                shift_bot[0] <= shift_bot[1];
                shift_bot[1] <= shift_bot[2];
                shift_bot[2] <= gray;

                // write current gray into the buffer selected by write_buf_idx at current column
                case (write_buf_idx)
                    2'd0: linebuf0[col_cnt] <= gray;
                    2'd1: linebuf1[col_cnt] <= gray;
                    2'd2: linebuf2[col_cnt] <= gray;
                endcase

                // increment column counter
                if (col_cnt == VISIBLE_PIXELS - 1) begin
                    col_cnt <= {ADDR_WIDTH{1'b0}};
                    // finished a line: rotate write buffer index so next line writes into next buffer
                    write_buf_idx <= write_buf_idx + 2'd1;
                end
                else begin
                    col_cnt <= col_cnt + 1'b1;
                end

                line_active <= 1'b1;
            end
            else begin
                // not visible: clear shifts for next line start so edges are zero-padded horizontally
                if (line_active) begin
                    // we just left visible region; reset shifts to zero for next line
                    for (i = 0; i < 3; i = i + 1) begin
                        shift_top[i] <= 4'd0;
                        shift_mid[i] <= 4'd0;
                        shift_bot[i] <= 4'd0;
                    end
                    line_active <= 1'b0;
                end
                // keep vga outputs black when not visible (unless static_display_mode uses colorbar)
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            red_out   <= 4'b0000;
            green_out <= 4'b0000;
            blue_out  <= 4'b0000;
        end
        else if (enabled) begin
            red_out   <= sobel_rgb[11:8];
            green_out <= sobel_rgb[7:4];
            blue_out  <= sobel_rgb[3:0];
        end
        else begin
            red_out   <= 4'b0000;
            green_out <= 4'b0000;
            blue_out  <= 4'b0000;
        end
    end

endmodule