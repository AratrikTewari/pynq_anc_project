# PYNQ-Z2 ANC Project - Jupyter Notebooks

This directory contains Jupyter notebooks for testing and validating the Adaptive Noise Cancellation (ANC) system on the PYNQ-Z2 board.

## Notebooks Overview

### 1. `01_setup.ipynb` - FPGA Programming and Basic I/O Verification
**Purpose**: Load the FPGA bitstream and verify basic I/O functionality.

**Tests**:
- Bitstream loading
- GPIO controller access
- LED read/write verification
- Switch input reading
- Manual I/O test (buttons, switches, LEDs)
- Clock domain verification

**Prerequisites**: None (first notebook to run)

**Expected Outcome**: FPGA programmed, basic I/O functional

---

### 2. `02_audio_codec_test.ipynb` - Audio Codec Interface Test
**Purpose**: Test the I2S codec interface on Pmod JA.

**Tests**:
- Codec controller register access
- Clock signal generation (MCLK, BCLK, LRCLK)
- Audio capture from left channel
- Audio capture from right channel
- Audio playback testing
- Sample rate verification (~48.8 kHz)

**Prerequisites**:
- Complete `01_setup.ipynb`
- Connect I2S audio codec to Pmod JA:
  - JA[0] (Y18): MCLK (12.5 MHz)
  - JA[1] (Y19): BCLK (~3.125 MHz)
  - JA[2] (Y16): LRCLK (~48.8 kHz)
  - JA[3] (Y17): SDATA_IN (ADC output)
  - JA[4] (U18): SDATA_OUT (DAC input)

**Expected Outcome**: Codec interface functional, audio capture/playback working

---

### 3. `03_anc_operation.ipynb` - Full ANC System Operation
**Purpose**: Test the complete ANC system with real audio input.

**Tests**:
- ANC core register access
- ANC mode configuration
- Audio capture (noisy input)
- Audio capture (cleaned output)
- Noise reduction measurement
- Step-size adaptation monitoring
- Spectral analysis
- Real-time monitoring
- Audio file export

**Prerequisites**:
- Complete `02_audio_codec_test.ipynb`
- Connect audio sources:
  - Primary audio (signal + noise) → Codec Left Channel
  - Reference noise (correlated) → Codec Right Channel
- Connect headphones/speakers to codec output
- Set SW0 to position 0 (ANC active mode)

**Expected Outcome**: ANC operational, noise reduction observed

---

### 4. `04_performance_analysis.ipynb` - Performance Analysis
**Purpose**: Detailed analysis of ANC convergence and adaptation behavior.

**Tests**:
- Long-term convergence monitoring (30 seconds)
- Error convergence visualization
- Step-size adaptation tracking
- Convergence metrics calculation
- Step-size distribution analysis
- Adaptive response to noise changes
- Filter weight monitoring (if accessible)
- Performance report generation

**Prerequisites**:
- Complete `03_anc_operation.ipynb`
- Stable audio source connected
- ANC system operational

**Expected Outcome**: Detailed performance metrics, convergence analysis

---

### 5. `05_bypass_mode.ipynb` - Bypass Mode Verification
**Purpose**: Verify bypass mode functionality and compare with ANC mode.

**Tests**:
- ANC mode audio capture
- Bypass mode audio capture
- Output comparison (ANC vs bypass)
- Bypass functionality verification
- Noise reduction comparison
- Real-time mode switching
- LED indicator monitoring
- Spectral comparison
- Audio file export

**Prerequisites**:
- Complete all previous notebooks
- ANC system operational

**Expected Outcome**: Bypass mode functional, mode switching works

---

## Hardware Setup

### Required Hardware
- PYNQ-Z2 board
- I2S audio codec (e.g., WM8731, CS4272, or similar)
- Audio source (signal + noise)
- Reference noise source (correlated with primary noise)
- Headphones or speakers
- Pmod cable for codec connection

### Pin Mapping (Pmod JA)
| Pmod Pin | FPGA Pin | Signal | Description |
|----------|----------|--------|-------------|
| JA[0]    | Y18      | MCLK   | Master Clock (12.5 MHz) |
| JA[1]    | Y19      | BCLK   | Bit Clock (~3.125 MHz) |
| JA[2]    | Y16      | LRCLK  | Word Select (~48.8 kHz) |
| JA[3]    | Y17      | SDATA_I| Serial Data In (ADC) |
| JA[4]    | U18      | SDATA_O| Serial Data Out (DAC) |

### Board Controls
- **BTN0**: Reset button (active-low)
- **SW0**: Bypass switch (0 = ANC active, 1 = Bypass mode)
- **LD0-LD3**: Convergence status LEDs (step-size indicator)

---

## Register Map

The following register offsets are used in the notebooks. **Adjust these based on your Vivado design's AXI-Lite interface mapping.**

