//-----------------------------------------------------------------------------
// Module  : init_status_manager.v
// Purpose : Top-level control FSM for OV7670 capture and VGA display
// Author  : twwang97
// Date    : 2025-12-10
//
// Description:
//   Controls OV7670 hardware setup, generates one-cycle start pulses for
//   capture, and drives status LEDs. Uses an active-low asynchronous reset.
//   Clock: 25 MHz.
//
// Ports:
//   input  clk_25mhz          : 25 MHz system clock
//   input  rst_n              : active-low asynchronous reset
//   input  ov7670_cfg_done    : OV7670 setup complete (pulse or level)
//   input  force_test         : bypass setup for test
//   output capture_pulse      : one-cycle capture start
//   output ov7670_setup_pulse : one-cycle setup start
//   output [5:0] led_state    : status LEDs
//   output display_ready      : VGA display ready
//-----------------------------------------------------------------------------

module init_status_manager #(
    parameter CLK_FREQ_HZ = 25_000_000,
    parameter TIMER_WIDTH = 32
) (
    input  wire        clk_25mhz,
    input  wire        rst_n,
    input  wire        ov7670_cfg_done,
    input  wire        force_test,
    output wire        capture_pulse,
    output wire        ov7670_setup_pulse,
    output wire [5:0]  led_state,
    output wire        display_ready
);

  // Convert ms to cycles (integer division)
  localparam integer MS_TO_CYCLES = CLK_FREQ_HZ / 1000 / 2; // 0.5 second

  // FSM states
  localparam START_STATE        = 3'd0;
  localparam START_SET_STATE    = 3'd1;
  localparam OV7670_SETUP_STATE = 3'd2;
  localparam VGA_DISPLAY_STATE  = 3'd3;
  localparam WAIT_TIMER_STATE   = 3'd4;

  // Registers
  reg                    display_ready_reg;
  reg [2:0]              control_state;
  reg [2:0]              return_state;
  reg [5:0]              led_state_reg;

  // Pulse signals (internal)
  reg                    start_capture_pulse;
  reg                    ov7670_setup_pulse_reg;

  // Timer interface
  reg  [TIMER_WIDTH-1:0] timer_load;
  reg                    timer_start;
  wire                   timer_done;
  wire [TIMER_WIDTH-1:0] timer_value;
  wire                   timer_running;

  // Instantiate countdown timer
  countdown_timer #(
    .WIDTH(TIMER_WIDTH)
  ) u_timer (
    .clk(clk_25mhz),
    .rst_n(rst_n),
    .start(timer_start),
    .load_value(timer_load),
    .done(timer_done),
    .value(timer_value),
    .running(timer_running)
  );

  // Output assignments
  assign display_ready = display_ready_reg;
  assign capture_pulse = start_capture_pulse;
  assign ov7670_setup_pulse = ov7670_setup_pulse_reg;
  assign led_state = led_state_reg;

  // FSM
  always @(posedge clk_25mhz or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all registers to known values
      control_state          <= START_STATE;
      display_ready_reg      <= 1'b0;
      return_state           <= START_STATE;
      led_state_reg          <= 6'b000000;
      start_capture_pulse    <= 1'b0;
      ov7670_setup_pulse_reg <= 1'b0;
      timer_load             <= {TIMER_WIDTH{1'b0}};
      timer_start            <= 1'b0;
    end else begin
      // Default: clear single-cycle pulses and timer_start
      start_capture_pulse <= 1'b0;
      ov7670_setup_pulse_reg <= 1'b0;
      timer_start <= 1'b0;

      case (control_state)
        START_STATE: begin
          display_ready_reg <= 1'b0;
          led_state_reg <= 6'b000001;
          if (force_test) begin
            control_state <= VGA_DISPLAY_STATE;
          end else begin
            // wait 50 cycles then go to START_SET
            control_state <= WAIT_TIMER_STATE;
            timer_load <= 32'd50;
            timer_start <= 1'b1;
            return_state <= START_SET_STATE;
          end
        end

        START_SET_STATE: begin
          // trigger OV7670 hw setup (one-cycle pulse)
          ov7670_setup_pulse_reg <= 1'b1;
          led_state_reg <= 6'b000011;
          control_state <= WAIT_TIMER_STATE;
          timer_load <= 32'd1;
          timer_start <= 1'b1;
          return_state <= OV7670_SETUP_STATE;
        end

        OV7670_SETUP_STATE: begin
          // ensure start pulse is only one cycle (already pulsed in START_SET)
          // wait for configuration done or force_test, then wait 300 ms for stability
          led_state_reg <= 6'b001111;
          if (ov7670_cfg_done || force_test) begin
            control_state <= WAIT_TIMER_STATE;
            return_state <= VGA_DISPLAY_STATE;
            // 300 ms stabilization time
            timer_load <= MS_TO_CYCLES * 300;
            timer_start <= 1'b1;
          end else begin
            // remain in this state until ov7670_cfg_done or force_test
            control_state <= OV7670_SETUP_STATE;
          end
        end

        VGA_DISPLAY_STATE: begin
          display_ready_reg <= 1'b1;
          // generate a single-cycle capture_pulse pulse
          start_capture_pulse <= 1'b1;
          led_state_reg <= 6'b111111;
          // Remain in VGA_DISPLAY until external reset or other event (modify as needed)
          control_state <= VGA_DISPLAY_STATE;
        end

        WAIT_TIMER_STATE: begin
          // Wait for the timer to assert done
          led_state_reg <= 6'b101010;
          if (timer_done) begin
            control_state <= return_state;
          end else begin
            control_state <= WAIT_TIMER_STATE;
          end
        end

        default: begin
          control_state <= START_STATE;
        end
      endcase
    end
  end

endmodule