/*
Module: ov7670_init
Purpose: Initialize an OV7670 camera by sequencing register writes from an on‑chip ROM
         and controlling the SCCB interface until configuration is complete.

Description:
  - Reads 16-bit ROM entries in the format {mem_reg_pair[15:8], mem_reg_pair[7:0]}.
  - Special ROM codes:
      16'hFFF0 -> insert a delay (timer = CLK_FREQ_HZ / 100, i.e., 10 ms at 25 MHz)
      16'hFFFF -> end of ROM sequence, assert done.
  - Waits for sccb_ready before issuing each SCCB transaction.
  - Produces current_idx index, SCCB address/data, and a start strobe for the SCCB master.
  - Finite state machine states: IDLE, SEND, TIMER, DONE.

Parameters:
  - CLK_FREQ_HZ : clock frequency used to compute delays (default 25_000_000).

Inputs:
  - clk_25mhz    : input clock (25 MHz)
  - rst_n        : active-low reset
  - sccb_ready   : indicates SCCB master is ready for a new transaction
  - mem_reg_pair : 16-bit ROM output containing {address, data} or special codes
  - start_init   : start initialization sequence

Outputs:
  - mem_index    : memory index selector (increments per memory entry)
  - init_done    : asserted when initialization completes
  - out_addr     : register address to write via SCCB
  - out_data     : data to write to the register
  - sccb_start   : strobe to trigger SCCB transaction

Notes:
  - Designed for synchronous operation on the rising edge of clk_25mhz.
  - Adjust CLK_FREQ_HZ if using a different clock frequency to keep delays accurate.
  - This header is intended to be placed at the top of the Verilog file above the module declaration.
*/

module ov7670_init
#(
    parameter CLK_FREQ_HZ = 25_000_000
)
(
    input  wire        clk_25mhz,
    input  wire        rst_n,
    input  wire        sccb_ready,        // SCCB interface ready flag
    input  wire [15:0] mem_reg_pair,      // register pairs from ROM (pair[15:8], pair[7:0])
    input  wire        start_init,        // start initialization sequence
    output wire [7:0]  mem_index,         // index into ROM sequence
    output wire        init_done,         // high when initialization finished
    output wire [7:0]  out_addr,          // address to send over SCCB
    output wire [7:0]  out_data,          // data to send over SCCB
    output wire        sccb_start         // pulse to start SCCB transaction
);

    // Internal registers
    reg [2:0] state_reg;
    reg [2:0] return_state_reg;
    reg [31:0] delay_cnt;
    reg [7:0] mem_index_reg;
    reg init_done_reg;
    reg [7:0] out_addr_reg;
    reg [7:0] out_data_reg;
    reg sccb_start_reg;

    // Output assignments
    assign mem_index   = mem_index_reg;
    assign init_done   = init_done_reg;
    assign out_addr    = out_addr_reg;
    assign out_data    = out_data_reg;
    assign sccb_start  = sccb_start_reg;

    // FSM state encoding (renamed)
    localparam ST_IDLE  = 3'd0;
    localparam ST_SEND  = 3'd1;
    localparam ST_DONE  = 3'd2;
    localparam ST_WAIT  = 3'd3;

    // Reset and main FSM (synchronous with asynchronous active-low reset)
    always @(posedge clk_25mhz or negedge rst_n) begin
        if (!rst_n) begin
            state_reg         <= ST_IDLE;
            return_state_reg  <= ST_IDLE;
            delay_cnt         <= 32'd0;
            mem_index_reg     <= 8'd0;
            init_done_reg     <= 1'b0;
            out_addr_reg      <= 8'd0;
            out_data_reg      <= 8'd0;
            sccb_start_reg    <= 1'b0;
        end
        else begin
            case (state_reg)

                ST_IDLE: begin
                    // Wait for start_init; clear index and done when starting
                    state_reg <= (start_init ? ST_SEND : ST_IDLE);
                    mem_index_reg <= 8'd0;
                    init_done_reg <= (start_init ? 1'b0 : init_done_reg);
                end

                ST_SEND: begin
                    case (mem_reg_pair)
                        16'hFFFF: begin
                            // End marker: finish initialization
                            state_reg <= ST_DONE;
                            sccb_start_reg <= 1'b0;
                        end

                        16'hFFF0: begin
                            // Delay marker: wait for 10 ms (approx) using CLK_FREQ_HZ/100
                            delay_cnt <= (CLK_FREQ_HZ / 100);
                            state_reg <= ST_WAIT;
                            return_state_reg <= ST_SEND;
                            mem_index_reg <= mem_index_reg + 8'd1;
                        end

                        default: begin
                            // Normal register write: start SCCB when interface ready
                            if (sccb_ready) begin
                                // one-cycle wait after asserting start
                                state_reg <= ST_WAIT;
                                return_state_reg <= ST_SEND;
                                delay_cnt <= 32'd0; // single-cycle pause
                                mem_index_reg <= mem_index_reg + 8'd1;
                                out_addr_reg <= mem_reg_pair[15:8];
                                out_data_reg <= mem_reg_pair[7:0];
                                sccb_start_reg <= 1'b1;
                            end
                            else begin
                                // SCCB not ready: ensure start pulse is low
                                sccb_start_reg <= 1'b0;
                            end
                        end
                    endcase
                end

                ST_DONE: begin
                    // Signal completion and return to idle
                    state_reg <= ST_IDLE;
                    init_done_reg <= 1'b1;
                    sccb_start_reg <= 1'b0;
                end

                ST_WAIT: begin
                    // Generic countdown timer used for both short and long delays
                    if (delay_cnt == 32'd0) begin
                        state_reg <= return_state_reg;
                        delay_cnt <= 32'd0;
                    end
                    else begin
                        state_reg <= ST_WAIT;
                        delay_cnt <= delay_cnt - 32'd1;
                    end
                    sccb_start_reg <= 1'b0; // ensure start pulse is deasserted during wait
                end

                default: begin
                    state_reg <= ST_IDLE;
                end
            endcase
        end
    end

endmodule