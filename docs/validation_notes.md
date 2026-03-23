# Validation Notes

This document summarizes the **verification and validation status**
of the RMS / Peak Envelope Detector module.

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

- `tb_rms_peak_core`
- `tb_rms_peak_axis`

Each testbench logs internal behavior to CSV files, which are plotted and inspected offline.

---

### Core-Level Validation (`rms_peak_core`)

The following behaviors were verified:

#### Absolute Value Rectifier
- Correct handling of positive and negative inputs
- Explicit saturation for `-32768` corner case
- No wraparound or undefined behavior

#### Envelope Accumulator
- Correct leaky integration behavior
- Stable convergence toward signal magnitude
- Proper decay when input returns to zero
- No underflow below zero

#### Alpha Coefficient
- Correct scaling using fixed-point Q0.16
- Runtime alpha update behaves as expected
- Larger alpha → faster response
- Smaller alpha → smoother envelope

#### Bypass Mode
- Output switches to delayed rectified input
- Time alignment preserved
- No glitches during bypass enable/disable

---

### AXI-Stream Integration Validation (`rms_peak_axis`)

The following AXI behaviors were validated:

#### AXI-Stream Handshake
- Correct `tvalid / tready` interaction
- No data loss under continuous streaming
- Proper backpressure propagation

#### Latency
- Fixed latency of **3 clock cycles**
- Latency independent of:
  - input signal
  - alpha value
  - bypass state

#### Stereo Independence
- Left and Right channels processed independently
- No crosstalk or shared state
- Different amplitudes and phases handled correctly

---

## 2. Hardware Validation (Kria KV260)

### Test Environment

- Board: **AMD Kria KV260**
- Integration method: **PYNQ overlay**
- Data movement: **AXI DMA**
- Clocking: PL clock derived from PS
- Control: AXI-Lite register access from Python

Python was used **only** for:
- configuring registers
- streaming test data
- observing output behavior

Python is **not part of the design**.

---

### Hardware Test Coverage

The following were verified on real hardware:

- Correct AXI-Lite register access
- Alpha coefficient updates during runtime
- Enable / bypass switching
- Stable real-time streaming operation
- Envelope behavior consistent with simulation

Observed hardware behavior matched RTL simulation results.

---

### Known Validation Limits

The following were **intentionally not tested**:

- Long-duration stress testing (hours/days)
- Clock domain crossings
- Multi-clock or async environments
- Audio DAC / ADC loopback
- Perceptual audio evaluation
- Performance benchmarking (throughput limits)

These are outside the scope of this repository.

---

## Interpretation of Results

Based on simulation and hardware testing:

- The design is **functionally correct**
- Fixed-point behavior is **numerically safe**
- Latency is **deterministic and predictable**
- The module is suitable as a **building block**
  for dynamics processors (ducking, gating, metering)

This design is validated as a **reference RTL implementation**,  
not as a finished audio product.

---

## Validation Status Summary

| Aspect | Status |
|----|----|
| RTL simulation | ✅ Passed |
| AXI-Stream correctness | ✅ Passed |
| AXI-Lite control | ✅ Passed |
| Fixed-point safety | ✅ Passed |
| Hardware test (KV260) | ✅ Passed |
| Production readiness | ❌ Not evaluated |

---

## Final Note

This validation demonstrates that the design:

> **Works as intended, within its declared scope.**

Any further validation (system-level, perceptual, or production-grade)
should be performed in the context of a larger application.

