`timescale 1ns/1ns
/*
  tb_image_display.v — Testbench purpose

  - Purpose:
    Provide a self-contained behavioral testbench that verifies the image
    capture → framebuffer → VGA display pipeline used with an OV7670-like
    camera source and a dual-port block RAM.

  - What it simulates:
    * Camera side: generates camera pixel clock (pclk), vsync, href and
      incrementing 8-bit camera_data to emulate a streaming OV7670 output.
    * System clocks: produces 100 MHz, 50 MHz and 25 MHz clock (clk_sim_25mhz)
      to replace vendor PLLs for simulation.
    * Memory: instantiates a dual-port block memory to model the frame buffer
      (write port clocked by pclk, read port clocked by 25 MHz).
    * Video pipeline: instantiates video_frame_buffer_write, video_frame_buffer_read,
      and video_out_manager to exercise packing, storing, reading and converting
      RGB444 image data to VGA outputs.

  - Test behavior and termination:
    * Applies reset, then asserts vsync/href to start a frame and streams
      camera_data on pclk.
    * Monitors vga_vsync to count frames and automatically finishes the
      simulation after two frames, printing a completion message.

  - Notes for use:
    * Replace or adapt stimulus (vsync/href timing, camera_data pattern) to
      exercise different image scenarios.
    * Timing parameters (clock periods) are defined in the TB and can be
      adjusted for alternate simulation speeds.
*/

module tb_image_display;
// module tb_vga;
  // inputs
  reg        clk;            // system clock (100 MHz)
  reg        rst_n;
  // input from OV7670
  reg        pclk;           // camera pixel clock (25 MHz)
  reg        vsync;          // camera frame signal
  reg        href;           // camera pixel valid 
  reg [7:0]  camera_data;    // camera D-data

  // outputs
  // output to VGA
  wire [3:0] vga_red, vga_green, vga_blue;
  wire       vga_hsync, vga_vsync;

  // Internal clocks (behavioral in TB)
  reg  clk_50mhz;            // 50 MHz generated in TB
  reg  clk_25mhz;            // 25 MHz generated in TB
  wire clk_sim_25mhz;        // used by read/display modules

  // finish after two frames
  reg vga_vsync_prev;
  reg [1:0] frame_count;

  // memory interface signals
  wire        mem_write_enabled;
  wire [11:0] data_written;
  wire [16:0] addr_written;
  wire [11:0] data_read;
  wire [16:0] addr_read;
  wire        visible;

  // -----------------------------------------------------------------------
  // Replace vendor PLL with simple TB-generated clocks
  // -----------------------------------------------------------------------
  // 100 MHz clock period 10 ns
  localparam integer CLK_PERIOD_100MHZ = 10;
  initial clk = 0;
  always #(CLK_PERIOD_100MHZ/2) clk = ~clk;

  // 50 MHz clock (period 20 ns)
  initial clk_50mhz = 0;
  always #10 clk_50mhz = ~clk_50mhz;

  // 25 MHz clock (period 40 ns)
  initial clk_25mhz = 0;
  always #20 clk_25mhz = ~clk_25mhz;

  // Use the simulated 25 MHz directly for modules that expect clk_sim_25mhz
  assign clk_sim_25mhz = clk_25mhz;

  // -----------------------------------------------------------------------
  // Module instantiations (unchanged interfaces)
  // -----------------------------------------------------------------------

  // video frame buffer write: pack RGB444 and write to memory (writes synchronous to pclk)
  video_frame_buffer_write u_video_buf_write (
    .clk(pclk),
    .rst_n(rst_n),
    .vsync(vsync),
    .href(href),
    .frame_din(camera_data),
    .mem_din(data_written),
    .mem_addr(addr_written),
    .mem_we(mem_write_enabled)
  );

  // video frame buffer read: read RGB444 from memory
  video_frame_buffer_read u_video_buf_read (
    .clk_25mhz(clk_sim_25mhz),
    .rst_n(rst_n),
    .visible(visible),
    .video_hsync(vga_hsync),
    .video_vsync(vga_vsync),
    .generated_addr(addr_read)
  );

  // VGA display: image RGB444 -> VGA outputs
  video_out_manager u_top_video_out_manager (
    .clk_25mhz(clk_sim_25mhz),
    .rst_n(rst_n),
    .visible(visible),
    .rgb444_data(data_read),
    .image_mode(4'b0001), // RGB444 mode
    .red_out(vga_red),
    .green_out(vga_green),
    .blue_out(vga_blue)
  );

  // memory wrapper
  xilinx_blk_mem_gen_dual u_dual_memory (
    .clka(pclk),            // write port clock aligned with write logic
    .wea(mem_write_enabled),
    .addra(addr_written),
    .dina(data_written),
    .clkb(clk_25mhz),       // read port clock aligned with read/display logic
    .addrb(addr_read),
    .doutb(data_read)
  );

  // -----------------------------------------------------------------------
  // pclk generator (25 MHz) - toggle pclk itself
  // -----------------------------------------------------------------------
  initial pclk = 0;
  always #(20) pclk = ~pclk;

  // -----------------------------------------------------------------------
  // initial reset and basic inits
  // -----------------------------------------------------------------------
  initial begin
    rst_n = 0; // assert reset
    vsync = 0;
    href  = 0;
    camera_data = 8'h00;
    #200;
    rst_n = 1; // deassert
    vga_vsync_prev  = 1'b0;
    frame_count = 2'b00;
  end

  // simple frame/control stimulus
  initial begin
    #500;
    vsync = 1;
    #80;
    vsync = 0;
    #120;
    href = 1;
    // camera_data is driven by the pclk generator below
  end

  // camera data generator: single driver for camera_data
  always @(posedge pclk or negedge rst_n) begin
    if (!rst_n)
      camera_data <= 8'h00;
    else if (camera_data < 8'hFF)
      camera_data <= camera_data + 1;
    else
      camera_data <= 8'h00;
  end

  // sample vga_vsync on pclk to detect rising edge reliably
  always @(posedge pclk or negedge rst_n) begin
    if (!rst_n) begin
      vga_vsync_prev  <= 1'b0;
      frame_count <= 2'b00;
    end else begin
      vga_vsync_prev <= vga_vsync;
      // detect falling edge: current vga_vsync low, previous high
      if (!vga_vsync && vga_vsync_prev) begin
        frame_count <= frame_count + 1;
        if (frame_count > 0) begin
          $display("Simulation finished after %0d frames at time %0t", frame_count + 1, $time);
          $finish;
        end
      end
    end
  end

endmodule