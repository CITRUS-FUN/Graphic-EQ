`define rom_size 6'd9

module CLOCK_500 (
                  CLOCK,
						CLOCK_1,
                  CLOCK_500,
                  DATA,
                  END,
                  RESET,
                  GO,
                  CLOCK_2
                 );

//=======================================================
// PORT declarations
//=======================================================
input           CLOCK;
input           CLOCK_1;
input           END;
input           RESET;

output          CLOCK_500;
output  [23:0]  DATA;
output          GO;
output          CLOCK_2;

reg     [10:0]  COUNTER_500;
reg     [15:0]  ROM[`rom_size:0];
reg     [15:0]  DATA_A;
reg     [5:0]   address;

wire CLOCK_500 = COUNTER_500[9];
wire CLOCK_2   = COUNTER_500[1];
wire [23:0] DATA = {8'h34, DATA_A};
wire GO = ((address <= `rom_size) && (END == 1)) ? COUNTER_500[10] : 1'b1;

//=============================================================================
// Structural coding
//=============================================================================

always @(negedge RESET or posedge END)
begin
    if (!RESET)
    begin
        address = 0;
    end
    else if (address <= `rom_size)
    begin
        address = address + 1;
    end
end

always @(posedge END)
begin

    // R6 Power Down Control
    ROM[0] = 16'h0C00;

    // R7 Digital Audio Interface Format
    // I2S, 24-bit, Master
    ROM[1] = 16'h0E4A;

    // R4 Analogue Audio Path Control
    // Line In -> ADC, DAC -> Outputs, BYPASS OFF
    ROM[2] = 16'h0810;

    // R5 Digital Audio Path Control
    ROM[3] = 16'h0A01;

    // R8 Sampling Control
    // 48 kHz
    ROM[4] = 16'h1000;

    // R0 Left Line In
    ROM[5] = 16'h0017;

    // R1 Right Line In
    ROM[6] = 16'h0217;

    // R2 Left Headphone Out
    ROM[7] = 16'h0479;

    // R3 Right Headphone Out
    ROM[8] = 16'h0679;

    // R9 Active Control
    ROM[`rom_size] = 16'h1201;

    DATA_A = ROM[address];
end

always @(posedge CLOCK)
begin
    COUNTER_500 = COUNTER_500 + 1;
end

endmodule