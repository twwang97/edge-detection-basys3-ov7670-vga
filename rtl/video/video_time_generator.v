// -----------------------------------------------------------------------------
// Video timing generator (320x240 style with 800x525 total pixels per frame)
// Parameters are configurable; outputs are registered and aligned.
// -----------------------------------------------------------------------------
module video_time_generator #(
    parameter H_TOTAL = 10'd800,
    parameter H_VISIBLE = 10'd320,   // visible width used by user code
    parameter H_SYNC_START = 10'd659,
    parameter H_SYNC_END   = 10'd755,
    parameter V_TOTAL = 10'd525,
    parameter V_VISIBLE = 10'd240,   // visible height used by user code
    parameter V_SYNC_LINE = 10'd494
)(
    input  wire clk,
    input  wire rst_n,
    output reg  [9:0] hcount,        // current horizontal pixel index 0..H_TOTAL-1
    output reg  [9:0] vcount,        // current vertical line index 0..V_TOTAL-1
    output reg        hsync,         // registered hsync (active low)
    output reg        vsync,         // registered vsync (active low)
    output reg        visible        // high when pixel is in visible region
);

    // combinational next-state signals
    reg [9:0] next_hcount;
    reg [9:0] next_vcount;
    reg       next_hsync;
    reg       next_vsync;
    reg       next_visible;

    // compute next counters and dependent signals combinationally
    always @(*) begin
        // next horizontal counter
        if (hcount == H_TOTAL - 1)
            next_hcount = 10'd0;
        else
            next_hcount = hcount + 10'd1;

        // next vertical counter increments when horizontal rolls
        if (hcount == H_TOTAL - 1) begin
            if (vcount == V_TOTAL - 1)
                next_vcount = 10'd0;
            else
                next_vcount = vcount + 10'd1;
        end
        else
            next_vcount = vcount;

        // derive syncs and visible from the NEXT counters (so outputs align with updated counters)
        next_hsync = (next_hcount >= H_SYNC_START && next_hcount <= H_SYNC_END) ? 1'b0 : 1'b1;
        next_vsync = (next_vcount == V_SYNC_LINE) ? 1'b0 : 1'b1;

        next_visible = (next_hcount < H_VISIBLE) && (next_vcount < V_VISIBLE);
    end

    // synchronous register updates (non-blocking)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hcount <= 10'd0;
            vcount <= 10'd0;
            hsync  <= 1'b1;
            vsync  <= 1'b1;
            visible<= 1'b0;
        end
        else begin
            hcount <= next_hcount;
            vcount <= next_vcount;
            hsync  <= next_hsync;
            vsync  <= next_vsync;
            visible<= next_visible;
        end
    end

endmodule