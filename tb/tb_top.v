`timescale 1ns / 1ps

module tb_top;

    localparam CLK_PERIOD = 8; // 125 MHz clock (8 ns)

    reg        sysclk;
    reg        btn_rst_n;
    reg        sw_bypass;

    wire       codec_mclk;
    wire       codec_bclk;
    wire       codec_lrclk;
    reg        codec_sdata_i;
    wire       codec_sdata_o;
    wire [3:0] leds;

    // Unit Under Test (UUT)
    top_pynq_anc #(
        .DATA_WIDTH(16),
        .FILTER_TAPS(16)
    ) uut (
        .sysclk(sysclk),
        .btn_rst_n(btn_rst_n),
        .sw_bypass(sw_bypass),
        .codec_mclk(codec_mclk),
        .codec_bclk(codec_bclk),
        .codec_lrclk(codec_lrclk),
        .codec_sdata_i(codec_sdata_i),
        .codec_sdata_o(codec_sdata_o),
        .leds(leds)
    );

    // 125 MHz Clock Generator
    always #(CLK_PERIOD / 2) sysclk = ~sysclk;

    // Helper task to send one 64-bit I2S Frame (Left + Right channels)
    task send_i2s_frame;
        input [15:0] left_pcm;   // Primary audio d[n]
        input [15:0] right_pcm;  // Reference noise x[n]
        integer bit_idx;
        begin
            // --- Left Channel (32 BCLK cycles, MSB first with 1 BCLK delay) ---
            wait (codec_lrclk == 1'b0);
            @(negedge codec_bclk); // Transition data on falling edge

            for (bit_idx = 31; bit_idx >= 0; bit_idx = bit_idx - 1) begin
                if (bit_idx >= 16)
                    codec_sdata_i = left_pcm[bit_idx - 16];
                else
                    codec_sdata_i = 1'b0; // Pad lower 16 bits
                @(negedge codec_bclk);
            end

            // --- Right Channel (32 BCLK cycles) ---
            wait (codec_lrclk == 1'b1);
            @(negedge codec_bclk);

            for (bit_idx = 31; bit_idx >= 0; bit_idx = bit_idx - 1) begin
                if (bit_idx >= 16)
                    codec_sdata_i = right_pcm[bit_idx - 16];
                else
                    codec_sdata_i = 1'b0; // Pad lower 16 bits
                @(negedge codec_bclk);
            end
        end
    endtask

    // Monitor serialized output received from codec_sdata_o
    reg [15:0] captured_dac_word;
    integer rx_idx;
    initial begin
        forever begin
            // Wait for start of left frame transmission
            wait (codec_lrclk == 1'b0);
            @(posedge codec_bclk); // I2S standard: 1 dummy cycle delay
            
            captured_dac_word = 16'd0;
            for (rx_idx = 15; rx_idx >= 0; rx_idx = rx_idx - 1) begin
                @(posedge codec_bclk);
                captured_dac_word[rx_idx] = codec_sdata_o;
            end
        end
    end

    initial begin
        // Initialize Control Lines
        sysclk        = 1'b0;
        btn_rst_n    = 1'b0;
        sw_bypass    = 1'b0;
        codec_sdata_i = 1'b0;

        // Apply Reset Pulse
        #(CLK_PERIOD * 20);
        btn_rst_n = 1'b1;
        $display("System Reset Released.");

        // Wait for clock dividers to stabilize
        wait (codec_lrclk == 1'b0);

        // Frame 1: Initial calibration frame (silence)
        send_i2s_frame(16'sh0000, 16'sh0000);

        // Frame 2 & 3: Noise test frames (ANC mode: sw_bypass = 0)
        $display("Transmitting I2S frames in ANC mode...");
        send_i2s_frame(16'sh2000, 16'sh1000);
        send_i2s_frame(16'sh2200, 16'sh1100);

        // Switch to Bypass Mode (sw_bypass = 1: Output should match primary d[n])
        sw_bypass = 1'b1;
        $display("Switching to Bypass mode...");
        send_i2s_frame(16'sh3500, 16'sh0800);
        send_i2s_frame(16'sh4200, 16'sh0500);

        #(CLK_PERIOD * 100);
        $display("Top-Level Simulation Completed.");
        $finish;
    end

endmodule