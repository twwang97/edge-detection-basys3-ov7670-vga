/*
 ==============================================================================
 Module : ov7670_sccb_master
 Forked from : https://github.com/donctchen/ov7670_vga_display/blob/main/sccb_communication.v
 Original repo commit : 242f79b6720ad82ab0f420f644ce1259e4506506
 Original author :  Don CT Chen
 Forked and modified by : Wang <twwang97@gmail.com>
 Date forked/modified : 2025-12-10
 ------------------------------------------------------------------------------
 Objective
 ------------------------------------------------------------------------------
 Implements an SCCB (Serial Camera Control Bus) master to write configuration
 registers to an OV7670 camera module. The module generates SCCB clock and
 drives the bidirectional data line to transmit a 3-byte write sequence:
   1) Slave address (write)
   2) Register address
   3) Register data
 The design uses a simple FSM and a programmable timer derived from the input
 clock to produce the requested SCCB bit rate.

 ------------------------------------------------------------------------------
 Key Features
 ------------------------------------------------------------------------------
 - Parameterizable input clock and SCCB frequency
 - Parameterizable camera slave address
 - Single-start write operation: accepts mem_addr and mem_data and performs
   the full write transaction
 - Ready handshake output to indicate idle/complete state
 - Tri-state sccb_data line to allow release for ACK or bus sharing
 - Deterministic timing using integer clock-cycle timer

 ------------------------------------------------------------------------------
 Parameters
 ------------------------------------------------------------------------------
 - INPUT_CLK_FREQ : Frequency of the input clock driving this module (Hz)
 - SCCB_FREQ      : Desired SCCB clock frequency (Hz)
 - SLAVE_ADDR     : 8-bit SCCB slave address for the OV7670 (default 8'h42)

 ------------------------------------------------------------------------------
 Ports
 ------------------------------------------------------------------------------
 - clk      : System clock input
 - rst_n    : Active-low synchronous reset
 - start    : Pulse to start a single register write transaction
 - mem_addr : 8-bit register address to write to the camera
 - mem_data : 8-bit data to write into the register
 - ready    : Output asserted when module is idle and ready for a new start
 - sccb_clk : SCCB clock output driven by the master
 - sccb_data: Bidirectional SCCB data line (driven low/high or released 'z')

 ------------------------------------------------------------------------------
 Operation Notes
 ------------------------------------------------------------------------------
 - On assertion of start while ready is high, the FSM captures mem_addr and
   mem_data and begins the SCCB start condition and byte sequence.
 - Timing for clock low/high and data setup is derived from:
     timer = INPUT_CLK_FREQ / (4 * SCCB_FREQ)  (or / (2 * SCCB_FREQ) for
     the clock high pulse where required)
 - sccb_data is driven to 'z' when the module releases the bus (e.g., to
   allow ACK from slave); external pull-ups are expected on the SCCB lines.
 - The module currently implements write-only transactions; read or repeated
   start sequences are not provided.
 ==============================================================================
*/

module ov7670_sccb_master 
#(
    parameter INPUT_CLK_FREQ = 25000000,
    parameter SCCB_FREQ = 100000 ,
    parameter SLAVE_ADDR  = 8'h42 // to talk with OV7670 camera
)
(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] mem_addr,
    input wire [7:0] mem_data,
    output wire ready,
    output wire sccb_clk,
    inout wire sccb_data
);

reg ready_reg = 1'b1;
reg sccb_clk_reg = 1'b1;
reg sccb_data_reg = 1'b1;
assign ready = ready_reg;
assign sccb_clk = sccb_clk_reg;
assign sccb_data = sccb_data_reg;

// FSM States
localparam [3:0]
    ST_IDLE               = 4'd0,
    ST_START_COND         = 4'd1,
    ST_LOAD_TX            = 4'd2,
    ST_CLK_LOW            = 4'd3,
    ST_DATA_BIT_SETUP     = 4'd4,
    ST_CLK_HIGH_PULSE     = 4'd5,
    ST_SHIFT_NEXT         = 4'd6,
    ST_END_PREP_CLK_LOW   = 4'd7,
    ST_END_SET_DATA_LOW   = 4'd8,
    ST_END_CLK_HIGH       = 4'd9,
    ST_END_RELEASE_DATA   = 4'd10,
    ST_COMPLETE_HOLD      = 4'd11,
    ST_WAIT_TIMER         = 4'd12;
    
