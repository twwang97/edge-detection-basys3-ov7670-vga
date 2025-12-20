# config.tcl
namespace eval config {
  variable origin_dir "."
  variable xilinx_proj_name "ov7670_vga_twwang97_proj"
  variable fpga_part_name "xc7a35tcpg236-1"
  variable default_lib "xil_defaultlib"
  variable top_source_name "top_level"
  variable top_tb_name "tb_image_display"
}

namespace eval files {
  variable vhdl_rel_files {
    rtl/task/debounce_4switches.v
    rtl/task/hex7seg_display.v
    rtl/task/image_mode_controller.v
    rtl/task/countdown_timer.v
    rtl/task/init_status_manager.v
    rtl/video/video_frame_buffer_write.v
    rtl/video/video_address_generator.v
    rtl/video/video_time_generator.v
    rtl/video/video_frame_buffer_read.v
    rtl/video/active_stable.v
    rtl/video/colorbar_gen.v
    rtl/video/video_out_original.v
    rtl/filtering/filter_sobel.v
    rtl/filtering/filter_edge_weighted.v
    rtl/video/video_out_manager.v
    rtl/ov7670/ov7670_sccb_master.v
    rtl/ov7670/ov7670_register_table.v
    rtl/ov7670/ov7670_init.v
    rtl/task/camera_init_controller.v
    rtl/top_level.v
  }
  variable ip_file "rtl/xilinx_blk_mem_gen_dual.xci"
  variable ip_file2 "rtl/xilinx_clk_wiz_pll_50_25mhz.xci"
  variable xdc_file "constr/sys.xdc"
  variable tb_file  "xsim/tb_image_display.v"
}