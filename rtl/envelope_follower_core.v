`timescale 1ns / 1ps

// ============================================================================
// Module      : envelope_follower_core
// Description : Stereo-Linked Linear Ramp Envelope Follower
//               Generates a stable Q4.12 gain envelope based on input amplitude.
//               Uses a counter-based linear ramp to avoid IIR limit cycles.
// ============================================================================
module envelope_follower_core #(
    parameter signed [15:0] GAIN_NORMAL = 16'd4096 // 1.0 in Q4.12 format
)(
    // System Signals
    input  wire               aclk,
    input  wire               aresetn,
    input  wire               en,              // 1: Enable processing, 0: Hold state

    // Audio Input (Stereo)
    input  wire signed [15:0] audio_l_in,      // Left channel audio
    input  wire signed [15:0] audio_r_in,      // Right channel audio
    input  wire               valid_in,        // High when input data is valid

    // Control Parameters
    input  wire [15:0]        threshold,       // Amplitude limit to trigger attack
    input  wire signed [15:0] target_level,    // Target gain when threshold is breached (Q4.12)
    input  wire [31:0]        attack_rate,     // Clock cycles per 1-LSB gain decrement
    input  wire [31:0]        release_rate,    // Clock cycles per 1-LSB gain increment

    // Output
    output reg  signed [15:0] current_gain     // Current envelope gain (Q4.12)
);

    // =========================================================================
    // 1. RECTIFIER & STEREO-LINKED PEAK DETECTION
    // =========================================================================
    // Convert to absolute values and take the maximum of Left and Right channels
    // to ensure the stereo image remains balanced during gain reduction.
    wire [15:0] abs_audio_l = (audio_l_in[15]) ? -audio_l_in : audio_l_in;
    wire [15:0] abs_audio_r = (audio_r_in[15]) ? -audio_r_in : audio_r_in;
    wire [15:0] max_audio   = (abs_audio_l > abs_audio_r) ? abs_audio_l : abs_audio_r;

    // =========================================================================
    // 2. THRESHOLD COMPARATOR
    // =========================================================================
    // Determine the target destination for the linear ramp.
    wire is_loud = (max_audio > threshold);
    wire signed [15:0] target_gain = is_loud ? target_level : GAIN_NORMAL;

    // =========================================================================
    // 3. LINEAR RAMP STATE MACHINE
    // =========================================================================
    reg [31:0] timer_count; 

    always @(posedge aclk) begin
        if (!aresetn) begin
            current_gain <= GAIN_NORMAL;
            timer_count  <= 0;
        end else if (en && valid_in) begin
            
            if (current_gain > target_gain) begin
                // Attack Phase: Linearly decrease gain towards target_level
                if (timer_count >= attack_rate) begin
                    current_gain <= current_gain - 1;
                    timer_count  <= 0;
                end else begin
                    timer_count  <= timer_count + 1;
                end
                
            end else if (current_gain < target_gain) begin
                // Release Phase: Linearly increase gain towards GAIN_NORMAL
                if (timer_count >= release_rate) begin
                    current_gain <= current_gain + 1;
                    timer_count  <= 0;
                end else begin
                    timer_count  <= timer_count + 1;
                end
                
            end else begin
                // Steady State: Target reached, hold current_gain
                timer_count <= 0;
            end
            
        end
    end

endmodule
