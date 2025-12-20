// -----------------------------------------------------------------------------
// Pixel output module: selects test pattern or memory data and registers RGB outputs.
// -----------------------------------------------------------------------------
module video_out_original (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enabled,
    input  wire [11:0] rgb444_data,
    output reg  [3:0]  red_out,
    output reg  [3:0]  green_out,
    output reg  [3:0]  blue_out
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            red_out   <= 4'b0000;
            green_out <= 4'b0000;
            blue_out  <= 4'b0000;
        end
        else if (enabled) begin
            red_out   <= rgb444_data[11:8];
            green_out <= rgb444_data[7:4];
            blue_out  <= rgb444_data[3:0];
        end
        else begin
            red_out   <= 4'b0000;
            green_out <= 4'b0000;
            blue_out  <= 4'b0000;
        end
    end
endmodule