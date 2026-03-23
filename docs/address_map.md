# Address Map

This document describes the AXI-Lite register map for the
`envelope_follower_axis` module as used in the reference system.

## Base Address

| Module                   | Base Address |
|--------------------------|-------------|
| AXI DMA (Lite)           | 0xA000_0000 |
| Envelope Follower Core   | 0xA001_0000 |

## Register Layout (envelope_follower_axis)

| Offset | Name            | Access | Description |
|------:|-----------------|--------|-------------|
| 0x00  | CTRL            | R/W    | Core control (Bit[0]: 1 = Enable, 0 = Bypass) |
| 0x04  | THRESHOLD       | R/W    | Amplitude threshold limit for triggering the envelope |
| 0x08  | TARGET_LEVEL    | R/W    | Target gain applied when threshold is exceeded (Q4.12 Format) |
| 0x0C  | ATTACK_RATE     | R/W    | Attack speed (timer limit in clock cycles per step down) |
| 0x10  | RELEASE_RATE    | R/W    | Release speed (timer limit in clock cycles per step up) |

> Note: Exact semantics and fixed-point formatting are defined in the RTL comments.
> This map reflects the **validated integration** for the Linear Ramp architecture.

## Notes

- Address alignment follows AXI-Lite requirements
- Register width is 32-bit
- No burst access is supported
- `TARGET_LEVEL` expects a fixed-point Q4.12 value (e.g., 4096 = 1.0)
