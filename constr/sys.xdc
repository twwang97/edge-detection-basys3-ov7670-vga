# -------------------------------------------------------------------------------------------
# File     : sys.xdc
# Purpose  : Pin assignments to Basys-3 for our camera OV7670, VGA, LEDs, and switches
# Device   : xc7a35tcpg236-1
# Author   : twwang97
# Date     : 2025-12-10
# Schematic:
# https://digilent.com/reference/_media/reference/programmable-logic/basys-3/basys-3_sch.pdf
# -------------------------------------------------------------------------------------------

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]

#################################################
#                                               #
#                 Clock Source                  #
#                                               #
#################################################

# System Clock (on Basys-3) (100 MHz)
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
# The default system clock (100 MHz) is drived the the Xilinx clocking wizard.
#create_clock -period 10.000 -name clk -waveform {0.000 5.000} -add [get_ports clk]

# Default ov7670_xclk is drived by the clocking wizard (25 MHz).
create_clock -name ov7670_xclk -period 40.0 [get_ports ov7670_xclk] -waveform {0 20}
# For 25-MHz pixel clock (camera drives FPGA):
create_clock -name ov7670_pclk -period 40.0 [get_ports ov7670_pclk]

#################################################
#                                               #
#                    Timing                     #
#                                               #
#################################################

# --- To avoid timing analysis across the two independent domains (camera PLL vs FPGA)
set_clock_groups -asynchronous -group [get_clocks ov7670_xclk] -group [get_clocks ov7670_pclk]

# --- Our reset is asserted asynchronously in frame buffer write
set_false_path -from [get_ports reset] -to [get_clocks ov7670_pclk]

# --- Switches  ---
set_false_path -from [get_clocks clk] -to [get_ports {simple_vga_flag switch_state[3:0]}]

# Set input delays for camera → FPGA signals
set_input_delay -clock ov7670_pclk -max 5.0 [get_ports {ov7670_data[0] ov7670_data[1] ov7670_data[2] ov7670_data[3] ov7670_data[4] ov7670_data[5] ov7670_data[6] ov7670_data[7] ov7670_href ov7670_vsync}]
set_input_delay -clock ov7670_pclk -min 0.5 [get_ports {ov7670_data[0] ov7670_data[1] ov7670_data[2] ov7670_data[3] ov7670_data[4] ov7670_data[5] ov7670_data[6] ov7670_data[7] ov7670_href ov7670_vsync}]

# --- Set output delay for XCLK (if FPGA drives it)
# --- --- set_output_delay is normally used when an external device samples data driven by the FPGA (data relative to an external clock). 
# --- --- For a driven clock pin, create_clock is preferred.
#set_output_delay -clock [get_clocks ov7670_xclk] -max 0.8 [get_ports ov7670_xclk]
#set_output_delay -clock [get_clocks ov7670_xclk] -min 1.3 [get_ports ov7670_xclk]

# --- Mark I2C paths asynchronous to video clocks
set_false_path -from [get_pins -of_objects [get_nets -of_objects [get_ports ov7670_scl]]] -to [get_clocks ov7670_pclk]
set_false_path -from [get_pins -of_objects [get_nets -of_objects [get_ports ov7670_sda]]] -to [get_clocks ov7670_pclk]
set_false_path -from [get_clocks ov7670_pclk] -to [get_pins -of_objects [get_nets -of_objects [get_ports ov7670_scl]]]
set_false_path -from [get_clocks ov7670_pclk] -to [get_pins -of_objects [get_nets -of_objects [get_ports ov7670_sda]]]

# --- VGA outputs: external sampling by DAC/monitor ---
set_output_delay -clock clk -max 6.5 [get_ports {vga_red[3:0] vga_green[3:0] vga_blue[3:0] vga_hsync vga_vsync}]
set_output_delay -clock clk -min 1.0 [get_ports {vga_red[3:0] vga_green[3:0] vga_blue[3:0] vga_hsync vga_vsync}]

# --- Seven-segment display: asynchronous visual outputs ---
set_false_path -from [get_clocks clk] -to [get_ports {hex7seg_pins[6:0] hex7seg_dp hex7seg_anode[3:0]}]

#################################################
#                                               #
#                     VGA                       #
#                                               #
#################################################

