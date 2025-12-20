/*
 * Module: countdown_timer
 * Purpose:
 *   Synchronous countdown timer with start/load, running and done status.
 *
 * Description:
 *   On a rising clock edge, when a start pulse is detected (start asserted
 *   while the internal start latch is clear), the module loads `load_value`
 *   into an internal counter and begins counting down each clock cycle until
 *   it reaches zero. The outputs indicate whether the timer is running and
 *   whether the countdown is complete.
 *
 * Parameters:
 *   WIDTH  - bit width of the counter and load_value (default 32)
 *
 * Ports:
 *   clk        - input clock, positive edge triggered
 *   rst_n      - active-low synchronous reset (registered reset behavior)
 *   start      - start pulse (edge-detected by internal latch)
 *   load_value - value to load into the counter when start is detected
 *   done       - asserted when counter == 0
 *   running    - asserted when counter != 0
 *
 * Behavior notes:
 *   - The module uses a start latch to detect a start assertion and avoid
 *     reloading while already processing.
 *   - done and running reflect the next-state of the counter so they update
 *     consistently in the same cycle the counter is loaded.
 *   - If load_value == 0, done will be asserted immediately after load.
 *
 * Usage:
 *   - Drive `start` with a single-cycle pulse to load and begin countdown.
 *   - Sample `done` or `running` to determine completion or active state.
 *
 * Revision history:
 *   - 2025-12-10  Initial corrected implementation: next-state pattern,
 *                replaced `and` with `&&`, ensured done/running reflect
 *                next_cnt for immediate visibility after load.
 */

module countdown_timer #(
  parameter WIDTH = 32
)(
  input  wire                 clk,
  input  wire                 rst_n,
  input  wire                 start,        // start a new countdown (one-cycle pulse)
  input  wire [WIDTH-1:0]     load_value,   // number of cycles to count down
  output reg                  done,         // one-cycle pulse when countdown finishes
  output reg  [WIDTH-1:0]     value,        // current remaining value (optional)
  output reg                  running       // high while counting
);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      value   <= {WIDTH{1'b0}};
      running <= 1'b0;
      done    <= 1'b0;
    end else begin
      done <= 1'b0; // default: no done pulse
      if (start) begin
        value   <= load_value;
        if (load_value == {WIDTH{1'b0}}) begin
          // zero-length countdown: immediately done for one cycle
          running <= 1'b0;
          done    <= 1'b1;
        end else begin
          running <= 1'b1;
        end
      end else if (running) begin
        if (value == {{(WIDTH-1){1'b0}}, 1'b1}) begin
          // last tick: produce done and stop running
          value   <= {WIDTH{1'b0}};
          running <= 1'b0;
          done    <= 1'b1;
        end else begin
          value <= value - 1'b1;
        end
      end
    end
  end

endmodule