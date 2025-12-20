/*
 * image_mode_controller.v
 *
 * Purpose
 *   Provide a stable, debounced image mode selector driven by four asynchronous
 *   switches and present the selected mode on a 7-segment display.
 *
 * Functional summary
 *   - Debounces a 4-bit raw switch input and converts it into a stable image
 *     mode value.
 *   - Forces a static (test) display mode when `force_test` is asserted or
 *     when the external `display_ready` signal is low.
 *   - When not in static mode, maps the debounced switch state to an image
 *     mode by adding 1 (so switch state 0 -> mode 1, etc.).
 *   - Drives a 7-segment display module with the current image_mode.
 *
 * Interface
 *   Inputs
 *     clk         : system clock
 *     rst_n       : active-low synchronous reset
 *     sw[3:0]     : raw asynchronous switches (debounced internally)
 *     force_test  : override to force static/test display mode
 *     display_ready: indicates whether the display subsystem is ready
 *
 *   Outputs
 *     image_mode[3:0] : debounced and mapped image mode (register)
 *     hex7seg_pins[6:0]: 7-segment display pins driven by hex7seg_display
 *
 * Dependencies
 *   - debounce_4switches : provides stable_sw_state from raw sw inputs
 *   - hex7seg_display    : converts image_mode to 7-seg pin pattern
 *
 * Behavior and reset
 *   - On reset, image_mode is cleared to 0.
 *   - While `force_test` is asserted or `display_ready` is false, image_mode
 *     remains 0 (static display mode).
 *   - Otherwise image_mode follows debounced switch state + 1 on each clock.
 *
 * Notes
 *   - The +1 mapping is intentional to reserve mode 0 for static/test state.
 *   - Ensure debounce and 7-seg modules meet timing and reset requirements for
 *     your target FPGA or board.
 *
 * Revision
 *   v1.0  Initial implementation
 */

module image_mode_controller (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [3:0]  sw,            // raw asynchronous switches
    input  wire        force_test,
    input  wire        display_ready,
    output reg  [3:0]  image_mode,    // debounced output
    output wire [6:0]  hex7seg_pins   // 7-segment display
);

    // internal wires
    wire [3:0] stable_sw_state;
    wire       static_display_mode;
    assign static_display_mode = force_test || (!display_ready);

    // instantiate 4-switch instance
    debounce_4switches switch_inst (
        .clk(clk),
        .rst_n(rst_n),
        .sw(sw),
        .state_out(stable_sw_state)
    );

    // instantiate 7-segment display instance
    hex7seg_display hex7seg_inst (
        .clk(clk),
        .rst_n(rst_n),
        .input_state(image_mode),
        .display_pins(hex7seg_pins)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            image_mode <= 4'b0000;
        end else begin
            if (static_display_mode)
                image_mode <= 4'b0000;
            else
                image_mode <= stable_sw_state + 4'b0001;
        end
    end

endmodule