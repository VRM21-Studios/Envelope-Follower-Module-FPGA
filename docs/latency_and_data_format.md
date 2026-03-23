# Latency and Data Format

## Data Format

- **Audio Input/Output**: 16-bit signed fixed-point (Stereo, packed into 32-bit AXI-Stream).
- **Control Registers**: 32-bit AXI-Lite.
- **Internal Gain/Envelope**: 16-bit signed fixed-point in **Q4.12** format (e.g., `4096` = `1.0`, `2048` = `0.5`).

Fixed-point math is heavily utilized. The 16-bit audio is multiplied by the 16-bit Q4.12 envelope gain, resulting in a 32-bit intermediate product that is safely arithmetic-shifted (`>>> 12`) and truncated back to 16-bit for the output.

## Latency

The module maintains a highly optimized, **fixed pipeline latency** to ensure phase alignment and real-time safety.

| Stage                                  | Cycles |
|----------------------------------------|--------|
| Envelope Calculation (Core)            | 0 (Combinatorial for current sample) |
| Gain Application (Multiplier)          | 0 (Combinatorial) |
| Output Register (`m_axis_tdata`)       | 1 |

Total audio datapath latency = **1 clock cycle**

> **Note:** The internal `current_gain` updates its state 1 cycle after the threshold is breached, but the audio passing through the datapath only suffers a strict 1-cycle delay due to the output register.

## Timing Characteristics

- No data-dependent delay
- No warm-up period after reset
- Continuous valid output after pipeline fill
- 100% stable throughput (processes 1 stereo sample per clock cycle when `tready` is high)
