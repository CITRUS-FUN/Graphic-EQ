module DE1_SoC_i2sound (
    // Audio codec
    input              AUD_ADCDAT,
    input              AUD_ADCLRCK,
    input              AUD_BCLK,
    output             AUD_DACDAT,
    input              AUD_DACLRCK,
    output             AUD_XCK,
 
    input              CLOCK_50,
 
    // Codec configuration bus
    output             FPGA_I2C_SCLK,
    inout              FPGA_I2C_SDAT,
 
    input       [3:0]  KEY,
    output reg  [9:0]  LEDR,
    input       [9:0]  SW
);
 
// -----------------------------------------------------------------------
// Codec configuration: MCLK from PLL, I2C register writes
// -----------------------------------------------------------------------
wire        CLK_1M;
wire        I2C_END;
wire        KEYON;
wire [23:0] AUD_I2C_DATA;
wire        GO;
 
AudioPLL u0 (
    .ref_clk_clk        (CLOCK_50),
    .ref_reset_reset    (~KEY[2]),
    .audio_clk_clk      (AUD_XCK),
    .reset_source_reset ()
);
 
CLOCK_500 u1 (
    .CLOCK     (CLOCK_50),
    .CLOCK_1   (AUD_XCK),
    .END       (I2C_END),
    .RESET     (KEYON),
    .CLOCK_500 (CLK_1M),
    .GO        (GO),
    .CLOCK_2   (),
    .DATA      (AUD_I2C_DATA)
);
 
