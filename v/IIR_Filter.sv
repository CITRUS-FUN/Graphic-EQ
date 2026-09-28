module IIR_Filter (
    input  wire               clk,
    input  wire               reset,         // active high, asynchronous
    input  wire               enable,        // 1 = filter, 0 = bypass
    input  wire               sample_tick,   // one pulse per new sample
    input  signed [23:0]      input_sample,
    input  signed [31:0]      b0,            // Q2.30
    input  signed [31:0]      b1,
    input  signed [31:0]      b2,
    input  signed [31:0]      a1,
    input  signed [31:0]      a2,
    output reg signed [23:0]  output_sample
);
    reg signed [31:0] x1, x2;
    reg signed [31:0] y1, y2;
    reg signed [63:0] acc;
    reg signed [31:0] y;
    wire signed [31:0] x = input_sample <<< 7;   // PCM24 -> Q2.30 scale
 
    // Saturate 64-bit -> 32-bit
    function signed [31:0] sat32;
        input signed [63:0] value;
        begin
            if (value > 64'sd2147483647)
                sat32 = 32'sh7fffffff;
            else if (value < -64'sd2147483648)
                sat32 = 32'sh80000000;
            else
                sat32 = value[31:0];
        end
    endfunction
 
    // Saturate Q2.30 -> PCM24
    function signed [23:0] sat24;
        input signed [31:0] value;
        begin
            if (value > (32'sd8388607 <<< 7))
                sat24 = 24'sh7FFFFF;
            else if (value < (-32'sd8388608 <<< 7))
                sat24 = -24'sd8388608;
            else
                sat24 = value >>> 7;
        end
    endfunction
 
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            x1 <= 0;
            x2 <= 0;
            y1 <= 0;
            y2 <= 0;
            output_sample <= 0;
        end
        else if (sample_tick) begin
            if (!enable) begin
                x1 <= 0;
                x2 <= 0;
                y1 <= 0;
                y2 <= 0;
                output_sample <= input_sample;
            end
            else begin
                acc = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
                y   = sat32(acc >>> 30);
                x2 <= x1;
                x1 <= x;
                y2 <= y1;
                y1 <= y;
                output_sample <= sat24(y);
            end
        end
    end
endmodule