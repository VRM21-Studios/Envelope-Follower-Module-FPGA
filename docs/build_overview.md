# Build Overview

This module implements a **Linear Ramp Envelope Follower** intended for
real-time audio dynamics processing on FPGA.

The design is fully streaming, written in synthesizable Verilog, and
validated using standard testbenches. A reference AXI-based
integration is provided for Zynq/Zynq UltraScale+ platforms.

## Design Scope

- Continuous sample-by-sample processing
- Independent Attack and Release linear ramp generators
- No frame buffering
- Deterministic 1-cycle pipeline latency
- Suitable for inline audio datapath processing (directly outputs gain-adjusted audio)

## Module Variants

- `envelope_follower_core`  
  Pure DSP logic (no bus dependency; handles peak detection and ramp generation)

- `envelope_follower_axis`  
  AXI-Stream (Audio In/Out) + AXI-Lite (Control registers) wrapper for SoC integration

## Target Platform

- Verified on **Kria KV260**
- Clock domain: single synchronous clock
