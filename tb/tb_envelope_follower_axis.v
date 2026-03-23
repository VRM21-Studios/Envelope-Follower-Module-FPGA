`timescale 1ns / 1ps

// ============================================================================
// Module      : tb_envelope_follower_axis
// Description : Testbench for the AXI4-Stream Envelope Follower Wrapper.
//               Verifies AXI-Lite configuration, AXI-Stream handshaking,
//               and the inline audio gain processing (Q4.12 format).
// ============================================================================
module tb_envelope_follower_axis;

    // ========================================================================
    // Parameters
    // ========================================================================
    parameter C_S_AXI_DATA_WIDTH = 32;
    parameter C_S_AXI_ADDR_WIDTH = 5;
    parameter GAIN_FBITS         = 12; // Q4.12 Format

    // ========================================================================
    // Signals
    // ========================================================================
    reg  aclk = 0;
    reg  aresetn = 0;

    // AXI-Stream 
    reg  [31:0] s_axis_tdata  = 0; 
    reg         s_axis_tvalid = 0;
    reg         s_axis_tlast  = 0;
    wire        s_axis_tready;
    wire [31:0] m_axis_tdata;
    wire        m_axis_tlast;
    wire        m_axis_tvalid;
    reg         m_axis_tready = 1;

    // AXI-Lite Write Channel
    reg  [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr = 0;
    reg                           s_axi_awvalid = 0;
    wire                          s_axi_awready;
    reg  [C_S_AXI_DATA_WIDTH-1:0] s_axi_wdata = 0;
    reg  [3:0]                    s_axi_wstrb = 0;
    reg                           s_axi_wvalid = 0;
    wire                          s_axi_wready;
    wire [1:0]                    s_axi_bresp;
    wire                          s_axi_bvalid;
    reg                           s_axi_bready = 0;
    
    // AXI-Lite Read Channel 
    reg  [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr  = 0;
    reg                           s_axi_arvalid = 0;
    wire                          s_axi_arready;
    wire [C_S_AXI_DATA_WIDTH-1:0] s_axi_rdata;
    wire [1:0]                    s_axi_rresp;
    wire                          s_axi_rvalid;
    reg                           s_axi_rready  = 0;

    // File Handler
    integer f_csv;
    integer sample_idx = 0;

    // Audio Generation Variables
    real PI = 3.14159265358979323846;
    real freq_audio = 0.05; 
    real val_audio;
    real amplitude_env;
    
    reg signed [15:0] audio_sample = 0;
    wire signed [15:0] out_l = m_axis_tdata[15:0];
    
    // Probe internal signal to monitor the envelope gain transition
    wire signed [15:0] probe_env_gain = u_dut.core_inst.current_gain;

    // ========================================================================
    // DUT Instantiation
    // ========================================================================
    envelope_follower_axis #(
        .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH),
        .GAIN_FBITS(GAIN_FBITS)
    ) u_dut (
        .aclk(aclk), .aresetn(aresetn),
        .s_axis_tdata(s_axis_tdata), .s_axis_tlast(s_axis_tlast),
        .s_axis_tvalid(s_axis_tvalid), .s_axis_tready(s_axis_tready),
        .m_axis_tdata(m_axis_tdata), .m_axis_tlast(m_axis_tlast),
        .m_axis_tvalid(m_axis_tvalid), .m_axis_tready(m_axis_tready),
        .s_axi_awaddr(s_axi_awaddr), .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata), .s_axi_wstrb(s_axi_wstrb), .s_axi_wvalid(s_axi_wvalid), .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp), .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr), .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata), .s_axi_rresp(s_axi_rresp), .s_axi_rvalid(s_axi_rvalid), .s_axi_rready(s_axi_rready)
    );

    // Clock generation (100MHz)
    always #5 aclk = ~aclk;

    // ========================================================================
    // Tasks
    // ========================================================================
    task axi_write;
        input [4:0] addr;
        input [31:0] data;
        begin
            @(posedge aclk);
            s_axi_awaddr  <= addr;
            s_axi_awvalid <= 1'b1;
            s_axi_wdata   <= data;
            s_axi_wvalid  <= 1'b1;
            s_axi_wstrb   <= 4'hf;
            s_axi_bready  <= 1'b1;
            wait(s_axi_awready && s_axi_wready);
            @(posedge aclk);
            s_axi_awvalid <= 1'b0;
            s_axi_wvalid  <= 1'b0;
            wait(s_axi_bvalid);
            @(posedge aclk);
            s_axi_bready <= 1'b0;
        end
    endtask

    // ========================================================================
    // Main Stimulus
    // ========================================================================
    initial begin
        f_csv = $fopen("tb_envelope_follower_axis.csv", "w");
        // Header includes the env_gain column for visualization
        $fwrite(f_csv, "sample,audio_in,audio_out,env_gain\n");

        aresetn = 0;
        #100;
        aresetn = 1;
        #20;

        // -------------------------------------------------------------
        // 1. CONFIGURATION (AXI-Lite)
        // -------------------------------------------------------------
        $display("Configuring Registers via AXI-Lite...");
        
        // 0x00: Enable = 1
        axi_write(5'h00, 32'd1); 
        
        // 0x04: Threshold = 5000 
        axi_write(5'h04, 32'd5000);
        
        // 0x08: Target Level = 0.5 ratio (2048 in Q4.12)
        // The target gain to reach when the signal exceeds the threshold
        axi_write(5'h08, 32'd2048);
        
        // 0x0C: Attack Rate = 2 Cycles per step
        axi_write(5'h0C, 32'd2);
        
        // 0x10: Release Rate = 4 Cycles per step 
        axi_write(5'h10, 32'd4);

        // -------------------------------------------------------------
        // 2. LOOP AUDIO SIMULATION
        // -------------------------------------------------------------
        $display("Starting Audio Stream...");
        
        // Simulate for 6000 samples
        for (sample_idx = 0; sample_idx < 6000; sample_idx = sample_idx + 1) begin
            
            // Volume Scenario:
            // Samples 0 - 2000: Quiet (Amplitude 3000) -> Below Threshold (5000). Gain = 1.0
            // Samples 2000 - 4000: Loud (Amplitude 15000) -> Exceeds Threshold. Envelope Attack active towards 0.5
            // Samples 4000 - 6000: Quiet again (Amplitude 3000) -> Envelope Release active back towards 1.0
            
            if (sample_idx >= 2000 && sample_idx < 4000) begin
                amplitude_env = 15000.0; // Loud sound
            end else begin
                amplitude_env = 3000.0;  // Quiet sound
            end

            // Generate Continuous Sine with dynamic envelope
            val_audio = $sin(2.0 * PI * freq_audio * sample_idx);
            audio_sample = val_audio * amplitude_env; 

            // Send Stream (32-bit packed: 16-bit Right, 16-bit Left)
            @(posedge aclk);
            s_axis_tdata  <= {audio_sample, audio_sample}; 
            s_axis_tvalid <= 1'b1;
            
            wait(s_axis_tready);
            
            // Output is delayed by 1 cycle (due to pipelining in the AXI wrapper)
            // Log to CSV when the output is valid.
            if (m_axis_tvalid) begin
                $fwrite(f_csv, "%0d,%0d,%0d,%0d\n", sample_idx, audio_sample, out_l, probe_env_gain);
            end

            @(posedge aclk);
            s_axis_tvalid <= 0;
        end

        $fclose(f_csv);
        $display("Simulation Complete. Data saved to tb_envelope_follower_axis.csv");
        $finish;
    end

endmodule
