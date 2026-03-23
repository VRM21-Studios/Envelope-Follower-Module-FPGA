# Simulation Results and Analysis

This directory contains **simulation results and waveform visualizations** for the **Linear Ramp Envelope Follower** implementation.

The results are generated from **cycle-accurate RTL simulation** and logged as CSV,
then plotted offline to validate **functional correctness, temporal behavior, and control response**.

---

## Files

| File | Description |
|----|----|
| `tb_envelope_follower_core.csv` | Raw core-level simulation data |
| `tb_envelope_follower_axis.csv` | AXI-Stream integrated simulation data |
| `tb_envelope_follower_core.png` | Core-level waveform visualization |
| `tb_envelope_follower_axis.png` | AXI-Stream waveform visualization |

---

## 1. Core-Level Results (`envelope_follower_core`)

This test verifies the **DSP behavior and envelope generation in isolation**, without AXI concerns.

### Signals Observed

- `audio_l_in`, `audio_r_in`: signed audio inputs  
- `current_gain`            : generated envelope gain (Q4.12)  
- `threshold`, `target_level`: amplitude limits and target gain controls
- `attack_rate`, `release_rate`: linear ramp speed controls

---

### Observations

#### a. Rectifier & Peak Detection

- Negative input samples are correctly rectified via absolute value conversion.
- Left and Right channels are compared (`max(abs_L, abs_R)`).
- The loudest channel correctly dictates the envelope behavior.

This confirms the **stereo-linked peak detector is safe and functional**.

---

#### b. Linear Ramp Attack and Release Behavior

- When `max_audio > threshold`, the gain decrements exactly 1 LSB per `attack_rate` cycles.
- When `max_audio <= threshold`, the gain increments exactly 1 LSB per `release_rate` cycles.
- The envelope follows a **strict linear slope**, stopping exactly at `target_level` or `1.0` (4096).

This confirms the implementation behaves as a **mathematically stable linear ramp**, avoiding the limit-cycle artifacts typical of IIR leaky integrators.

---

#### c. Dynamic Parameter Update

- Changing `attack_rate` or `release_rate` during runtime **immediately affects the envelope slope**.
- Adjusting `target_level` shifts the destination of the ramp safely without causing arithmetic overflow.

This validates that:
- Control parameters are sampled synchronously
- There is no hidden coefficient caching

---

#### d. Enable / Bypass Control

- When `en = 0`, the core gracefully holds or resets the gain state safely.
- No glitches or undefined behaviors occur when toggling the module on and off.

---

### Conclusion (Core-Level)

The core behaves exactly as designed:

- Deterministic linear progression  
- Numerically stable (fixed-point Q4.12)  
- Fully synchronous  
- Suitable for driving audio multiplier stages

---

## 2. AXI-Stream Level Results (`envelope_follower_axis`)

This test verifies **full system integration**:  
AXI-Stream audio data path + AXI-Lite control registers + Gain multiplier.

---

### Signals Observed

- `s_axis_tdata`   : packed 32-bit stereo input samples  
- `m_axis_tdata`   : packed 32-bit stereo output samples (gain applied)
- `env_gain`       : internally probed Q4.12 envelope gain
- `m_axis_tvalid`  : AXI-Stream `TVALID`  

---

### Observations

#### a. Gain Application & Stereo Image

- Both Left and Right audio channels are multiplied by the **same** `env_gain`.
- Audio output amplitude scales down accurately when `env_gain` drops below 4096.
- Fixed-point multiplication (`>>> 12`) truncates perfectly back to 16-bit without clipping.

This confirms **stereo image is preserved** (no center-shifting during aggressive ducking).

---

#### b. Envelope vs Audio Waveform

- Input shows abrupt transient spikes.
- `env_gain` drops linearly, creating a controlled "ducking" or "compressing" effect on the output audio.
- The output waveform reflects the **gain reduction instantly** as the ramp evolves.

This confirms the module functions correctly as an **inline dynamics processor**.

---

#### c. AXI Handshake Correctness

- `TVALID` remains asserted continuously when downstream is ready.
- Audio passes seamlessly even during envelope state transitions.
- Backpressure stalls the pipeline gracefully without dropping samples.

Backpressure behavior is safe due to:
`core_valid_in = s_axis_tvalid && stream_ready;`

---

#### d. Runtime Control via AXI-Lite

- `THRESHOLD` and `TARGET_LEVEL` updates via AXI-Lite take effect seamlessly.
- No protocol violations observed during concurrent streaming and register writes.

This confirms:
- Control plane (AXI-Lite) and data plane (AXI-Stream) are cleanly separated
- No CDC or partial-write hazards exist

---

## Latency Summary

| Stage | Latency |
|----|----|
| Envelope Calculation (Core) | 0 cycles (Combinatorial) |
| Gain Application (Multiplier) | 0 cycles (Combinatorial) |
| Output Register (`m_axis_tdata`) | 1 cycle |
| **Total Audio Latency** | **1 cycle (fixed)** |

Latency is:
- Extremely optimized (1 cycle total datapath delay)
- Independent of input amplitude
- Independent of attack/release settings

---

## Overall Conclusion

The simulation results confirm that this module is:

- **Functionally correct**
- **Numerically stable (eliminating IIR feedback issues)**
- **Cycle-accurate with ultra-low latency (1-cycle)**
- **AXI-compliant**
- **Safe for real-time inline audio processing**

The design behaves as a highly predictable **hardware envelope follower and dynamic gain controller**.

---

## Notes

This repository intentionally focuses on:

- RTL behavior  
- Fixed-point math safety (Q4.12)  
- Streaming correctness and minimal latency  

Not included:
- Psychoacoustic tuning (e.g., RMS windows, soft-knee curves)  
- Ratio-based proportional compression (operates as a fixed-target ducker/limiter)

Those belong to more complex DSP architectures.

---

> **These results validate design decisions and architectural stability, proving the efficacy of the linear ramp approach over legacy IIR methods.**
