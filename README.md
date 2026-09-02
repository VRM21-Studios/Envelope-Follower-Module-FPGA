# Linear Ramp Envelope Follower (AXI-Stream) on FPGA

This repository provides a **reference RTL implementation** of a
**real-time Linear Ramp Envelope Follower and Dynamics Processor**
implemented in **Verilog**, integrated with **AXI-Stream** and **AXI-Lite**.

Target platform: **AMD Kria KV260** Focus: **deterministic RTL DSP design, fixed-point stability, and AXI correctness**

This module is intended for **continuous real-time audio streaming**,  
featuring ultra-low latency and absolute mathematical stability.

---

## Motivation

This project was developed as part of a self-directed exploration of real-time audio DSP and hardware-based dynamics processing.

An envelope follower introduces signal-dependent behavior and internal state, making it useful for studying how amplitude analysis and control signals can be generated directly within a deterministic RTL architecture. The project also explores the interaction between fixed-point arithmetic, streaming dataflow, and predictable real-time behavior.

---

## Overview

This design implements:

- **Function**: Linear ramp envelope generator & inline gain controller
- **Purpose**: Hardware-stable dynamics processing (ducking, gating, auto-tremolo)
- **Data type**: Fixed-point arithmetic (strictly Q4.12 for gain)
- **Scope**: Minimal, highly reliable DSP building block

Unlike legacy IIR (leaky integrator) designs, this implementation uses a **counter-based linear ramp state machine**. It completely eliminates fixed-point limit-cycle artifacts and provides exact, predictable convergence to target gain levels.

---

## Key Characteristics

- RTL written in **Verilog**
- **AXI-Stream** stereo audio interface (inline processing)
- **AXI-Lite** runtime control (5 registers)
- Fully synchronous, cycle-accurate design
- **Ultra-low deterministic latency (1 cycle)**
- Safe fixed-point arithmetic (Q4.12 truncation without clipping)
- Designed for **real-time streaming DSP**
- No software runtime included (Python used only for testbed/modulation)

---

## Architecture

High-level structure:
```

    AXI-Stream In (Stereo 32-bit packed)
            |
            v
    +-----------------------------------------+
    | Envelope Follower Core                  |
    | - Stereo-Linked Abs Rectifier           |
    | - Peak/Threshold Comparator             |
    | - Linear Ramp Generator (Counter-based) |
    +-----------------------------------------+
            |                  |
            | (Audio)          | (Q4.12 Envelope Gain)
            v                  v
    +-----------------------------------------+
    | Gain Application Stage                  |
    | - 32-bit Multiplication                 |
    | - Arithmetic Shift & Truncation (>>> 12)|
    +-----------------------------------------+
            |
            v
    AXI-Stream Out (Gain Applied, Stereo 32-bit)

```
Design notes:

- Peak detection is **stereo-linked** (the loudest channel dictates the gain reduction for both channels, preserving the stereo image).
- Control plane (AXI-Lite) is fully separated from data plane (AXI-Stream).
- No hidden buffering, block processing, or feedback loops.

---

## Data Format

### AXI-Stream (Audio In & Out)

- Data width: **32-bit packed**
- Stereo layout:
  - `[15:0]`   → Left Channel
  - `[31:16]`  → Right Channel
- Samples are signed **16-bit PCM**

### Internal Envelope Gain

- Data width: **16-bit signed**
- Format: **Q4.12 Fixed-Point** (e.g., `4096` = 1.0, `2048` = 0.5)

---

## Latency

| Stage | Cycles |
|----|----|
| Envelope Calculation (Core) | 0 (Combinatorial) |
| Gain Application (Multiplier) | 0 (Combinatorial) |
| Output Register / Alignment | 1 |
| **Total** | **1 cycle (fixed)** |

Latency is:

- ultra-low and deterministic
- independent of input signal amplitude
- independent of attack/release settings
- perfectly phase-aligned

---

## Control Interface (AXI-Lite)

| Offset | Register | Description |
|----:|----|----|
| 0x00 | CTRL | Bit 0: Enable (1 = Active, 0 = Bypass) |
| 0x04 | THRESHOLD | Amplitude threshold to trigger the attack phase |
| 0x08 | TARGET_LEVEL | Target gain when threshold is breached (Q4.12) |
| 0x0C | ATTACK_RATE | Clock cycles per 1-LSB gain decrement |
| 0x10 | RELEASE_RATE | Clock cycles per 1-LSB gain increment |

All registers can be updated safely **during active streaming**.

---

## Verification & Validation

### RTL Simulation

Simulation verifies:

- Stereo-linked rectifier correctness
- Linear ramp behavior (attack / release slopes)
- Runtime parameter updates (Threshold, Target, Rates)
- AXI-Stream handshake and backpressure safety
- Q4.12 mathematical truncation

Results are logged as CSV and plotted offline.

---

### Hardware Validation

- Tested on **AMD Kria KV260**
- Integrated using AXI DMA + PYNQ
- Validated real-time continuous streaming
- Validated dynamic modulation (e.g., using Python PS to drive the `TARGET_LEVEL` for an Auto-Tremolo effect)

Python is used only as a stimulus and observability layer. Bitstreams and PYNQ overlays are intentionally not included.

---

## Design Philosophy

This repository focuses on:

- **Predictability & Mathematical Stability**
- **Numerical safety (Q4.12 math)**
- **RTL clarity**
- **Streaming correctness**

It intentionally avoids:

- Legacy IIR filter instabilities
- Psychoacoustic smoothing (soft-knee)
- Feature-rich software-oriented abstractions

This is a **hardware-first dynamics building block**.

---

## What This Repository Is

- A clean **RTL reference implementation**
- A reusable building block for:
  - duckers / limiters
  - dynamic gain controllers
  - tremolo modulators
- A teaching-quality example of:
  - fixed-point DSP scaling
  - AXI-Stream integration
  - control/data plane separation

---

## What This Repository Is Not

- ❌ A proportional audio compressor (no complex ratio calculation)
- ❌ A software DSP library
- ❌ A drop-in plug-and-play audio product

The scope is intentionally narrow and reliable.

---

## Documentation

Additional documentation is available in `/docs`:

- `address_map.md`
- `build_overview.md`
- `design_rationale.md`
- `latency_and_data_format.md`
- `validation_notes.md`

---

## License

MIT License  
Provided as-is, without warranty.

---

> **This design demonstrates strict engineering decisions and fixed-point stability, not algorithmic ambition.**
