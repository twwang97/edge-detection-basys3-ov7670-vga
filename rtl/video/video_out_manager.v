// -----------------------------------------------------------------------------
// Module : video_out_manager
// Purpose: Output 4-bit RGB channels.
// Inputs : clk_25mhz    - 25 MHz pixel clock
//          rst_n        - active-low reset
//          rgb444_data  - 12-bit pixel data from memory [R(11:8),G(7:4),B(3:0)]
//          image_mode   - post-process the image with this mode
// Outputs: red_out, green_out, blue_out - 4-bit color outputs
// Notes  : Visible region is defined as hcount < 320 and vcount < 240.
// -----------------------------------------------------------------------------

module video_out_manager #(
  parameter IMAGE_MODE_MAX = 3 // Increase this if you add more filtering cases
)(
    input  wire        clk_25mhz,
    input  wire        rst_n,
    input  wire        visible,      // active during visible pixels
    input  wire [3:0]  image_mode,
    input  wire [11:0] rgb444_data,
    output reg  [3:0]  red_out,
    output reg  [3:0]  green_out,
    output reg  [3:0]  blue_out
);

    reg  [3:0]  image_mode_reg;
    reg  [15:0] image_1hot_mode;
    wire [11:0] pixel_out_colorbar;
    wire [11:0] pixel_out_original;
    wire [24:0] pixel_out_edge;
    wire [24:0] pixel_out_blur;    

    // pixel-output instance: color-bar pattern
    colorbar_gen #(
        .VISIBLE_PIXELS(320),
        .VISIBLE_LINES(240)
    ) colorbar_gen_inst (
        .clk(clk_25mhz),
        .active_video(image_1hot_mode[0]),
        .red_out(pixel_out_colorbar[11:8]),
        .green_out(pixel_out_colorbar[7:4]),
        .blue_out(pixel_out_colorbar[3:0])
    );

    // pixel-output instance: RGB444
    video_out_original origin_rgb444_inst (
        .clk(clk_25mhz),
        .rst_n(rst_n),
        .enabled(image_1hot_mode[1]),
        .rgb444_data(rgb444_data),
        .red_out(pixel_out_original[11:8]),
        .green_out(pixel_out_original[7:4]),
        .blue_out(pixel_out_original[3:0])
    );

    // pixel-output instance: Sobel Filter
    filter_sobel sobel_edge_inst (
        .clk(clk_25mhz),
        .rst_n(rst_n),
        .enabled(image_1hot_mode[2]),
        .visible(visible),
        .rgb444_data(rgb444_data),
        .red_out(pixel_out_edge[23:20]),
        .green_out(pixel_out_edge[19:16]),
        .blue_out(pixel_out_edge[15:12])
    );

    // pixel-output instance: Weighted Edge Detection
    filter_edge_weighted weighted_edge_inst (
        .clk(clk_25mhz),
        .rst_n(rst_n),
        .enabled(image_1hot_mode[3]),
        .visible(visible),
        .rgb444_data(rgb444_data),
        .red_out(pixel_out_edge[11:8]),
        .green_out(pixel_out_edge[7:4]),
        .blue_out(pixel_out_edge[3:0])
    );

    always @* begin
        // keep image_mode_reg in range
        image_mode_reg = (image_mode <= IMAGE_MODE_MAX) ? image_mode : 4'd0;
        image_1hot_mode = 16'b1 << image_mode_reg; // one-hot encoding
    end

    // synchronous logic with asynchronous active-low reset
    always @(posedge clk_25mhz or negedge rst_n) begin
        if (!rst_n) begin
            red_out          <= 4'b0;
            green_out        <= 4'b0;
            blue_out         <= 4'b0;
        end else begin

            case (image_mode_reg)
                4'b0000: begin // 0: Colorbar Pattern
                    red_out   <= pixel_out_colorbar[11:8];
                    green_out <= pixel_out_colorbar[7:4];
                    blue_out  <= pixel_out_colorbar[3:0];
                end

                4'b0001: begin // 1: Original RGB444
                    red_out   <= pixel_out_original[11:8];
                    green_out <= pixel_out_original[7:4];
                    blue_out  <= pixel_out_original[3:0];
                end

                4'b0010: begin // 2: Sobel
                    red_out   <= pixel_out_edge[23:20];
                    green_out <= pixel_out_edge[19:16];
                    blue_out  <= pixel_out_edge[15:12];
                end

                4'b0011: begin // 3: Weighted Edge Detection
                    red_out   <= pixel_out_edge[11:8];
                    green_out <= pixel_out_edge[7:4];
                    blue_out  <= pixel_out_edge[3:0];
                end

                default: begin
                    red_out   <= pixel_out_colorbar[11:8];
                    green_out <= pixel_out_colorbar[7:4];
                    blue_out  <= pixel_out_colorbar[3:0];
                end
            endcase
        end
    end

endmodule