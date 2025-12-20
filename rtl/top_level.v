`timescale 1ns/1ns
module top_level(
  input  wire        clk,            // system clock (100 MHz)
  input  wire        reset,
  // input from OV7670
  input  wire        pclk,           // camera pixel clock
  input  wire        vsync,          // camera frame signal
  input  wire        href,           // camera pixel valid 
  input  wire [7:0]  camera_data,         // camera D-data
  // input from switches
  input  wire        simple_vga_flag, // To skip ov7670 setup and test VGA
  input  wire [3:0]  switch_state,    // four switches
  // output to LED light
  // output wire [5:0]  led_states, // debugging purpose
  // output to 7-segment display
  output wire [6:0]  hex7seg_pins,
  output wire        hex7seg_dp,
  output wire [3:0]  hex7seg_anode,
  // output to VGA
  output wire [3:0]  vga_red,
  output wire [3:0]  vga_green,
  output wire [3:0]  vga_blue,
  output wire        vga_hsync,
  output wire        vga_vsync,
  // output to OV7670 camera
  output wire        ov7670_scl,
  output wire        ov7670_sda,
  output wire        ov7670_xclk,
  output wire        ov7670_pwdn,
  output wire        ov7670_rst,
  output wire        is_display_ready
);

  // Internal clocks
  wire clk_50mhz, clk_25mhz;

  // Image format selector
  wire [3:0] image_mode;

  // memory interface signals
  wire        mem_write_enabled;
  wire [11:0] data_written;
  wire [16:0] addr_written;
  wire [11:0] data_read;
  wire [16:0] addr_read;
  wire        visible;

  // temporary wires for debugging purposes
  wire [5:0]  led_states;
  wire [3:0]  current_image_mode;

  // OV7670 setup status
  wire ov7670_setup_flag;
  wire ov7670_init_flag;

  // Capture pulse (one pulse per frame) generated in camera_interface
  wire capture_pulse; // currently not used

  // XCLK to camera is 25 MHz
  assign ov7670_xclk = clk_25mhz;
  assign rst_n       = ~reset;

  // 7-segment display (Disable other three 8s)
  assign hex7seg_dp    = 1'b0;
  assign hex7seg_anode = 4'b1110;

  // Clock generator
  xilinx_clk_wiz_pll_50_25mhz u_clock_gen (
    .clk_in1(clk),
    .resetn(rst_n),
    .clk_out50mhz(clk_50mhz),
    .clk_out25mhz(clk_25mhz)
  );
  
  // OV7670 init controller
  camera_init_controller #(
    .INPUT_CLK_FREQ(25000000) 
  ) u_ov7670_ctrl (
    .clk(clk_25mhz),
    .rst_n(rst_n),
    .start(ov7670_init_flag),
    .done(ov7670_setup_flag),
    .ov7670_clk(ov7670_scl),
    .ov7670_data(ov7670_sda),
    .ov7670_pwdn(ov7670_pwdn),
    .ov7670_reset(ov7670_rst)
  );

  // Status manager / FSM
  init_status_manager u_status_manager (
    .clk_25mhz(clk_25mhz),
    .rst_n(rst_n),
    .ov7670_cfg_done(ov7670_setup_flag),
    .capture_pulse(capture_pulse),
    .ov7670_setup_pulse(ov7670_init_flag),
    .led_state(led_states),
    .display_ready(is_display_ready),
    .force_test(simple_vga_flag)
  );

  // video frame buffer write: to pack RGB444 and write to memory
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

  // video frame buffer read: to read RGB444 from memory
  video_frame_buffer_read u_video_buf_read (
    .clk_25mhz(clk_25mhz),
    .rst_n(rst_n),
    .visible(visible),
    .video_hsync(vga_hsync),
    .video_vsync(vga_vsync),
    .generated_addr(addr_read)
  );

  // VGA display: image RGB444 -> VGA outputs
  video_out_manager u_top_video_out_manager (
    .clk_25mhz(clk_25mhz),
    .rst_n(rst_n),
    .visible(visible),
    .rgb444_data(data_read),
    .image_mode(current_image_mode),
    .red_out(vga_red),
    .green_out(vga_green),
    .blue_out(vga_blue)
  );

  // memory wrapper
  xilinx_blk_mem_gen_dual u_dual_memory (
    .clka(clk_50mhz),
    .wea(mem_write_enabled),
    .addra(addr_written),
    .dina(data_written),
    .clkb(clk_50mhz),
    .addrb(addr_read),
    .doutb(data_read)
  );

  // image selector from switches
  image_mode_controller u_img_format_select (
    .clk(clk_25mhz),
    .rst_n(rst_n),
    .sw(switch_state),
    .force_test(simple_vga_flag),
    .display_ready(is_display_ready),
    .image_mode(current_image_mode),
    .hex7seg_pins(hex7seg_pins)
  );

endmodule