set_property PACKAGE_PIN G19 [get_ports {vga_red[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_red[0]}]
set_property PACKAGE_PIN H19 [get_ports {vga_red[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_red[1]}]
set_property PACKAGE_PIN J19 [get_ports {vga_red[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_red[2]}]
set_property PACKAGE_PIN N19 [get_ports {vga_red[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_red[3]}]

set_property PACKAGE_PIN J17 [get_ports {vga_green[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_green[0]}]
set_property PACKAGE_PIN H17 [get_ports {vga_green[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_green[1]}]
set_property PACKAGE_PIN G17 [get_ports {vga_green[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_green[2]}]
set_property PACKAGE_PIN D17 [get_ports {vga_green[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_green[3]}]

set_property PACKAGE_PIN N18 [get_ports {vga_blue[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_blue[0]}]
set_property PACKAGE_PIN L18 [get_ports {vga_blue[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_blue[1]}]
set_property PACKAGE_PIN K18 [get_ports {vga_blue[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_blue[2]}]
set_property PACKAGE_PIN J18 [get_ports {vga_blue[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_blue[3]}]

set_property PACKAGE_PIN P19 [get_ports vga_hsync]
set_property IOSTANDARD LVCMOS33 [get_ports vga_hsync]
set_property PACKAGE_PIN R19 [get_ports vga_vsync]
set_property IOSTANDARD LVCMOS33 [get_ports vga_vsync]

#################################################
#                                               #
#                     LED                       #
#                                               #
#################################################

# LED 1~6
#set_property PACKAGE_PIN U16 [get_ports {led_states[0]}]					
#set_property IOSTANDARD LVCMOS33 [get_ports {led_states[0]}]
#set_property PACKAGE_PIN E19 [get_ports {led_states[1]}]					
#set_property IOSTANDARD LVCMOS33 [get_ports {led_states[1]}]
#set_property PACKAGE_PIN U19 [get_ports {led_states[2]}]					
#set_property IOSTANDARD LVCMOS33 [get_ports {led_states[2]}]
#set_property PACKAGE_PIN V19 [get_ports {led_states[3]}]					
#set_property IOSTANDARD LVCMOS33 [get_ports {led_states[3]}]
#set_property PACKAGE_PIN W18 [get_ports {led_states[4]}]					
#set_property IOSTANDARD LVCMOS33 [get_ports {led_states[4]}]
#set_property PACKAGE_PIN U15 [get_ports {led_states[5]}]					
#set_property IOSTANDARD LVCMOS33 [get_ports {led_states[5]}]

# LED 16
set_property PACKAGE_PIN L1 [get_ports {is_display_ready}]					
set_property IOSTANDARD LVCMOS33 [get_ports {is_display_ready}]

#################################################
#                                               #
#                   Switch                      #
#                                               #
#################################################

set_property PACKAGE_PIN V17 [get_ports {simple_vga_flag}]
set_property IOSTANDARD LVCMOS33 [get_ports {simple_vga_flag}]
set_property PACKAGE_PIN V16 [get_ports {switch_state[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {switch_state[0]}]
set_property PACKAGE_PIN W16 [get_ports {switch_state[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {switch_state[1]}]
set_property PACKAGE_PIN W17 [get_ports {switch_state[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {switch_state[2]}]
set_property PACKAGE_PIN W15 [get_ports {switch_state[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {switch_state[3]}]
set_property PACKAGE_PIN R2 [get_ports {reset}]
set_property IOSTANDARD LVCMOS33 [get_ports {reset}]

#################################################
#                                               #
#                PMOD for OV7670                #
#                                               #
#################################################

## Pmod Header JB for our camera OV7670
# schematic_name = JB1
set_property PACKAGE_PIN A14 [get_ports {ov7670_pwdn}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_pwdn}]
# schematic_name = JB2
set_property PACKAGE_PIN A16 [get_ports {ov7670_data[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_data[0]}]
# schematic_name = JB3
set_property PACKAGE_PIN B15 [get_ports {ov7670_data[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_data[2]}]
# schematic_name = JB4
set_property PACKAGE_PIN B16 [get_ports {ov7670_data[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_data[4]}]
# schematic_name = JB7
set_property PACKAGE_PIN A15 [get_ports {ov7670_rst}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_rst}]
# schematic_name = JB8
set_property PACKAGE_PIN A17 [get_ports {ov7670_data[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_data[1]}]
# schematic_name = JB9
set_property PACKAGE_PIN C15 [get_ports {ov7670_data[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_data[3]}]
# schematic_name = JB10
set_property PACKAGE_PIN C16 [get_ports {ov7670_data[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_data[5]}]

## Pmod Header JC for our camera OV7670
# schematic_name = JC1
set_property PACKAGE_PIN K17 [get_ports {ov7670_data[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_data[6]}]
# schematic_name = JC2
set_property PACKAGE_PIN M18 [get_ports {ov7670_xclk}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_xclk}]
# schematic_name = JC3
set_property PACKAGE_PIN N17 [get_ports {ov7670_href}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_href}]
# schematic_name = JC4
set_property PACKAGE_PIN P18 [get_ports {ov7670_sda}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_sda}]
# schematic_name = JC7
set_property PACKAGE_PIN L17 [get_ports {ov7670_pclk}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_pclk}]
# schematic_name = JC8
set_property PACKAGE_PIN M19 [get_ports {ov7670_data[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_data[7]}]
# schematic_name = JC9
set_property PACKAGE_PIN P17 [get_ports {ov7670_vsync}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_vsync}]
# schematic_name = JC10
set_property PACKAGE_PIN R18 [get_ports {ov7670_scl}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_scl}]

#################################################
#                                               #
#  7-segment display                            #
#  - To map hex7seg_pins bits to outputs        #
#  - Namely, hex7seg_pins[6] -> a               #
#            ... hex7seg_pins[0] -> g           #
#                                               #
#################################################

set_property PACKAGE_PIN W7 [get_ports {hex7seg_pins[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hex7seg_pins[6]}]
set_property PACKAGE_PIN W6 [get_ports {hex7seg_pins[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hex7seg_pins[5]}]
set_property PACKAGE_PIN U8 [get_ports {hex7seg_pins[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hex7seg_pins[4]}]
set_property PACKAGE_PIN V8 [get_ports {hex7seg_pins[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hex7seg_pins[3]}]
set_property PACKAGE_PIN U5 [get_ports {hex7seg_pins[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hex7seg_pins[2]}]
set_property PACKAGE_PIN V5 [get_ports {hex7seg_pins[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hex7seg_pins[1]}]
set_property PACKAGE_PIN U7 [get_ports {hex7seg_pins[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hex7seg_pins[0]}]
set_property PACKAGE_PIN V7 [get_ports hex7seg_dp]
set_property IOSTANDARD LVCMOS33 [get_ports hex7seg_dp]
set_property PACKAGE_PIN U2 [get_ports {hex7seg_anode[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hex7seg_anode[0]}]
set_property PACKAGE_PIN U4 [get_ports {hex7seg_anode[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hex7seg_anode[1]}]
set_property PACKAGE_PIN V4 [get_ports {hex7seg_anode[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hex7seg_anode[2]}]
set_property PACKAGE_PIN W4 [get_ports {hex7seg_anode[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hex7seg_anode[3]}]