###############################################################################
# PYNQ-Z2 Board Constraints for Adaptive Noise Cancellation (ANC) Project
# Vivado 2025.2 / Zynq-7000 (xc7z020clg400-1)
###############################################################################

## Clock Signal (125 MHz Oscillator)
set_property -dict { PACKAGE_PIN H16   IOSTANDARD LVCMOS33 } [get_ports { sysclk }];
create_clock -add -name sys_clk_pin -period 8.000 -waveform {0 4.000} [get_ports { sysclk }];

## Reset Pushbutton (BTN0 - Active Low in RTL logic)
set_property -dict { PACKAGE_PIN D19   IOSTANDARD LVCMOS33 } [get_ports { btn_rst_n }];

## ANC Bypass Switch (SW0: 1 = Raw bypass, 0 = ANC active)
set_property -dict { PACKAGE_PIN M20   IOSTANDARD LVCMOS33 } [get_ports { sw_bypass }];

## Convergence Step-Size Status Indicators (LED0 - LED3)
set_property -dict { PACKAGE_PIN R14   IOSTANDARD LVCMOS33 } [get_ports { leds[0] }]; # LD0
set_property -dict { PACKAGE_PIN P14   IOSTANDARD LVCMOS33 } [get_ports { leds[1] }]; # LD1
set_property -dict { PACKAGE_PIN N16   IOSTANDARD LVCMOS33 } [get_ports { leds[2] }]; # LD2
set_property -dict { PACKAGE_PIN M14   IOSTANDARD LVCMOS33 } [get_ports { leds[3] }]; # LD3

###############################################################################
# I2S Audio Codec Interface (Mapped to Pmod Header JA)
# JA[0] -> Pin Y18  : Master Clock (codec_mclk)   - 12.5 MHz
# JA[1] -> Pin Y19  : Bit Clock (codec_bclk)      - ~3.125 MHz
# JA[2] -> Pin Y16  : Word Select / LRCLK         - ~48.8 kHz
# JA[3] -> Pin Y17  : Serial Data In (codec_sdata_i)
# JA[4] -> Pin U18  : Serial Data Out (codec_sdata_o)
###############################################################################

set_property -dict { PACKAGE_PIN Y18   IOSTANDARD LVCMOS33 } [get_ports { codec_mclk }];
set_property -dict { PACKAGE_PIN Y19   IOSTANDARD LVCMOS33 } [get_ports { codec_bclk }];
set_property -dict { PACKAGE_PIN Y16   IOSTANDARD LVCMOS33 } [get_ports { codec_lrclk }];
set_property -dict { PACKAGE_PIN Y17   IOSTANDARD LVCMOS33 } [get_ports { codec_sdata_i }];
set_property -dict { PACKAGE_PIN U18   IOSTANDARD LVCMOS33 } [get_ports { codec_sdata_o }];

###############################################################################
# Timing & False Path Constraints
###############################################################################

# Asynchronous inputs: Pushbutton and Switch
set_false_path -from [get_ports { btn_rst_n }]
set_false_path -from [get_ports { sw_bypass }]

# Static visual outputs: LEDs
set_false_path -to [get_ports { leds[*] }]

# Configuration Settings
set_property BITSTREAM.CONFIG.UNUSEDPIN PULLUP [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]