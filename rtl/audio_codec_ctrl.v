`timescale 1ns / 1ps

module audio_codec_ctrl #(
    parameter DATA_WIDTH = 16,
    // 125 MHz clock divided down for standard ~48.8 kHz @ 64-bit frame:
    // BCLK = 125 MHz / (2 * 20) = 3.125 MHz
    // LRCLK = 3.125 MHz / 64 = ~48.828 kHz
    parameter BCLK_DIV = 20
)(
    input  wire                         clk,          // 125 MHz PYNQ-Z2 sysclk
    input  wire                         rst_n,
    
    // Physical I2S Codec Pins
    output reg                          bclk,         // Bit Clock (~3.125 MHz)
    output reg                          lrclk,        // Left/Right Word Select Clock
    input  wire                         sdata_in,     // Serial audio in (ADC)
    output reg                          sdata_out,    // Serial audio out (DAC)
    
    // Internal Parallel DSP Interface
    output reg  signed [DATA_WIDTH-1:0] left_data_in,  // Primary audio d[n]
    output reg  signed [DATA_WIDTH-1:0] right_data_in, // Reference noise x[n]
    input  wire signed [DATA_WIDTH-1:0] data_out,      // Filtered audio e[n]
    output reg                          sample_valid   // Strobe pulsed every audio frame
);

    // Clock divider counter
    reg [7:0] clk_cnt;
    wire bclk_pulse = (clk_cnt == (BCLK_DIV - 1));

    // I2S Bit Counter: 64 BCLKs per LRCLK period (32 bits per channel)
    reg [5:0] bit_cnt;

    // Shift registers
    reg [31:0] shift_rx;
    reg [31:0] shift_tx;

    // Generate BCLK
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_cnt <= 'd0;
            bclk    <= 1'b0;
        end else if (bclk_pulse) begin
            clk_cnt <= 'd0;
            bclk    <= ~bclk;
        end else begin
            clk_cnt <= clk_cnt + 1'b1;
        end
    end

    // Detect falling edge of internal BCLK for updating output bits
    wire bclk_fall = bclk_pulse && (bclk == 1'b1);
    // Detect rising edge of internal BCLK for latching incoming bits
    wire bclk_rise = bclk_pulse && (bclk == 1'b0);

    // I2S Shift & Framing Engine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_cnt       <= 'd0;
            lrclk         <= 1'b0;
            shift_rx      <= 'd0;
            shift_tx      <= 'd0;
            sdata_out     <= 1'b0;
            left_data_in  <= 'd0;
            right_data_in <= 'd0;
            sample_valid  <= 1'b0;
        end else begin
            sample_valid <= 1'b0; // default state

            // Transmit update on BCLK falling edge
            if (bclk_fall) begin
                sdata_out <= shift_tx[31];
                shift_tx  <= {shift_tx[30:0], 1'b0};
            end

            // Receive & control logic on BCLK rising edge
            if (bclk_rise) begin
                shift_rx <= {shift_rx[30:0], sdata_in};
                bit_cnt  <= bit_cnt + 1'b1;

                // Standard I2S transition: LRCLK changes 1 bit prior to MSB
                if (bit_cnt == 6'd31) begin
                    lrclk <= 1'b1; // Switch to Right Channel
                    left_data_in <= shift_rx[31 -: DATA_WIDTH];
                end else if (bit_cnt == 6'd63) begin
                    lrclk <= 1'b0; // Switch to Left Channel
                    right_data_in <= shift_rx[31 -: DATA_WIDTH];
                    
                    // Latch transmit data (clean mono/processed out to both channels)
                    shift_tx     <= {data_out, 16'd0};
                    sample_valid <= 1'b1; // Strobe sample valid for ANC DSP core
                end
            end
        end
    end

endmodule