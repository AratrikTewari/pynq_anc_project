`timescale 1ns / 1ps

module top_pynq_anc #(
    parameter DATA_WIDTH  = 16,
    parameter FILTER_TAPS = 16
)(
    // Clock and Reset Interfaces
    input  wire        sysclk,       // 125 MHz system clock from H16 pin
    input  wire        btn_rst_n,    // Pushbutton reset (Active-Low)
    input  wire        sw_bypass,    // Switch 0: 1 = Bypass filter (pass primary), 0 = ANC active

    // Physical Audio Codec / I2S Pins
    output wire        codec_mclk,   // Master clock out to codec (12.5 MHz)
    output wire        codec_bclk,   // Bit clock out (~3.125 MHz)
    output wire        codec_lrclk,  // Frame / Word clock out (~48.8 kHz)
    input  wire        codec_sdata_i,// Serial audio in (ADC)
    output wire        codec_sdata_o,// Serial audio out (DAC)

    // Visual Status Diagnostics (PYNQ-Z2 Onboard LEDs)
    output wire [3:0]  leds          // Displays active mu_shift convergence level
);

    // Synchronizer for active-low reset
    reg [1:0] rst_sync;
    wire      sys_rst_n;

    always @(posedge sysclk or negedge btn_rst_n) begin
        if (!btn_rst_n)
            rst_sync <= 2'b00;
        else
            rst_sync <= {rst_sync[0], 1'b1};
    end
    assign sys_rst_n = rst_sync[1];

    // Master Clock Generator: 125 MHz / 10 = 12.5 MHz
    reg [2:0] mclk_div;
    reg       mclk_reg;
    always @(posedge sysclk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            mclk_div <= 3'd0;
            mclk_reg <= 1'b0;
        end else if (mclk_div == 3'd4) begin
            mclk_div <= 3'd0;
            mclk_reg <= ~mclk_reg;
        end else begin
            mclk_div <= mclk_div + 1'b1;
        end
    end
    assign codec_mclk = mclk_reg;

    // Internal Datapath Interconnects
    wire signed [DATA_WIDTH-1:0] primary_audio;   // Left Channel: d[n]
    wire signed [DATA_WIDTH-1:0] reference_noise; // Right Channel: x[n]
    wire signed [DATA_WIDTH-1:0] cleaned_audio;   // ANC Output: e[n]
    wire signed [DATA_WIDTH-1:0] dac_stream;
    wire                         sample_pulse;
    wire                         anc_valid;
    wire [3:0]                   mu_shift_val;

    // Codec Controller Instance
    audio_codec_ctrl #(
        .DATA_WIDTH(DATA_WIDTH),
        .BCLK_DIV(20)
    ) u_audio_codec (
        .clk(sysclk),
        .rst_n(sys_rst_n),
        .bclk(codec_bclk),
        .lrclk(codec_lrclk),
        .sdata_in(codec_sdata_i),
        .sdata_out(codec_sdata_o),
        .left_data_in(primary_audio),
        .right_data_in(reference_noise),
        .data_out(dac_stream),
        .sample_valid(sample_pulse)
    );

    // Adaptive Noise Cancellation Core Instance
    anc_core #(
        .DATA_WIDTH(DATA_WIDTH),
        .FILTER_TAPS(FILTER_TAPS)
    ) u_anc_core (
        .clk(sysclk),
        .rst_n(sys_rst_n),
        .sample_valid(sample_pulse),
        .primary_in(primary_audio),
        .ref_noise_in(reference_noise),
        .cleaned_out(cleaned_audio),
        .active_mu_shift(mu_shift_val),
        .data_ready(anc_valid)
    );

    // Bypass Multiplexer: Test listening to raw contaminated input vs. cleaned signal
    assign dac_stream = sw_bypass ? primary_audio : cleaned_audio;

    // LED Convergence Visualizer
    // As residual error drops, mu_shift increases (4 -> 6 -> 8 -> 10), lighting more LEDs
    assign leds[0] = (mu_shift_val >= 4'd4);
    assign leds[1] = (mu_shift_val >= 4'd6);
    assign leds[2] = (mu_shift_val >= 4'd8);
    assign leds[3] = (mu_shift_val >= 4'd10);

endmodule