### ANC Core Registers
| Offset | Register | Description |
|--------|----------|-------------|
| 0x00   | mu_shift | Active step-size shift value |
| 0x04   | primary_in | Primary audio input (d[n]) |
| 0x08   | ref_noise | Reference noise input (x[n]) |
| 0x0C   | cleaned_out | Cleaned audio output (e[n]) |
| 0x10   | data_ready | Sample valid flag |
| 0x20+  | weights[0-15] | Filter weights (if exposed) |

### GPIO Registers
| Offset | Register | Description |
|--------|----------|-------------|
| 0x00   | bypass | Bypass switch input |
| 0x04   | leds | LED outputs |

**Note**: These offsets are examples. You must update them in each notebook to match your Vivado design's address map.

---

## Vivado Design Requirements

For the notebooks to work correctly, your Vivado design must include:

1. **AXI GPIO Controllers** (optional but recommended):
   - One for bypass switch input
   - One for LED outputs

2. **AXI-Lite Interface** for ANC core:
   - Expose key registers (mu_shift, primary_in, cleaned_out, data_ready)
   - Ensure proper address mapping

3. **Interrupts** (optional):
   - For efficient sample valid detection
   - Can use polling if interrupts not available

4. **Clock Management**:
   - 125 MHz system clock
   - Proper clock dividers for codec

---

## Usage Instructions

### 1. Transfer Notebooks to PYNQ-Z2
```bash
# On your local machine
scp -r notebooks/ xilinx@<pynq-ip>:/home/xilinx/jupyter_notebooks/
```

### 2. Transfer Bitstream
```bash
# Transfer the compiled bitstream
scp anc_project.bit xilinx@<pynq-ip>:/home/xilinx/jupyter_notebooks/
```

### 3. Open Jupyter Notebook
- Navigate to the PYNQ-Z2 web interface
- Open the notebooks directory
- Run notebooks in order (01 → 02 → 03 → 04 → 05)

### 4. Execute Notebooks
- Run each cell sequentially
- Read instructions before execution
- Adjust register offsets if needed
- Verify hardware connections before testing

---

## Troubleshooting

### Bitstream Loading Fails
- Ensure `.bit` file is in the correct directory
- Check that the Vivado project was built for PYNQ-Z2 (xc7z020clg400-1)
- Verify the bitstream filename matches in the notebook

### GPIO/Controller Not Found
- Check that AXI GPIO IP blocks are included in the Vivado design
- Verify the IP names match what the notebooks search for
- Use `overlay.ip_dict` to list all available IP blocks

### Register Read/Write Errors
- Verify register offsets match your Vivado design
- Check that the address range is correct
- Ensure the IP block is properly connected to the AXI interconnect

### No Audio Capture
- Verify codec is connected to Pmod JA correctly
- Check codec power supply
- Ensure audio source is connected
- Verify clock signals with oscilloscope (if available)

### No Noise Reduction
- Ensure reference noise is correlated with primary noise
- Check that bypass switch is in ANC mode (SW0 = 0)
- Verify audio levels are appropriate (not too quiet, not clipping)
- Allow time for convergence (several seconds)

### Step-Size Not Changing
- Check that audio is present at both inputs
- Verify the step-size controller is enabled
- Allow more time for adaptation
- Check error energy levels

---

## Customization

### Adjusting Register Offsets
Each notebook has a section defining register offsets. Update these to match your design:

```python
# Example in each notebook
MU_SHIFT_OFFSET = 0x00  # Adjust based on your design
PRIMARY_IN_OFFSET = 0x04
REF_NOISE_OFFSET = 0x08
CLEANED_OUT_OFFSET = 0x0C
DATA_READY_OFFSET = 0x10
```

### Changing Sample Rate
The design uses ~48.8 kHz. If you change this, update:

```python
SAMPLE_RATE = 48828  # Adjust to your sample rate
```

### Modifying Test Duration
Adjust duration variables in each notebook:

```python
DURATION = 2.0  # seconds
NUM_SAMPLES = int(DURATION * SAMPLE_RATE)
```

---

## Performance Expectations

### Convergence Time
- Initial convergence: 2-5 seconds (depending on noise level)
- Steady-state: step-size should settle at higher shift values (5-6)

### Noise Reduction
- Expected: 5-15 dB reduction with correlated noise
- Minimum threshold: >3 dB for effective ANC

### Step-Size Adaptation
- Fast adaptation (shift 1-2): Initial convergence
- Medium adaptation (shift 3-4): Tracking changes
- Fine adaptation (shift 5-6): Steady-state precision

---

## Additional Resources

- [PYNQ Documentation](http://www.pynq.io/)
- [PYNQ-Z2 Board Reference Manual](https://reference.digilentinc.com/reference/programmable-logic/pynq-z2/start)
- [Vivado Design Suite Documentation](https://www.xilinx.com/support/documentation/sw_manuals/xilinx2024_1/ug901-vivado-design-suite.pdf)

---

## License

This project is licensed under the terms specified in the main project LICENSE file.
