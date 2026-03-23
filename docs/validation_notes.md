# Validation Notes

This document summarizes the **verification and validation status**
of the Linear Ramp Envelope Follower module.

The goal of validation is **functional correctness and architectural soundness**,  
not exhaustive audio quality evaluation.

---

## Validation Scope

Validation was performed at two levels:

1. **RTL Simulation**
2. **FPGA Hardware Test (Kria KV260 via PYNQ overlay)**

The validation intentionally stops at **board-level functional testing**.  
No standalone application, driver, or production deployment is included.

---

## 1. RTL Simulation Validation

RTL simulation is the **primary correctness reference** for this design.

### Testbenches

Two dedicated testbenches were used:

- `tb_envelope_follower_core`
- `tb_envelope_follower_axis`

Each testbench logs internal behavior (including the Q4.12 envelope gain state) to CSV files, which are plotted and inspected offline.

---

### Core-Level Validation (`envelope_follower_core`)

The following behaviors were verified:

#### Rectifier & Peak Detection
- Correct handling of positive and negative inputs via absolute value conversion
- Linked-stereo detection: correctly compares Left and Right channels and uses the maximum magnitude to drive the envelope (preserves stereo image)

#### Linear Ramp Generator
- Correct state transitions between Attack, Release, and Steady states
- Strict linear increments/decrements based on cycle counters
- Stable convergence to the exact `TARGET_LEVEL` or `1.0` (4096) without overshoot or limit-cycle oscillations

#### Parameter Responses
- Threshold breaches accurately trigger the Attack phase
- `ATTACK_RATE` and `RELEASE_RATE` correctly dictate the envelope slope
- Graceful recovery to normal gain when the signal falls below the threshold

---

### AXI-Stream Integration Validation (`envelope_follower_axis`)

The following AXI behaviors were validated:

#### AXI-Stream Handshake
- Correct `tvalid / tready` interaction
- No data loss under continuous streaming
- Proper backpressure propagation, safely stalling the lookahead/pipeline shift registers

#### Datapath & Latency
- Fixed datapath latency of **1 clock cycle**
- Envelope gain accurately multiplied with the audio signal
- Correct arithmetic shift (`>>> 12`) to convert the 32-bit product back to 16-bit packed AXI-Stream output
- Latency is strictly independent of attack/release settings or signal amplitude

---

## 2. Hardware Validation (Kria KV260)

### Test Environment

- Board: **AMD Kria KV260**
- Integration method: **PYNQ overlay**
- Data movement: **AXI DMA**
- Clocking: PL clock (100 MHz) derived from PS
- Control: AXI-Lite register access from Python (PS)

Python was used **only** for:
- Configuring AXI-Lite registers
- Streaming test audio files (WAV) via DMA
- Simulating dynamic register modulation (e.g., LFO/Tremolo effect driven by the PS)

Python is **not part of the hardware datapath design**.

---

### Hardware Test Coverage

The following were verified on real hardware:

- Correct AXI-Lite register writes and reads (Threshold, Target Level, Rates)
- Enable / bypass switching via Control register
- Stable real-time stereo streaming operation at 48kHz
- Dynamic parameter updates during runtime (successfully tested PS-driven LFO modulating the Target Level to create an Auto-Tremolo effect)
- Gain reduction behavior completely consistent with RTL simulation results

---

### Known Validation Limits

The following were **intentionally not tested**:

- Long-duration stress testing (hours/days)
- Clock domain crossings (module assumes single synchronous clock)
- Multi-clock or async environments
- Direct Audio DAC / ADC I2S loopback (tested via DMA instead)
- Perceptual audio evaluation or psychoacoustic tuning
- Performance benchmarking (Fmax limits beyond 100MHz)

These are outside the scope of this repository.

---

## Interpretation of Results

Based on simulation and hardware testing:

- The design is **functionally correct and mathematically stable**
- Fixed-point behavior (Q4.12 math) is **numerically safe**
- Datapath latency is **highly optimized (1 cycle) and predictable**
- The module successfully operates as an inline dynamics processor

This design is validated as a **reference RTL implementation**,  
not as a finished audio product.

---

## Validation Status Summary

| Aspect | Status |
|----|----|
| RTL simulation | ✅ Passed |
| AXI-Stream correctness | ✅ Passed |
| AXI-Lite control | ✅ Passed |
| Fixed-point safety (Q4.12) | ✅ Passed |
| Hardware test (KV260 / PYNQ) | ✅ Passed |
| Production readiness | ❌ Not evaluated |

---

## Final Note

This validation demonstrates that the design:

> **Works as intended, within its declared scope.**

Any further validation (system-level, perceptual, or production-grade)
should be performed in the context of a larger application.
