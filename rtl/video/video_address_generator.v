// -----------------------------------------------------------------------------
// Memory address generator for visible region (no general multiplier).
// Maintains a line_base that increments by 320 at end of each line.
// -----------------------------------------------------------------------------
module video_address_generator #(
    parameter H_VISIBLE = 10'd320,
    parameter V_VISIBLE = 10'd240,
    parameter H_TOTAL = 10'd800
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [9:0] hcount,
    input  wire [9:0] vcount,
    input  wire        visible,
    output reg  [16:0] mem_addr // 17-bit address (enough for 320*240)
);

    // line_base holds the starting address for the current line (visible lines only)
    reg [16:0] line_base;

    // We update line_base at the end of each line (when hcount rolls).
    // Use non-blocking updates in sequential block; compute next_line_base combinationally.
    reg [16:0] next_line_base;

    always @(*) begin
        // default: hold
        next_line_base = line_base;

        // when horizontal counter rolls, update line_base for next line
        if (hcount == H_TOTAL - 1) begin
            // if next vcount wraps to 0 (end of frame), reset line_base
            if (vcount == (10'd525 - 1))
                next_line_base = 17'd0;
            else begin
                // if current line is visible, increment base by 320 for next line
                // else if current line is the last visible line, next line base should be 0
                if (vcount < V_VISIBLE - 1)
                    next_line_base = line_base + 17'd320;
                else
                    next_line_base = 17'd0;
            end
        end
    end

    // compute mem_addr for the pixel that will be displayed this cycle.
    // We use line_base (base for current line) + hcount + 1 (keeps original +1 behavior).
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            line_base <= 17'd0;
            mem_addr <= 17'd0;
        end
        else begin
            line_base <= next_line_base;

            if (visible) begin
                // safe addition: line_base + hcount fits in 17 bits for 320x240
                mem_addr <= line_base + {7'd0, hcount} + 17'd1;
            end
            else begin
                // outside visible region: clear address
                mem_addr <= 17'd0;
            end
        end
    end

endmodule