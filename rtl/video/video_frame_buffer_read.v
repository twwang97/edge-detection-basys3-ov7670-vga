// -----------------------------------------------------------------------------
// Module : video_frame_buffer_read
// Purpose: Generate VGA timing signals (HSYNC/VSYNC), manage horizontal and
//          vertical counters for a 320x240 timing domain, define a visible
//          region of 320x240, and compute the memory read address for 
//          the visible pixels.
// Inputs : clk_25mhz    - 25 MHz pixel clock
//          rst_n        - active-low reset
// Outputs: generated_addr - 17-bit address to read pixel data from memory
// Notes  : Visible region is defined as hcount < 320 and vcount < 240.
// -----------------------------------------------------------------------------

module video_frame_buffer_read (
    input  wire        clk_25mhz,
    input  wire        rst_n,
    output wire        visible,
    output wire        video_hsync,
    output wire        video_vsync,
    output wire [16:0] generated_addr
);

    // internal wires
    wire [9:0] hcount, vcount;
    wire [16:0] addr;

    // timing generator instance
    video_time_generator timing_inst (
        .clk(clk_25mhz),
        .rst_n(rst_n),
        .hcount(hcount),
        .vcount(vcount),
        .hsync(video_hsync),
        .vsync(video_vsync),
        .visible(visible)
    );

    // address generator instance
    video_address_generator addr_inst (
        .clk(clk_25mhz),
        .rst_n(rst_n),
        .hcount(hcount),
        .vcount(vcount),
        .visible(visible),
        .mem_addr(addr)
    );

    // expose address
    assign generated_addr = addr;

endmodule