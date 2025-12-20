//////////////////////////////////////////////////////////////////////////////////
// Engineer:       twwang97
// Create Date:    2025-12-10
// Module Name:    camera_init_controller
// Project Name:   OV7670 Camera Initialization
// Target Devices: Basys-3
// 
// Description:
//  Top-level module to initialize an OV7670 camera using an on-chip ROM
//  (register table) and an SCCB master controller. The top module coordinates
//  the initialization sequence: it reads register address/value pairs from a
//  ROM table and drives the SCCB master to program the camera. The module
//  exposes SCCB signals (SCL, SDA) and basic camera control pins (PWDN, RESET).
//
//  This file is organized modularly: the top module instantiates three
//  submodules with clear interfaces:
//    - ov7670_init            : initialization sequencer (reads ROM, controls flow)
//    - ov7670_register_table  : ROM/register table (address/value pairs)
//    - ov7670_sccb_master     : SCCB/I2C-like master to write registers
//
//  Each submodule should be implemented in its own file for clarity and reuse.
//
// Parameters:
//  INPUT_CLK_FREQ - input clock frequency in Hz (default 25 MHz).
//////////////////////////////////////////////////////////////////////////////////

module camera_init_controller 
#(
    parameter INPUT_CLK_FREQ = 25_000_000  // default 25 MHz
)
(
    input  wire        clk,            // system clock (INPUT_CLK_FREQ)
    input  wire        rst_n,          // active-low reset for top-level
    input  wire        start,          // start initialization sequence
    output wire        done,           // initialization finished
    output wire        ov7670_clk,     // SCCB clock to ov7670
    output wire        ov7670_data,    // SCCB data to OV7670
    output wire        ov7670_pwdn,    // camera power down (active high)
    output wire        ov7670_reset    // camera reset (active low or high per HW)
);

    //-------------------------------------------------------------------------
    // Internal signals
    //-------------------------------------------------------------------------
    wire [15:0] dev_register_pair;     // data from register table (addr+value or packed)
    wire [7:0]  current_idx;           // index into register table
    wire [7:0]  sccb_reg_addr;         // register address to write
    wire [7:0]  sccb_reg_data;         // data to write to register
    wire        sccb_start_sign;       // pulse to start SCCB transaction
    wire        sccb_ready;            // SCCB master ready/idle indicator
    wire        sccb_clk;              // internal clock
    wire        sccb_data;             // internal data

    //-------------------------------------------------------------------------
    // Top-level pin assignments
    //-------------------------------------------------------------------------
    assign ov7670_clk = sccb_clk;
    assign ov7670_data = sccb_data;

    // Default camera control pins
    assign ov7670_pwdn  = 1'b0;  // keep camera powered on
    assign ov7670_reset = 1'b1;  // keep camera out of reset

    //-------------------------------------------------------------------------
    // Submodule: Initialization sequencer
    //  - Reads rom/register table
    //  - Generates sccb_start_sign and provides current_idx index
    //-------------------------------------------------------------------------
    ov7670_init #(
        .CLK_FREQ_HZ(INPUT_CLK_FREQ)
    ) ov7670_init_inst (
        .clk_25mhz(clk),
        .rst_n(rst_n),
        .sccb_ready(sccb_ready),
        .mem_reg_pair(dev_register_pair),
        .start_init(start),
        .mem_index(current_idx),
        .init_done(done),
        .out_addr(sccb_reg_addr),
        .out_data(sccb_reg_data),
        .sccb_start(sccb_start_sign)
    );

    //-------------------------------------------------------------------------
    // Submodule: Register table (ROM)
    //  - Provides register address/value pairs based on current_idx
    //-------------------------------------------------------------------------
    ov7670_register_table ov7670_register_inst (
        .clk(clk),
        .current_idx(current_idx),
        .dev_register_pair(dev_register_pair)
    );

    //-------------------------------------------------------------------------
    // Submodule: SCCB master
    //  - Performs SCCB/I2C-like transactions to program the camera
    //-------------------------------------------------------------------------
    ov7670_sccb_master #(
        .INPUT_CLK_FREQ(INPUT_CLK_FREQ)
    ) ov7670_sccb_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(sccb_start_sign),
        .mem_addr(sccb_reg_addr),
        .mem_data(sccb_reg_data),
        .ready(sccb_ready),
        .sccb_clk(sccb_clk),
        .sccb_data(sccb_data)
    );

endmodule