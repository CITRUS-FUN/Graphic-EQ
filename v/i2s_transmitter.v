module i2s_transmitter (
    input  wire        clk,          // system clock (50 MHz)
    input  wire        rst_n,        // active-low reset
 
    input  wire        BCLK,         // bit clock from codec
    input  wire        LRCK,         // left/right clock from codec (AUD_DACLRCK)
    output reg         DACDAT,       // serial DAC data
 
    input  wire [23:0] sample_left,
    input  wire [23:0] sample_right
);
 
// Synchronize BCLK and LRCK to clk
reg bclk_r0, bclk_r1, bclk_r2;
reg lrck_r0, lrck_r1, lrck_r2;
 
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        bclk_r0 <= 1'b1; bclk_r1 <= 1'b1; bclk_r2 <= 1'b1;
        lrck_r0 <= 1'b0; lrck_r1 <= 1'b0; lrck_r2 <= 1'b0;
    end else begin
        bclk_r0 <= BCLK;  bclk_r1 <= bclk_r0;  bclk_r2 <= bclk_r1;
        lrck_r0 <= LRCK;  lrck_r1 <= lrck_r0;  lrck_r2 <= lrck_r1;
    end
end
 
wire bclk_falling = (~bclk_r1 &  bclk_r2);
wire lrck_falling = (~lrck_r1 &  lrck_r2);   // start of LEFT channel
wire lrck_rising  = ( lrck_r1 & ~lrck_r2);   // start of RIGHT channel
 
reg [4:0]  bit_cnt;
reg [31:0] tx_shift;    // 24 data bits + 8 zero bits
reg [23:0] tx_right;    // RIGHT sample latched at the start of the frame
 
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        bit_cnt  <= 5'd0;
        tx_shift <= 32'd0;
        tx_right <= 24'd0;
        DACDAT   <= 1'b0;
    end else begin
        if (lrck_falling) begin
            bit_cnt  <= 5'd0;
            tx_right <= sample_right;
            tx_shift <= {sample_left, 8'b0};
        end
        else if (lrck_rising) begin
            bit_cnt  <= 5'd0;
            tx_shift <= {tx_right, 8'b0};
        end
        else if (bclk_falling) begin
            bit_cnt <= bit_cnt + 1'b1;
 
            if (bit_cnt <= 5'd23) begin
                DACDAT   <= tx_shift[31];
                tx_shift <= {tx_shift[30:0], 1'b0};
            end else begin
                DACDAT <= 1'b0;
            end
        end
    end
end
 
endmodule