i2c u2 (
    .CLOCK    (CLK_1M),
    .RESET    (1'b1),
    .I2C_SDAT (FPGA_I2C_SDAT),
    .I2C_DATA (AUD_I2C_DATA),
    .I2C_SCLK (FPGA_I2C_SCLK),
    .GO       (GO),
    .END      (I2C_END)
);
 
keytr u3 (
    .clock (CLK_1M),
    .key   (KEY[0]),
    .key1  (KEY[1]),
    .KEYON (KEYON)
);
 
// -----------------------------------------------------------------------
// I2S receiver: AUD_ADCDAT -> parallel 24-bit samples.
// rx_valid pulses once per stereo sample (CLOCK_50 domain) and is the
// sample tick for all filters.
// -----------------------------------------------------------------------
wire [23:0] rx_left, rx_right;
wire        rx_valid;
 
wire rst_n        = KEY[3];   // 1 = run, 0 = reset (KEY[3] pressed)
wire filter_reset = ~rst_n;   // active-high reset for IIR_Filter
 
i2s_receiver u_rx (
    .clk          (CLOCK_50),
    .rst_n        (rst_n),
    .BCLK         (AUD_BCLK),
    .LRCK         (AUD_ADCLRCK),
    .ADCDAT       (AUD_ADCDAT),
    .sample_left  (rx_left),
    .sample_right (rx_right),
    .sample_valid (rx_valid)
);
 
// -----------------------------------------------------------------------
// Cascade of IIR filters, LEFT and RIGHT channels in parallel.
// enable = 0 -> filter clears its state and passes the sample unchanged.
// -----------------------------------------------------------------------
wire [23:0] w_R_31_5,  w_L_31_5;
wire [23:0] w_R_63,    w_L_63;
wire [23:0] w_R_125,   w_L_125;
wire [23:0] w_R_250,   w_L_250;
wire [23:0] w_R_500,   w_L_500;
wire [23:0] w_R_1000,  w_L_1000;
wire [23:0] w_R_2000,  w_L_2000;
wire [23:0] w_R_4000,  w_L_4000;
wire [23:0] w_R_8000,  w_L_8000;
wire [23:0] w_R_out,   w_L_out;
 
// -- 31.5 Hz --------------------------------------------------------------
IIR_Filter Filter_R_31_5_Hz (
    .clk          (CLOCK_50),
    .reset        (filter_reset),
    .enable       (SW[9]),
    .sample_tick  (rx_valid),
    .input_sample (rx_right),
 
    .b0( 32'sd1074414558),
    .b1(-32'sd2146843152),
    .b2( 32'sd1072446844),
 
    .a1(-32'sd2146843152),
    .a2( 32'sd1073119578),
 
    .output_sample(w_R_31_5)
);
 
IIR_Filter Filter_L_31_5_Hz (
    .clk          (CLOCK_50),
    .reset        (filter_reset),
    .enable       (SW[9]),
    .sample_tick  (rx_valid),
    .input_sample (rx_left),
 
    .b0( 32'sd1074414558),
    .b1(-32'sd2146843152),
    .b2( 32'sd1072446844),
 
    .a1(-32'sd2146843152),
    .a2( 32'sd1073119578),
 
    .output_sample(w_L_31_5)
);
 
// -- 63 Hz ----------------------------------------------------------------
IIR_Filter Filter_R_63_Hz (
    .clk          (CLOCK_50),
    .reset        (filter_reset),
    .enable       (SW[8]),
    .sample_tick  (rx_valid),
    .input_sample (w_R_31_5),
 
    .b0( 32'sd1075086891),
    .b1(-32'sd2146166547),
    .b2( 32'sd1071152636),
 
    .a1(-32'sd2146166547),
    .a2( 32'sd1072497703),
 
    .output_sample(w_R_63)
);
 
IIR_Filter Filter_L_63_Hz (
    .clk          (CLOCK_50),
    .reset        (filter_reset),
    .enable       (SW[8]),
    .sample_tick  (rx_valid),
    .input_sample (w_L_31_5),
 
    .b0( 32'sd1075086891),
    .b1(-32'sd2146166547),
    .b2( 32'sd1071152636),
 
    .a1(-32'sd2146166547),
    .a2( 32'sd1072497703),
 
    .output_sample(w_L_63)
);
 
// -- 125 Hz ---------------------------------------------------------------
IIR_Filter Filter_R_125_Hz (
    .clk          (CLOCK_50),
    .reset        (filter_reset),
    .enable       (SW[7]),
    .sample_tick  (rx_valid),
    .input_sample (w_R_63),
 
    .b0( 32'sd1076408998),
    .b1(-32'sd2144729507),
    .b2( 32'sd1068607645),
 
    .a1(-32'sd2144729507),
    .a2( 32'sd1071274819),
 
    .output_sample(w_R_125)
);
 
IIR_Filter Filter_L_125_Hz (
    .clk          (CLOCK_50),
    .reset        (filter_reset),
    .enable       (SW[7]),
    .sample_tick  (rx_valid),
    .input_sample (w_L_63),
 
    .b0( 32'sd1076408998),
    .b1(-32'sd2144729507),
    .b2( 32'sd1068607645),
 
    .a1(-32'sd2144729507),
    .a2( 32'sd1071274819),
 
    .output_sample(w_L_125)
);
 
// -- 250 Hz ---------------------------------------------------------------
IIR_Filter Filter_R_250_Hz (
    .clk          (CLOCK_50),
    .reset        (filter_reset),
    .enable       (SW[6]),
    .sample_tick  (rx_valid),
    .input_sample (w_R_125),
 
    .b0( 32'sd1079069340),
    .b1(-32'sd2141408808),
    .b2( 32'sd1063486619),
 
    .a1(-32'sd2141408808),
    .a2( 32'sd1068814135),
 
    .output_sample(w_R_250)
);
 
IIR_Filter Filter_L_250_Hz (
    .clk          (CLOCK_50),
    .reset        (filter_reset),
    .enable       (SW[6]),
    .sample_tick  (rx_valid),
    .input_sample (w_L_125),
 
    .b0( 32'sd1079069340),
    .b1(-32'sd2141408808),
    .b2( 32'sd1063486619),
 
    .a1(-32'sd2141408808),
    .a2( 32'sd1068814135),
 
    .output_sample(w_L_250)
);
 
// -- 500 Hz ---------------------------------------------------------------
IIR_Filter Filter_R_500_Hz (
    .clk          (CLOCK_50),
    .reset        (filter_reset),
    .enable       (SW[5]),
    .sample_tick  (rx_valid),
    .input_sample (w_R_250),
 
    .b0( 32'sd1084366797),
    .b1(-32'sd2133079187),
    .b2( 32'sd1053289276),
 
    .a1(-32'sd2133079187),
    .a2( 32'sd1063914249),
 
    .output_sample(w_R_500)
);
 
IIR_Filter Filter_L_500_Hz (
    .clk          (CLOCK_50),
    .reset        (filter_reset),
    .enable       (SW[5]),
    .sample_tick  (rx_valid),
    .input_sample (w_L_250),
 
    .b0( 32'sd1084366797),
    .b1(-32'sd2133079187),
    .b2( 32'sd1053289276),
 
    .a1(-32'sd2133079187),
    .a2( 32'sd1063914249),
 
    .output_sample(w_L_500)
);
 
// -- 1000 Hz --------------------------------------------------------------
IIR_Filter Filter_R_1000_Hz (
    .clk          (CLOCK_50),
    .reset        (filter_reset),
    .enable       (SW[4]),
    .sample_tick  (rx_valid),
    .input_sample (w_R_500),
 
    .b0( 32'sd1094850088),
    .b1(-32'sd2109754558),
    .b2( 32'sd1033109459),
 
    .a1(-32'sd2109754558),
    .a2( 32'sd1054217723),
 
    .output_sample(w_R_1000)
);
 
IIR_Filter Filter_L_1000_Hz (
    .clk          (CLOCK_50),
    .reset        (filter_reset),
    .enable       (SW[4]),
    .sample_tick  (rx_valid),
    .input_sample (w_L_500),
 
    .b0( 32'sd1094850088),
    .b1(-32'sd2109754558),
    .b2( 32'sd1033109459),
 
    .a1(-32'sd2109754558),
    .a2( 32'sd1054217723),
 
    .output_sample(w_L_1000)
);
 
// -- 2000 Hz --------------------------------------------------------------
IIR_Filter Filter_R_2000_Hz (
    .clk          (CLOCK_50),
    .reset        (filter_reset),
    .enable       (SW[3]),
    .sample_tick  (rx_valid),
    .input_sample (w_R_1000),
 
    .b0( 32'sd1115226474),
    .b1(-32'sd2037246134),
    .b2( 32'sd993885922),
 
    .a1(-32'sd2037246134),
    .a2( 32'sd1035370572),
 
    .output_sample(w_R_2000)
);
 
IIR_Filter Filter_L_2000_Hz (
    .clk          (CLOCK_50),
    .reset        (filter_reset),
    .enable       (SW[3]),
    .sample_tick  (rx_valid),
    .input_sample (w_L_1000),
 
    .b0( 32'sd1115226474),
    .b1(-32'sd2037246134),
    .b2( 32'sd993885922),
 
    .a1(-32'sd2037246134),
    .a2( 32'sd1035370572),
 
    .output_sample(w_L_2000)
);
 
// -- 4000 Hz --------------------------------------------------------------
IIR_Filter Filter_R_4000_Hz (
    .clk          (CLOCK_50),
    .reset        (filter_reset),
    .enable       (SW[2]),
    .sample_tick  (rx_valid),
    .input_sample (w_R_2000),
 
    .b0( 32'sd1152571474),
    .b1(-32'sd1796630423),
    .b2( 32'sd921998642),
 
    .a1(-32'sd1796630423),
    .a2( 32'sd1000828292),
 
    .output_sample(w_R_4000)
);
 
IIR_Filter Filter_L_4000_Hz (
    .clk          (CLOCK_50),
    .reset        (filter_reset),
    .enable       (SW[2]),
    .sample_tick  (rx_valid),
    .input_sample (w_L_2000),
 
    .b0( 32'sd1152571474),
    .b1(-32'sd1796630423),
    .b2( 32'sd921998642),
 
    .a1(-32'sd1796630423),
    .a2( 32'sd1000828292),
 
    .output_sample(w_L_4000)
);
 
// -- 8000 Hz --------------------------------------------------------------
IIR_Filter Filter_R_8000_Hz (
    .clk          (CLOCK_50),
    .reset        (filter_reset),
    .enable       (SW[1]),
    .sample_tick  (rx_valid),
    .input_sample (w_R_4000),
 
    .b0( 32'sd1206967418),
    .b1(-32'sd1012128278),
    .b2( 32'sd817289138),
 
    .a1(-32'sd1012128278),
    .a2( 32'sd950514732),
 
    .output_sample(w_R_8000)
);
 
IIR_Filter Filter_L_8000_Hz (
    .clk          (CLOCK_50),
    .reset        (filter_reset),
    .enable       (SW[1]),
    .sample_tick  (rx_valid),
    .input_sample (w_L_4000),
 
    .b0( 32'sd1206967418),
    .b1(-32'sd1012128278),
    .b2( 32'sd817289138),
 
    .a1(-32'sd1012128278),
    .a2( 32'sd950514732),
 
    .output_sample(w_L_8000)
);
 
// -- 16000 Hz -------------------------------------------------------------
IIR_Filter Filter_R_16000_Hz (
    .clk          (CLOCK_50),
    .reset        (filter_reset),
    .enable       (SW[0]),
    .sample_tick  (rx_valid),
    .input_sample (w_R_8000),
 
    .b0( 32'sd1206967418),
    .b1( 32'sd1012128278),
    .b2( 32'sd817289138),
 
    .a1( 32'sd1012128278),
    .a2( 32'sd950514732),
 
    .output_sample(w_R_out)
);
 
IIR_Filter Filter_L_16000_Hz (
    .clk          (CLOCK_50),
    .reset        (filter_reset),
    .enable       (SW[0]),
    .sample_tick  (rx_valid),
    .input_sample (w_L_8000),
 
    .b0( 32'sd1206967418),
    .b1( 32'sd1012128278),
    .b2( 32'sd817289138),
 
    .a1( 32'sd1012128278),
    .a2( 32'sd950514732),
 
    .output_sample(w_L_out)
);
 
// -----------------------------------------------------------------------
// Sample registers for the transmitter, updated once per sample.
// KEY[1] pressed -> mute.
// -----------------------------------------------------------------------
reg [23:0] dac_left, dac_right;
 
always @(posedge CLOCK_50 or negedge rst_n) begin
    if (!rst_n) begin
        dac_left  <= 24'd0;
        dac_right <= 24'd0;
        LEDR      <= 10'd0;
    end else begin
        LEDR <= SW;   // show enabled bands
 
        if (rx_valid) begin
            if (!KEY[1]) begin
                dac_left  <= 24'd0;
                dac_right <= 24'd0;
            end else begin
                dac_left  <= w_L_out;
                dac_right <= w_R_out;
            end
        end
    end
end
 
// -----------------------------------------------------------------------
// I2S transmitter: parallel 24-bit samples -> AUD_DACDAT
// -----------------------------------------------------------------------
i2s_transmitter u_tx (
    .clk          (CLOCK_50),
    .rst_n        (rst_n),
    .BCLK         (AUD_BCLK),
    .LRCK         (AUD_DACLRCK),
    .DACDAT       (AUD_DACDAT),
    .sample_left  (dac_left),
    .sample_right (dac_right)
);
 
endmodule