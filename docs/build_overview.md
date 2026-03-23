# Build Overview

This module implements a **RMS / Peak envelope extractor** intended for
real-time audio signal analysis on FPGA.

The design is fully streaming, written in synthesizable Verilog, and
validated using SystemVerilog testbenches. A reference AXI-based
integration is provided for Zynq UltraScale+ platforms.

## Design Scope

- Continuous sample-by-sample processing
- No frame buffering
- Deterministic latency
- Suitable for control and analysis paths (not audio playback)

## Module Variants

- `rms_peak_core`  
  Pure DSP logic (no bus dependency)

- `rms_peak_axis`  
  AXI-Stream + AXI-Lite wrapper for SoC integration

## Target Platform

- Verified on **Kria KV260**
- Clock domain: single synchronous clock
