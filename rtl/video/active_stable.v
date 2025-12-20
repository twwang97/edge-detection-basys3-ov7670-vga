// active_stable.v
// Waits until active_in is continuously high for STABLE_CYCLES cycles,
// then asserts active_valid. If active_in goes low, the detector resets.

module active_stable #(
    parameter integer CLK_FREQ_HZ       = 25_000_000, // input clock frequency
    parameter real    STABLE_SECONDS    = 0.1          // required stable time in seconds
)(
    input  wire clk,
    input  wire active_in,
    output reg  active_valid
);

    // compute required stable cycles (integer)
    localparam integer STABLE_CYCLES = (CLK_FREQ_HZ * STABLE_SECONDS);

    // function to compute ceil(log2(n))
    function integer clog2;
        input integer value;
        integer i;
    begin
        clog2 = 0;
        for (i = value - 1; i > 0; i = i >> 1)
            clog2 = clog2 + 1;
    end
    endfunction

    localparam integer CNT_WIDTH = (STABLE_CYCLES <= 1) ? 1 : clog2(STABLE_CYCLES);

    reg [CNT_WIDTH-1:0] stable_cnt = {CNT_WIDTH{1'b0}};

    always @(posedge clk) begin
        if (active_in) begin
            if (!active_valid) begin
                if (stable_cnt == STABLE_CYCLES - 1) begin
                    active_valid <= 1'b1;
                end else begin
                    stable_cnt <= stable_cnt + 1'b1;
                end
            end
            // if already active_valid, keep it asserted while active_in stays high
        end else begin
            // reset when input goes low
            active_valid <= 1'b0;
            stable_cnt   <= {CNT_WIDTH{1'b0}};
        end
    end

endmodule