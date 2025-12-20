// debounce_4switches.v
// Parameterized debounce for 4 switches: update output only after stable interval.
//
// Inputs:
//  - clk: system clock
//  - rst_n: synchronous active-low reset
//  - sw[3:0]: raw switch inputs (asynchronous)
// Output:
//  - state_out[3:0]: debounced switch state (initially 4'b0000)

module debounce_4switches #(
    parameter integer CLK_FREQ_HZ   = 50_000_000, // default 50 MHz
    parameter integer DEBOUNCE_SEC  = 1            // debounce time in seconds
)(
    input  wire        clk,
    input  wire        rst_n,       // synchronous active-low reset
    input  wire [3:0]  sw,        // raw asynchronous switches
    output reg  [3:0]  state_out  // debounced output
);

    // Counter maximum cycles required for stable period
    localparam integer CYCLES_REQUIRED = CLK_FREQ_HZ * DEBOUNCE_SEC;

    // Use a 32-bit counter (enough for typical clock rates and 1s)
    reg [31:0] stable_cnt;

    // Synchronizers for each switch to avoid metastability
    reg [3:0] sync_0;
    reg [3:0] sync_1;

    // Track last sampled (synchronized) input
    reg [3:0] last_sampled;

    // Two-stage synchronizer
    always @(posedge clk) begin
        if (!rst_n) begin
            sync_0 <= 4'b0000;
            sync_1 <= 4'b0000;
        end else begin
            sync_0 <= sw;
            sync_1 <= sync_0;
        end
    end

    // Main debounce logic
    always @(posedge clk) begin
        if (!rst_n) begin
            state_out    <= 4'b0000; // initial state as requested
            last_sampled <= 4'b0000;
            stable_cnt   <= 32'd0;
        end else begin
            // If synchronized input changed from last sampled, reset counter and update last_sampled
            if (sync_1 != last_sampled) begin
                last_sampled <= sync_1;
                stable_cnt   <= 32'd0;
            end else begin
                // input unchanged; increment counter until it reaches required cycles
                if (stable_cnt < (CYCLES_REQUIRED - 1)) begin
                    stable_cnt <= stable_cnt + 1;
                end
            end

            // When counter reaches required cycles, commit the stable input to output
            if (stable_cnt >= (CYCLES_REQUIRED - 1)) begin
                state_out <= last_sampled;
            end
        end
    end

endmodule