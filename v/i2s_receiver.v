module i2s_receiver (
    input  wire        clk,          // system clock (50 MHz)
    input  wire        rst_n,        // active-low reset
 
    input  wire        BCLK,         // bit clock from codec
    input  wire        LRCK,         // left/right clock from codec (AUD_ADCLRCK)
    input  wire        ADCDAT,       // serial ADC data
 
    output reg  [23:0] sample_left,
    output reg  [23:0] sample_right,
    output reg         sample_valid  // 1 clk pulse when a new stereo pair is ready
);
 
// Synchronize the external I2S signals to clk
reg bclk_r0, bclk_r1, bclk_r2;
reg lrck_r0, lrck_r1, lrck_r2;
reg dat_r0,  dat_r1;
 
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        bclk_r0 <= 1'b0; bclk_r1 <= 1'b0; bclk_r2 <= 1'b0;
        lrck_r0 <= 1'b0; lrck_r1 <= 1'b0; lrck_r2 <= 1'b0;
        dat_r0  <= 1'b0; dat_r1  <= 1'b0;
    end else begin
        bclk_r0 <= BCLK;   bclk_r1 <= bclk_r0;  bclk_r2 <= bclk_r1;
        lrck_r0 <= LRCK;   lrck_r1 <= lrck_r0;  lrck_r2 <= lrck_r1;
        dat_r0  <= ADCDAT; dat_r1  <= dat_r0;
    end
end
 
wire bclk_rising  = ( bclk_r1 & ~bclk_r2);
wire lrck_falling = (~lrck_r1 &  lrck_r2);   // start of LEFT channel
wire lrck_rising  = ( lrck_r1 & ~lrck_r2);   // start of RIGHT channel
 
// bit_cnt = 0 is the delay slot after the LRCK edge (discarded),
// bit_cnt = 1..24 are the data bits, MSB first.
reg [4:0]  bit_cnt;
reg [23:0] shift_reg;
reg        channel;      // 0 = LEFT, 1 = RIGHT
 
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        bit_cnt      <= 5'd0;
        shift_reg    <= 24'd0;
        channel      <= 1'b0;
        sample_left  <= 24'd0;
        sample_right <= 24'd0;
        sample_valid <= 1'b0;
    end else begin
        sample_valid <= 1'b0;
 
        if (lrck_falling) begin
            channel <= 1'b0;
            bit_cnt <= 5'd0;
        end
        else if (lrck_rising) begin
            channel     <= 1'b1;
            bit_cnt     <= 5'd0;
            sample_left <= shift_reg;      // LEFT word is complete
        end
        else if (bclk_rising) begin
            bit_cnt <= bit_cnt + 1'b1;
 
            if (bit_cnt >= 5'd1 && bit_cnt <= 5'd24)
                shift_reg <= {shift_reg[22:0], dat_r1};
 
            if (channel == 1'b1 && bit_cnt == 5'd24) begin
                sample_right <= {shift_reg[22:0], dat_r1};
                sample_valid <= 1'b1;
            end
        end
    end
end
 
endmodule