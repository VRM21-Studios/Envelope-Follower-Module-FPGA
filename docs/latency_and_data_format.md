# Latency and Data Format

## Data Format

- Input: signed fixed-point audio samples
- Output: unsigned envelope magnitude
- Fixed-point scaling is consistent across modes

Typical configuration:
- Input: Q1.15
- Output: widened fixed-point to preserve precision

## Latency

The module has a **fixed pipeline latency**.

| Stage               | Cycles |
|---------------------|--------|
| Input register      | 1 |
| DSP pipeline        | N |
| Output register     | 1 |

Total latency = **N + 2 cycles**

## Timing Characteristics

- No data-dependent delay
- No warm-up period after reset
- Continuous valid output after pipeline fill
