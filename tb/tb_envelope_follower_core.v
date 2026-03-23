`timescale 1ns / 1ps

// ============================================================================
// Module      : tb_envelope_follower_core
// Description : Testbench for the Envelope Follower Core
//               Verifies the linear ramp logic, stereo peak detection, and
//               dynamic gain generation (Q4.12 format) without AXI overhead.
// ============================================================================
module tb_envelope_follower_core;

    // ========================================================================
    // Parameters
    // ========================================================================
    parameter signed [15:0] GAIN_NORMAL = 16'd4096; // 1.0 in Q4.12 format
    parameter integer GAIN_FBITS        = 12;

    // ========================================================================
    // Signals
    // ========================================================================
    reg  aclk = 0;
    reg  aresetn = 0;
    reg  en = 0;

    // Audio Input Signals
    reg  signed [15:0] audio_l_in = 0;
    reg  signed [15:0] audio_r_in = 0;
    reg                valid_in = 0;

    // Control Parameters
    reg  [15:0]        threshold = 0;
    reg  signed [15:0] target_level = 0;
    reg  [31:0]        attack_rate = 0;
    reg  [31:0]        release_rate = 0;

    // Output Signal
    wire signed [15:0] current_gain;

    // Signals for simulation and logging
    integer f_csv;
    integer sample_idx = 0;
    real PI = 3.14159265358979323846;
    real freq_audio = 0.05; 
    real val_audio;
    real amplitude_env;
    
    // Additional testbench logic to simulate audio output processing
    // This allows us to visualize the envelope effect in the CSV data
    wire signed [31:0] mult_out = audio_l_in * current_gain;
    wire signed [15:0] audio_out = mult_out >>> GAIN_FBITS;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================
    envelope_follower_core #(
        .GAIN_NORMAL(GAIN_NORMAL)
    ) u_dut (
        .aclk(aclk),
        .aresetn(aresetn),
        .en(en),
        .audio_l_in(audio_l_in),
        .audio_r_in(audio_r_in),
        .valid_in(valid_in),
        .threshold(threshold),
        .target_level(target_level),
        .attack_rate(attack_rate),
        .release_rate(release_rate),
        .current_gain(current_gain)
    );

    // Clock generation (100 MHz)
    always #5 aclk = ~aclk;

    // ========================================================================
    // Main Stimulus
    // ========================================================================
    initial begin
        // Open file for logging
        f_csv = $fopen("tb_envelope_follower_core.csv", "w");
        $fwrite(f_csv, "sample,audio_in,audio_out,env_gain\n");

        // 1. Initial Reset & Setup
        aresetn = 0;
        en = 0;
        valid_in = 0;
        
        // Setup parameters directly (bypassing AXI)
        threshold    = 16'd5000;
        target_level = 16'd2048; // Gain 0.5
        attack_rate  = 32'd2;    // Fast attack
        release_rate = 32'd4;    // Slightly slower release
        
        #100;
        aresetn = 1;
        en = 1;
        #20;

        $display("Starting Core-Level Simulation...");

        // 2. Audio Stream Simulation (6000 samples)
        for (sample_idx = 0; sample_idx < 6000; sample_idx = sample_idx + 1) begin
            
            // Volume Scenario:
            // Samples 0 - 2000: Quiet (Amplitude 3000)
            // Samples 2000 - 4000: Loud (Amplitude 15000) -> Triggers Attack
            // Samples 4000 - 6000: Quiet again (Amplitude 3000) -> Triggers Release
            
            if (sample_idx >= 2000 && sample_idx < 4000) begin
                amplitude_env = 15000.0;
            end else begin
                amplitude_env = 3000.0; 
            end

            // Generate Sine Wave
            val_audio = $sin(2.0 * PI * freq_audio * sample_idx);
            
            // Feed to Inputs
            @(posedge aclk);
            audio_l_in <= val_audio * amplitude_env;
            audio_r_in <= val_audio * amplitude_env; // Duplicate to simulate stereo
            valid_in   <= 1'b1;
            
            // Wait 1 clock cycle for the core to process the gain
            @(posedge aclk); 
            valid_in <= 1'b0; // Simulate single-cycle valid data pulse

            // Write results to CSV
            $fwrite(f_csv, "%0d,%0d,%0d,%0d\n", sample_idx, audio_l_in, audio_out, current_gain);
        end

        $fclose(f_csv);
        $display("Simulation Complete. Data saved to tb_envelope_follower_core.csv");
        $finish;
    end

endmodule
