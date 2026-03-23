`timescale 1 ns / 1 ps

// ============================================================================
// RMS / Peak Envelope Core
// ----------------------------------------------------------------------------
// Computes a rectified and smoothed envelope using a leaky integrator.
// - Absolute-value rectification
// - First-order IIR smoothing (leaky integrator)
// - Optional bypass with matched latency
//
// Notes:
// - Fixed-point arithmetic only
// - Alpha is expressed in Q0.16 format
// - Designed for real-time streaming DSP
// ============================================================================

module rms_peak_core #(
    parameter integer DATA_W  = 16,
    parameter integer ALPHA_W = 16   // Alpha format: Q0.16
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 en,
    input  wire                 bypass,

    input  wire [ALPHA_W-1:0]   alpha, 
    input  wire signed [DATA_W-1:0] din,
    output reg  [DATA_W-1:0]    dout
);

    // ========================================================================
    // CONSTANTS
    // ========================================================================
    // Minimum and maximum representable signed values
    localparam signed [DATA_W-1:0] MIN_INT = {1'b1, {(DATA_W-1){1'b0}}};
    localparam signed [DATA_W-1:0] MAX_INT = {1'b0, {(DATA_W-1){1'b1}}};

    // ========================================================================
    // STAGE 1: ABSOLUTE VALUE (RECTIFIER)
    // ========================================================================
    // Converts signed input to magnitude.
    // Special handling for MIN_INT avoids overflow on negation.
    reg signed [DATA_W-1:0] abs_val;

    always @(posedge clk) begin
        if (!rst_n) begin
            abs_val <= 0;
        end else if (en) begin
            if (din == MIN_INT)
                abs_val <= MAX_INT;
            else
                abs_val <= (din < 0) ? -din : din;
        end
    end

    // ========================================================================
    // STAGE 2: LEAKY INTEGRATOR (ENVELOPE FOLLOWER)
    // ========================================================================
    // Implements:
    //   env[n+1] = env[n] + alpha * (abs(x[n]) - env[n])
    //
    // Fixed-point scaling:
    // - env_acc keeps full precision
    // - alpha is Q0.16
    reg signed [DATA_W+ALPHA_W-1:0] env_acc;

    wire signed [DATA_W-1:0]       current_env;
    wire signed [DATA_W:0]         diff;
    wire signed [DATA_W+ALPHA_W:0] prod;
    wire signed [DATA_W+ALPHA_W:0] next_acc_calc;

    // Extract current envelope (truncate fractional bits)
    assign current_env = env_acc[DATA_W+ALPHA_W-1 : ALPHA_W];

    // Difference between input magnitude and current envelope
    assign diff = abs_val - current_env;

    // Scaled correction term
    assign prod = diff * $signed({1'b0, alpha});

    // Accumulator update
    assign next_acc_calc = env_acc + prod;

    always @(posedge clk) begin
        if (!rst_n) begin
            env_acc <= 0;
        end else if (en) begin
            // Underflow protection (envelope cannot go negative)
            if (next_acc_calc < 0)
                env_acc <= 0;
            else
                env_acc <= next_acc_calc[DATA_W+ALPHA_W-1:0];
        end
    end

    // ========================================================================
    // STAGE 2B: BYPASS PATH (LATENCY MATCHING)
    // ========================================================================
    // The envelope output becomes valid one cycle after abs_val.
    // To keep bypass output time-aligned, abs_val is delayed by 1 cycle.
    reg [DATA_W-1:0] abs_val_d1;

    always @(posedge clk) begin
        if (!rst_n)
            abs_val_d1 <= 0;
        else if (en)
            abs_val_d1 <= $unsigned(abs_val);
    end

    // ========================================================================
    // STAGE 3: OUTPUT SELECTION
    // ========================================================================
    // Total latency:
    //   din -> abs -> env/bypass align -> dout = 3 cycles
    always @(posedge clk) begin
        if (!rst_n) begin
            dout <= 0;
        end else if (en) begin
            if (bypass)
                dout <= abs_val_d1;          // Raw rectified magnitude
            else
                dout <= $unsigned(current_env); // Smoothed envelope
        end
    end

endmodule
