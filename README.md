# Nexys A7 (Artix-7) Mono PDM Microphone Capture, FIR Filtering & Multi-Output Visualizer

This repository implements a **SystemVerilog** audio acquisition and digital signal processing (DSP) pipeline on the **Digilent Nexys A7 (Artix-7 DDR4)** FPGA board. The system captures single-channel (mono) audio from the onboard omnidirectional MEMS microphone, processes the demodulated 9-bit PCM amplitude through a switchable **5-tap FIR low-pass filter**, and routes the signal to four output interfaces: onboard LEDs, 7-segment displays, UART serial streaming with a Python visualizer, and a VGA waveform display.

---

## ⚙️ System Architecture & Module Hierarchy

* **`top_mic_vu.sv` (Top-Level Module):**
  * Generates a **~2.38 MHz PDM clock** (`mic_clk`) from the 100 MHz system clock (`clk_100mhz`) and sets `mic_lr_sel = 1'b0` for mono channel capture.
  * Instantiates a **Clocking Wizard IP (`clk_wiz_0`)** to generate a **108 MHz** pixel clock (`pxl_clk_108mhz`) for the VGA subsystem.
  * Uses **`SW0` (`filter_sw`)** to dynamically select between raw demodulated audio (`0`) and FIR-filtered audio (`1`) for downstream visualization.
* **`mic_vu_meter.sv` (PDM Demodulation & LED Meter):**
  * Synchronizes PDM clock edges via `sync_async.sv` and demodulates the 1-bit `mic_data` stream using a 375-bit shift register (`SR_WIDTH = 375`) into a 9-bit amplitude value (`sample_out`).
  * Drives **8 onboard LEDs (`LED[7:0]`)** across 8 amplitude thresholds (`> 40` to `> 320`).
* **`fir_filter.sv` (5-Tap Binomial FIR Low-Pass Filter):**
  * Implements a 5-tap shift-register FIR filter with symmetric coefficients **`b = [1, 4, 6, 4, 1]`** using shift-and-add arithmetic (no DSP multipliers required) and normalizes the output via a 4-bit right shift (`>> 4`, dividing by 16).
* **`seven_segment_ctrl.sv` (3-Level Noise Indicator):**
  * Multiplexes all 8 onboard 7-segment digits at ~1 kHz and categorizes `final_sample` into three discrete noise levels:
    * **Quiet / Low Noise (`sample_val <= 70`):** Illuminates the bottom bar segment (`CD` — `_`).
    * **Moderate Noise (`71 <= sample_val <= 85`):** Illuminates the middle and bottom bar segments (`CG`, `CD` — `=`).
    * **High Noise (`sample_val > 85`):** Illuminates the top, middle, and bottom bar segments (`CA`, `CG`, `CD` — `≡`).
* **`uart_tx.sv` & `mic_uart_python_code.py` (Serial Streaming & PC Visualizer):**
  * Transmits the upper 8 bits (`final_sample[8:1]`) over USB-UART (`D4`) at **115,200 baud**.
  * The companion Python script (`mic_uart_python_code.py`) reads the incoming stream via `pyserial` and plots a rolling 250-sample window using `matplotlib` blitting for low-latency waveform rendering.
* **`vga_controller.sv` & `mic_display.sv` (1280×1024 VGA Waveform Display):**
  * Inspired by the Digilent Nexys A7 Out-of-Box (OOB) demo, renders a `915×375` waveform window backed by an inferred dual-port Block RAM buffer over a dynamic colorbar background at **1280×1024 @ 60 Hz**.

---

## ⚠️ Known Issues & Limitations

* **VGA Display Stability & Clock-Domain Crossing (CDC):** The VGA waveform subsystem (`vga_controller` / `mic_display`) is currently experimental and may exhibit display/synchronization instability.

---

## 📂 Repository Structure

```text
Nexys-A7-PDM-Microphone-FIR-Visualizer/
├── rtl/
│   ├── top_mic_vu.sv          
│   ├── mic_vu_meter.sv         
│   ├── fir_filter.sv           
│   ├── seven_segment_ctrl.sv   
│   ├── uart_tx.sv              
│   ├── vga_controller.sv       
│   ├── mic_display.sv          
│   └── sync_async.sv           
├── constraints/                
├── software/
│   └── mic_uart_python_code.py # Real-time Python serial waveform plotter
└── README.md
```

---

## 🛠️ Tools & References

* **HDL & Synthesis:** SystemVerilog, AMD Vivado
* **Host Visualization:** Python
* **Hardware Platform:** Digilent Nexys A7 (Artix-7 DDR4)
* **Reference Material:** Digilent Nexys A7 Reference Manual (PDM Microphone section) & Digilent Nexys A7 Out-of-Box (OOB) Demo repository.
