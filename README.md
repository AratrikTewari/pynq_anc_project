# Real-Time Adaptive Noise Cancellation (ANC) on PYNQ-Z2

An FPGA-based, real-time Adaptive Noise Cancellation system implemented in Verilog for the Xilinx Zynq-7000 SoC (XC7Z020CLG400-1) on the PYNQ-Z2 board. The design uses a pipelined Variable Step-Size Least Mean Squares (VSS-LMS) adaptive filter engine to cancel acoustic noise from an audio stream in real time.

---

## Features & Novelty

* **VSS-LMS Adaptation (`step_size_controller.v`)**: Dynamically tracks residual error energy via a leaky absolute integrator. Automatically shifts step size ($\mu$) across coarse-to-fine thresholds: accelerates initial transient convergence and tightens steady-state misadjustment.
* **Pipelined MAC Datapath (`fir_engine.v`)**: Fully pipelined 16-tap FIR architecture utilizing a balanced 2-stage adder tree. Maps directly to Xilinx DSP48E1 slices and meets timing closure at 125 MHz ($T_{clk} = 8.0\text{ ns}$).
* **2-Stage Registered Weight Adaptation (`lms_filter.v`)**: Separates gradient multiplication from dynamic barrel shifting and saturated accumulation to cut combinational logic depth and maintain positive timing slack.
* **Standard I2S Codec Controller (`audio_codec_ctrl.v`)**: Generates Master Clock ($12.5\text{ MHz}$), Bit Clock ($\approx 3.125\text{ MHz}$), and Word Select ($\approx 48.8\text{ kHz}$) directly from the $125\text{ MHz}$ system clock to interface with external audio codecs over Pmod JA.
* **Hardware Visualizer & Bypass Switch**: Live step-size adaptation tracking via onboard LEDs (`LD0`–`LD3`) and hardware raw audio bypass toggle via `SW0`.

---

## Directory Structure

```text
pynq_anc_project/
│
├── constraints/
│   └── pynq_z2_anc.xdc          # Pin assignments (125 MHz clock, I/O, I2S on Pmod JA)
│
├── rtl/
│   ├── top_pynq_anc.v           # Top-level wrapper (clock dividers, I/O routing, LED logic)
│   ├── anc_core.v               # ANC processing pipeline & sample alignment datapath
│   ├── lms_filter.v             # Pipelined adaptive filter & weight update engine
│   ├── fir_engine.v             # Pipelined DSP48 MAC engine with balanced adder tree
│   ├── step_size_controller.v   # Leaky-integrator variable step-size gear shifter
│   └── audio_codec_ctrl.v       # Serial full-duplex I2S transceiver (48.8 kHz, 64-bit frame)
│
├── tb/
│   ├── tb_anc_core.v            # Direct core testbench verifying convergence & noise suppression[cite: 1]
│   ├── tb_top.v                 # Full-system testbench driving external I2S frame streams[cite: 1]
│   └── stimulus/
│       ├── primary_signal.mem   # 16-bit hex vectors: Clean tone + correlated noise[cite: 1]
│       └── reference_noise.mem  # 16-bit hex vectors: Correlated reference noise source[cite: 1]
│
└── .gitignore                   # Vivado project caches and build artifact exclusions
