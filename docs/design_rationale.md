# Design Rationale

The RMS / Peak envelope extractor is designed as a **pure streaming
hardware block**, avoiding feedback paths, control-heavy logic, or
time-varying state machines.

## Key Design Decisions

### 1. Streaming-Only Architecture
- One input sample produces one output sample
- No frame buffering
- No global control state

This guarantees predictable latency and simplifies verification.

### 2. Fixed-Point Arithmetic
- Fixed-point math is used throughout
- Bit growth is explicitly managed
- Saturation is preferred over wrap-around

This avoids non-deterministic behavior across synthesis tools.

### 3. Separation of Core and AXI Logic
- `*_core.v` implements DSP math only
- `*_axis.v` handles AXI-Stream and AXI-Lite

This separation allows the core to be reused in non-AXI environments.

### 4. No “Audio-Rate Control” Assumptions
- No LFOs
- No feedback smoothing
- No psychoacoustic tuning

The module is intentionally **boring but reliable**.
