# Design Rationale

The Linear Ramp Envelope Follower is designed as a **stable, streaming hardware block**. It specifically moves away from feedback-based IIR filters (leaky integrators) used in earlier iterations to eliminate fixed-point instability and limit-cycle artifacts.

## Key Design Decisions

### 1. Linear Ramp State Machine
- Replaces the legacy first-order IIR smoothing
- Uses strict counter-based increments/decrements for Attack and Release phases
- Eliminates mathematical instability and guarantees exact, predictable convergence to the target gain

### 2. Streaming-Only Architecture
- One input sample produces one output sample (or stereo pair)
- No frame buffering
- Deterministic 1-clock-cycle pipeline latency in the AXI wrapper

### 3. Fixed-Point Arithmetic
- Envelope gain and target levels are strictly represented in Q4.12 format
- Multiplication bit-growth is explicitly managed, shifted, and truncated safely
- Avoids non-deterministic behavior across different synthesis tools

### 4. Separation of Core and AXI Logic
- `*_core.v` implements the pure DSP math, peak detection, and envelope generation
- `*_axis.v` handles AXI-Stream (audio datapath), AXI-Lite (control registers), and applies the final audio multiplication

This separation allows the core envelope detector to be easily reused in non-AXI environments or custom audio pipelines.
