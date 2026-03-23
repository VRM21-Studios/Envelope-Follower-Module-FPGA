# Simulation Results and Analysis

This directory contains **simulation results and waveform visualizations**  
for the **RMS / Peak Envelope Detector** implementation.

The results are generated from **cycle-accurate RTL simulation** and logged as CSV,
then plotted offline to validate **functional correctness, temporal behavior, and control response**.

---

## Files

| File | Description |
|----|----|
| `tb_data_rms_peak_core.csv` | Raw core-level simulation data |
| `tb_data_rms_peak_axis.csv` | AXI-Stream integrated simulation data |
| `tb_waveform_rms_peak_core.png` | Core-level waveform visualization |
| `tb_waveform_rms_peak_axis.png` | AXI-Stream waveform visualization |

---

## 1. Core-Level Results (`rms_peak_core`)

This test verifies the **DSP behavior in isolation**, without AXI concerns.

### Signals Observed

- `din`   : signed audio input  
- `dout`  : envelope output  
- `alpha` : smoothing coefficient (Q0.16)  
- `bypass`: bypass control flag  

---

### Observations

#### a. Absolute Value Rectification

- Negative input samples are correctly rectified.
- Corner case `-32768` is handled safely (saturated to `+32767`).
- No wraparound or undefined behavior observed.

This confirms the **rectifier stage is safe and deterministic**.

---

#### b. Envelope Attack and Release Behavior

- With **large alpha**, the envelope rises quickly (fast attack).
- With **small alpha**, the envelope changes slowly (smooth release).
- Envelope follows the *amplitude trend*, not the waveform itself.

This confirms the implementation behaves as a **leaky integrator envelope detector**, not an RMS window.

---

#### c. Dynamic Alpha Update

- Changing `alpha` during runtime **immediately affects envelope slope**.
- No instability or glitch observed when alpha is updated mid-stream.

This validates that:
- `alpha` is sampled synchronously
- no hidden state or coefficient caching exists

---

#### d. Bypass Mode

- When `bypass = 1`, output follows **rectified input**, time-aligned.
- Latency is preserved (bypass is delay-matched, not combinational).

Bypass is **structural**, not a special gain value.

---

### Conclusion (Core-Level)

The core behaves exactly as designed:

- Deterministic  
- Numerically safe  
- Fully synchronous  
- Suitable for real-time control signals (envelope followers, sidechains)

---

## 2. AXI-Stream Level Results (`rms_peak_axis`)

This test verifies **full system integration**:  
AXI-Stream data path + AXI-Lite control.

---

### Signals Observed

- `in_L`, `in_R`   : stereo input samples  
- `out_L`, `out_R` : envelope outputs  
- `valid_out`      : AXI-Stream `TVALID`  

---

### Observations

#### a. Stereo Independence

- Left and Right channels are processed independently.
- Different amplitudes and phases produce correct, independent envelopes.
- No crosstalk observed.

This confirms **true dual-core instantiation**, not shared state.

---

#### b. Envelope vs Waveform

- Input shows full-rate sine wave.
- Output shows **slowly varying envelope**, following amplitude.

This confirms:
- Envelope is computed **per-sample**
- No block-based averaging is used
- No RMS windowing artifacts exist

---

#### c. AXI Handshake Correctness

- `TVALID` remains asserted continuously when downstream is ready.
- No dropped samples or bubbles observed.
- Output latency is fixed and deterministic.

Backpressure behavior is safe due to:

```
core_ce = s_axis_tvalid && m_axis_tready && global_en
```


---

#### d. Runtime Control via AXI-Lite

- `alpha` updates take effect without halting the stream.
- Enable / bypass control works during active streaming.
- No protocol violations observed.

This confirms:
- Control plane and data plane are cleanly separated
- No CDC or partial-write hazards exist

---

## Latency Summary

| Stage | Latency |
|----|----|
| Rectifier | 1 cycle |
| Envelope accumulator | 1 cycle |
| Output register / alignment | 1 cycle |
| **Total** | **3 cycles (fixed)** |

Latency is:
- independent of input
- independent of alpha
- independent of bypass

---

## Overall Conclusion

The simulation results confirm that this module is:

- **Functionally correct**
- **Numerically stable**
- **Cycle-accurate**
- **AXI-compliant**
- **Safe for real-time streaming**

The design behaves as a **hardware envelope follower**, not a software RMS approximation.

---

## Notes

This repository intentionally focuses on:

- RTL behavior  
- fixed-point reasoning  
- streaming correctness  

Not included:
- psychoacoustic tuning  
- perceptual optimization  
- software-side smoothing  

Those belong to higher system layers.

---

> **These results validate design decisions, not algorithmic ambition.**