reg [3:0] sccb_state = 0;
reg [3:0] return_state = 0;
reg [31:0] timer = 0;
reg [7:0] mem_addr_reg;
reg [7:0] mem_data_reg;
reg [1:0] byte_counter = 0;
reg [3:0] bit_index = 0;
reg [7:0] load_tx_byte = 0;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sccb_state <= ST_IDLE;
        ready_reg <= 1'b1;
        sccb_clk_reg <= 1'b1;
        sccb_data_reg <= 1'b1;
        timer <= 0;
        byte_counter <= 0;
        bit_index <= 0;
        load_tx_byte <= 0;
        mem_addr_reg <= 0;
        mem_data_reg <= 0;
        return_state <= 0;
    end
    else begin
        case (sccb_state)
            ST_IDLE: begin
                bit_index <= 4'b0000;
                byte_counter <= 2'b00;
                if (start) begin
                    sccb_state <= ST_START_COND;
                    mem_addr_reg <= mem_addr;
                    mem_data_reg <= mem_data;
                    ready_reg <= 1'b0;
                end
                else begin
                    ready_reg <= 1'b1; 
                end
            end

            ST_START_COND: begin
                sccb_state <= ST_WAIT_TIMER;
                return_state <= ST_LOAD_TX;
                timer <= (INPUT_CLK_FREQ / (4*SCCB_FREQ));
                sccb_clk_reg <= 1'b1;
                sccb_data_reg <= 1'b0;
            end

            ST_LOAD_TX: begin            
                sccb_state <= (byte_counter == 3) ? ST_END_PREP_CLK_LOW : ST_CLK_LOW;
                byte_counter <= byte_counter + 1;
                bit_index <= 0;
                case (byte_counter)
                    0: load_tx_byte <= SLAVE_ADDR;
                    1: load_tx_byte <= mem_addr_reg;
                    2: load_tx_byte <= mem_data_reg;
                    default: load_tx_byte <= mem_data_reg;
                endcase            
            end

            ST_CLK_LOW: begin
                sccb_state <= ST_WAIT_TIMER;
                return_state <= ST_DATA_BIT_SETUP;
                timer <= (INPUT_CLK_FREQ / (4*SCCB_FREQ));
                sccb_clk_reg <= 1'b0;
            end

            ST_DATA_BIT_SETUP: begin
                sccb_state <= ST_WAIT_TIMER;
                return_state <= ST_CLK_HIGH_PULSE;
                timer <= (INPUT_CLK_FREQ / (4*SCCB_FREQ));
                if (bit_index < 8) sccb_data_reg <= load_tx_byte[7];
                else sccb_data_reg <= 1'bz;
            end

            ST_CLK_HIGH_PULSE: begin
                sccb_state <= ST_WAIT_TIMER;
                return_state <= ST_SHIFT_NEXT;
                timer <= (INPUT_CLK_FREQ / (2*SCCB_FREQ));
                sccb_clk_reg <= 1'b1;
            end

            ST_SHIFT_NEXT: begin
                sccb_state <= (bit_index == 8) ? ST_LOAD_TX : ST_CLK_LOW;
                load_tx_byte <= load_tx_byte << 1;
                bit_index <= bit_index + 1;
            end

            ST_END_PREP_CLK_LOW: begin
                sccb_state <= ST_WAIT_TIMER;
                return_state <= ST_END_SET_DATA_LOW;
                timer <= (INPUT_CLK_FREQ / (4*SCCB_FREQ));
                sccb_clk_reg <= 1'b0;
            end

            ST_END_SET_DATA_LOW: begin
                sccb_state <= ST_WAIT_TIMER;
                return_state <= ST_END_CLK_HIGH;
                timer <= (INPUT_CLK_FREQ / (4*SCCB_FREQ));
                sccb_data_reg <= 1'b0;
            end

            ST_END_CLK_HIGH: begin
                sccb_state <= ST_WAIT_TIMER;
                return_state <= ST_END_RELEASE_DATA;
                timer <= (INPUT_CLK_FREQ / (4*SCCB_FREQ));
                sccb_clk_reg <= 1'b1;
            end

            ST_END_RELEASE_DATA: begin
                sccb_state <= ST_WAIT_TIMER;
                return_state <= ST_COMPLETE_HOLD;
                timer <= (INPUT_CLK_FREQ / (4*SCCB_FREQ));
                sccb_data_reg <= 1'b1;
            end

            ST_COMPLETE_HOLD: begin
                sccb_state <= ST_WAIT_TIMER;
                return_state <= ST_IDLE;
                timer <= (INPUT_CLK_FREQ / (2*SCCB_FREQ));
                byte_counter <= 0;
            end

            ST_WAIT_TIMER: begin
                sccb_state <= (timer == 0) ? return_state : ST_WAIT_TIMER;
                timer <= (timer == 0) ? 0 : timer - 1;
            end

            default: begin
                sccb_state <= ST_IDLE;
            end
        endcase
    end  
end
endmodule