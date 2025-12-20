// colorbar_gen.v
// Color bar generator that derives pixel/line wrap from VISIBLE_PIXELS and VISIBLE_LINES.
// It instantiates active_stable to require active_video to be high for 0.1s
// before streaming valid RGB outputs.

module colorbar_gen #(
    parameter integer VISIBLE_PIXELS = 640,
    parameter integer VISIBLE_LINES  = 480,
    parameter integer CLK_FREQ_HZ    = 25_000_000  // default 25 MHz
)(
    input  wire        clk,           // pixel clock (25 MHz)
    input  wire        active_video,  // asserted during visible pixels
    output reg  [3:0]  red_out,
    output reg  [3:0]  green_out,
    output reg  [3:0]  blue_out,
    output wire        active_valid   // indicates active_video has been stable for 0.1s
);

    // instantiate active_stable: requires 0.1s stable high
    active_stable #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .STABLE_SECONDS(0.1)
    ) u_active_stable (
        .clk(clk),
        .active_in(active_video),
        .active_valid(active_valid)
    );

    // function to compute ceil(log2(n))
    function integer clog2;
        input integer value;
        integer i;
    begin
        clog2 = 0;
        for (i = value - 1; i > 0; i = i >> 1)
            clog2 = clog2 + 1;
    end
    endfunction

    localparam integer PIXEL_CNT_WIDTH = (VISIBLE_PIXELS + 1) <= 1 ? 1 : clog2(VISIBLE_PIXELS + 1);
    localparam integer LINE_CNT_WIDTH  = (VISIBLE_LINES  + 1) <= 1 ? 1 : clog2(VISIBLE_LINES  + 1);

    // band width (8 equal vertical bars)
    localparam integer BAND_WIDTH = VISIBLE_PIXELS / 8;

    // counters and state
    reg [PIXEL_CNT_WIDTH-1:0] pixel_counter = {PIXEL_CNT_WIDTH{1'b0}};
    reg [LINE_CNT_WIDTH-1:0]  line_counter  = {LINE_CNT_WIDTH{1'b0}};

    // internal color registers
    reg [3:0] red_i   = 4'b0000;
    reg [3:0] green_i = 4'b0000;
    reg [3:0] blue_i  = 4'b0000;

    // pixel/line counters: derive wrap from visible counts
    // Only advance pixels when active_video is high AND active_valid is asserted.
    always @(posedge clk) begin
        if (active_video && active_valid) begin
            if (pixel_counter == VISIBLE_PIXELS - 1) begin
                // end of visible pixels in this line -> wrap pixel and advance line
                pixel_counter <= {PIXEL_CNT_WIDTH{1'b0}};
                if (line_counter == VISIBLE_LINES - 1)
                    line_counter <= {LINE_CNT_WIDTH{1'b0}}; // new frame
                else
                    line_counter <= line_counter + 1'b1;    // next line
            end else begin
                pixel_counter <= pixel_counter + 1'b1;
            end
        end else begin
            // during blanking or before active_valid, keep pixel index at 0
            pixel_counter <= {PIXEL_CNT_WIDTH{1'b0}};
        end
    end

    // color assignment based on pixel index within visible area
    integer pix_idx;
    always @(posedge clk) begin
        // default safe values
        red_i   <= 4'b0000;
        green_i <= 4'b0000;
        blue_i  <= 4'b0000;

        // only output color bars when active_video is high and has been stable long enough
        if (active_video && active_valid) begin
            pix_idx = pixel_counter;

            if (pix_idx < BAND_WIDTH * 1) begin
                // White
                red_i   <= 4'b1111;
                green_i <= 4'b1111;
                blue_i  <= 4'b1111;
            end else if (pix_idx < BAND_WIDTH * 2) begin
                // Yellow
                red_i   <= 4'b1111;
                green_i <= 4'b1111;
                blue_i  <= 4'b0000;
            end else if (pix_idx < BAND_WIDTH * 3) begin
                // Cyan
                red_i   <= 4'b0000;
                green_i <= 4'b1111;
                blue_i  <= 4'b1111;
            end else if (pix_idx < BAND_WIDTH * 4) begin
                // Green
                red_i   <= 4'b0000;
                green_i <= 4'b1111;
                blue_i  <= 4'b0000;
            end else if (pix_idx < BAND_WIDTH * 5) begin
                // Magenta
                red_i   <= 4'b1111;
                green_i <= 4'b0000;
                blue_i  <= 4'b1111;
            end else if (pix_idx < BAND_WIDTH * 6) begin
                // Red
                red_i   <= 4'b1111;
                green_i <= 4'b0000;
                blue_i  <= 4'b0000;
            end else if (pix_idx < BAND_WIDTH * 7) begin
                // Blue
                red_i   <= 4'b0000;
                green_i <= 4'b0000;
                blue_i  <= 4'b1111;
            end else begin
                // Black (last band)
                red_i   <= 4'b0000;
                green_i <= 4'b0000;
                blue_i  <= 4'b0000;
            end
        end else begin
            // during blanking or before active_valid keep black
            red_i   <= 4'b0000;
            green_i <= 4'b0000;
            blue_i  <= 4'b0000;
        end
    end

    // outputs registered
    always @(posedge clk) begin
        red_out   <= red_i;
        green_out <= green_i;
        blue_out  <= blue_i;
    end

endmodule