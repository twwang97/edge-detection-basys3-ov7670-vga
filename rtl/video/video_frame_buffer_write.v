// Module   : video_frame_buffer_write
// Purpose  : Capture OV7670 pixel stream, pack to 12-bit RGB, drive memory writes
// Author   : twwang97
// Date     : 2025-12-10
// Inputs   : clk, rst_n, vsync, href, frame_din[7:0]
// Outputs  : mem_din[11:0], mem_addr[16:0], mem_we
// Notes    : Assumes 2 bytes per pixel; RGB444 extraction; 320x240 addressing
//            RGB565 = {RRRR, R, GGGG, GG, BBBB, B}

module video_frame_buffer_write (
    input wire clk,
    input wire rst_n,
    input wire vsync,
    input wire href,
    input  wire [7:0] frame_din,
    output wire [11:0] mem_din,
    output wire [16:0] mem_addr,
    output wire mem_we
);

    // Registers
    reg [16:0] mem_addr_reg;
    reg [17:0] mem_addr_next; // one bit wider for increment carry
    reg [11:0] mem_din_reg;
    reg [1:0] we_shift;
    reg mem_we_reg;
    reg [15:0] data_reg;

    assign mem_din = mem_din_reg;
    assign mem_addr = mem_addr_reg;
    assign mem_we = mem_we_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_addr_reg  <= 17'd0;
            mem_addr_next <= 18'd0;
            data_reg      <= 16'd0;
            mem_din_reg   <= 12'd0;
            we_shift      <= 2'b00;
            mem_we_reg    <= 1'b0;
        end else begin
            if (vsync == 1) begin
                mem_addr_reg   <= 17'd0;
                mem_addr_next  <= 18'd0;
                data_reg       <= 16'd0;
                mem_din_reg    <= 12'd0;
                we_shift       <= 2'b00;
                mem_we_reg     <= 1'b0;
            end else begin
                // Convert RGB565 (RRRR, R, GGGG, GG, BBBB, B) into RGB444
                mem_din_reg  <= {data_reg[15:12], data_reg[10:7], data_reg[4:1]};
                mem_addr_reg <= mem_addr_next[16:0];
                mem_we_reg   <= we_shift[1];
                we_shift     <= {we_shift[0], (href && !we_shift[0])};
                data_reg     <= {data_reg[7:0], frame_din};
                if (we_shift[1] == 1) begin
                    mem_addr_next <= mem_addr_next + 1;
                end
            end
        end
    end

endmodule