# RMS / Peak Envelope Detector (AXI-Stream) on FPGA

This repository provides a **reference RTL implementation** of a
**real-time RMS / Peak envelope detector**
implemented in **Verilog**, integrated with **AXI-Stream** and **AXI-Lite**.

Target platform: **AMD Kria KV260**  
Focus: **deterministic RTL DSP design, fixed-point behavior, and AXI correctness**

This module is intended for **continuous real-time audio streaming**,  
not block-based or windowed signal processing.

---

## Overview

This design implements:

- **Function**: Envelope follower (peak-style, leaky integrator)
- **Purpose**: Level detection for dynamics control (ducking, gating, metering)
- **Data type**: Fixed-point arithmetic
- **Scope**: Minimal, single-purpose DSP building block

Despite the name, the implementation is **not a windowed RMS calculator**.  
It behaves as a **hardware-friendly envelope detector**, suitable for FPGA pipelines.

---

## Key Characteristics

- RTL written in **Verilog**
- **AXI-Stream** stereo audio interface
- **AXI-Lite** runtime control
- Fully synchronous, cycle-accurate design
- Deterministic latency
- Safe fixed-point arithmetic (no wraparound)
- Designed for **real-time streaming DSP**
- No software runtime included

---

## Architecture

High-level structure:

```
AXI-Stream In (Stereo)
|
v
+---------------------------+
| RMS / Peak Core         |
| - Abs rectifier         |
| - Leaky integrator      |
| - Bypass path (aligned) |
+---------------------------+
|
v
AXI-Stream Out (Stereo)
```


Design notes:

- Each channel uses an **independent core**
- No shared state between Left / Right
- Control plane is fully separated from data plane
- No hidden buffering or block processing

---

## Data Format

### AXI-Stream

- Data width: **32-bit**
- Stereo layout:
  - `[15:0]`   → Left
  - `[31:16]`  → Right
- Samples are signed **16-bit PCM**

### Envelope Output

- Unsigned magnitude (post-rectification)
- Same width as input audio
- Time-aligned with fixed latency

---

## Latency

| Stage | Cycles |
|----|----|
| Absolute value | 1 |
| Envelope accumulator | 1 |
| Output register | 1 |
| **Total** | **3 cycles (fixed)** |

Latency is:

- deterministic
- independent of input signal
- independent of `alpha`
- independent of bypass

---

## Control Interface (AXI-Lite)

| Offset | Register | Description |
|----:|----|----|
| 0x00 | CONTROL | Bit 0: Enable, Bit 1: Bypass |
| 0x04 | ALPHA | Envelope smoothing coefficient |

### Alpha

- Format: **Q0.16**
- Larger value → faster response
- Smaller value → smoother envelope

Alpha can be updated **during active streaming**.

---

## Verification & Validation

### RTL Simulation

Simulation verifies:

- Rectifier correctness
- Envelope behavior (attack / release)
- Runtime alpha updates
- Bypass correctness
- AXI-Stream handshake behavior
- Stereo independence

Results are logged as CSV and plotted offline.

See `/results/README.md` for waveform interpretation.

---

### Hardware Validation

- Tested on **AMD Kria KV260**
- Integrated using AXI DMA + PYNQ
- Python used only as stimulus and observability layer

Bitstreams and PYNQ overlays are intentionally not included.

---

## Design Philosophy

This repository focuses on:

- **Predictability**
- **Numerical safety**
- **RTL clarity**
- **Streaming correctness**

It intentionally avoids:

- Windowed RMS logic
- Psychoacoustic smoothing
- Feature-rich control
- Software-oriented abstractions

This is a **hardware-first envelope detector**.

---

## What This Repository Is

- A clean **RTL reference implementation**
- A reusable building block for:
  - ducking
  - compressors
  - gates
  - envelope followers
- A teaching-quality example of:
  - fixed-point DSP
  - AXI-Stream integration
  - control/data plane separation

---

## What This Repository Is Not

- ❌ A full dynamics processor
- ❌ A software DSP library
- ❌ A drop-in audio product
- ❌ A perceptually tuned RMS meter

The scope is intentionally narrow.

---

## Documentation

Additional documentation is available in `/docs`:

- `address_map.md`
- `build_overview.md`
- `design_rationale.md`
- `latency_and_data_format.md`
- `validation_notes.md`

---

## Project Status

This repository is **complete and stable**.

- RTL frozen
- Simulation complete
- Hardware validated
- No further feature development planned

Published as a **reference design**.

---

## License

MIT License  
Provided as-is, without warranty.

---

> **This design demonstrates engineering decisions, not algorithmic ambition.**

Design notes:

- Each channel uses an **independent core**
- No shared state between Left / Right
- Control plane is fully separated from data plane
- No hidden buffering or block processing

---

## Data Format

### AXI-Stream

- Data width: **32-bit**
- Stereo layout:
  - `[15:0]`   → Left
  - `[31:16]`  → Right
- Samples are signed **16-bit PCM**

### Envelope Output

- Unsigned magnitude (post-rectification)
- Same width as input audio
- Time-aligned with fixed latency

---

## Latency

| Stage | Cycles |
|----|----|
| Absolute value | 1 |
| Envelope accumulator | 1 |
| Output register | 1 |
| **Total** | **3 cycles (fixed)** |

Latency is:

- deterministic
- independent of input signal
- independent of `alpha`
- independent of bypass

---

## Control Interface (AXI-Lite)

| Offset | Register | Description |
|----:|----|----|
| 0x00 | CONTROL | Bit 0: Enable, Bit 1: Bypass |
| 0x04 | ALPHA | Envelope smoothing coefficient |

### Alpha

- Format: **Q0.16**
- Larger value → faster response
- Smaller value → smoother envelope

Alpha can be updated **during active streaming**.

---

## Verification & Validation

### RTL Simulation

Simulation verifies:

- Rectifier correctness
- Envelope behavior (attack / release)
- Runtime alpha updates
- Bypass correctness
- AXI-Stream handshake behavior
- Stereo independence

Results are logged as CSV and plotted offline.

See `/results/README.md` for waveform interpretation.

---

### Hardware Validation

- Tested on **AMD Kria KV260**
- Integrated using AXI DMA + PYNQ
- Python used only as stimulus and observability layer

Bitstreams and PYNQ overlays are intentionally not included.

---

## Design Philosophy

This repository focuses on:

- **Predictability**
- **Numerical safety**
- **RTL clarity**
- **Streaming correctness**

It intentionally avoids:

- Windowed RMS logic
- Psychoacoustic smoothing
- Feature-rich control
- Software-oriented abstractions

This is a **hardware-first envelope detector**.

---

## What This Repository Is

- A clean **RTL reference implementation**
- A reusable building block for:
  - ducking
  - compressors
  - gates
  - envelope followers
- A teaching-quality example of:
  - fixed-point DSP
  - AXI-Stream integration
  - control/data plane separation

---

## What This Repository Is Not

- ❌ A full dynamics processor
- ❌ A software DSP library
- ❌ A drop-in audio product
- ❌ A perceptually tuned RMS meter

The scope is intentionally narrow.

---

## Documentation

Additional documentation is available in `/docs`:

- `address_map.md`
- `build_overview.md`
- `design_rationale.md`
- `latency_and_data_format.md`
- `validation_notes.md`

---

## Project Status

This repository is **complete and stable**.

- RTL frozen
- Simulation complete
- Hardware validated
- No further feature development planned

Published as a **reference design**.

---

## License

MIT License  
Provided as-is, without warranty.

---

> **This design demonstrates engineering decisions, not algorithmic ambition.**
