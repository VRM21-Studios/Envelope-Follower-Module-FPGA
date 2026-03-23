# Address Map

This document describes the AXI-Lite register map for the
`rms_peak_axis` module as used in the reference system.

## Base Address

| Module           | Base Address |
|------------------|-------------|
| AXI DMA (Lite)   | 0xA000_0000 |
| RMS / Peak Core  | 0xA001_0000 |

## Register Layout (rms_peak_axis)

| Offset | Name            | Access | Description |
|------:|-----------------|--------|-------------|
| 0x00  | CTRL            | R/W    | Enable, reset control |
| 0x04  | MODE            | R/W    | RMS / Peak select |
| 0x08  | WINDOW_LEN      | R/W    | Averaging window |
| 0x0C  | STATUS          | R      | Internal state flags |

> Note: Exact semantics are defined in the RTL comments.
> This map reflects the **validated integration**, not a generic IP spec.

## Notes

- Address alignment follows AXI-Lite requirements
- Register width is 32-bit
- No burst access is supported
