`timescale 1ns / 1ps

// ============================================================================
// Module      : envelope_follower_axis
// Description : AXI4 Wrapper for Linear Ramp Envelope Follower
//               - AXI4-Lite: 5 Control Registers for dynamic modulation
//               - AXI4-Stream: 32-bit packed stereo audio datapath
//               - Inline DSP: Applies Q4.12 envelope gain directly to audio
//               - Latency: 1 clock cycle (pipelined output)
// ============================================================================
module envelope_follower_axis #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 5,
    parameter integer GAIN_FBITS         = 12  // Fractional bits for Q4.12 format
)(
    // Global Clock & Reset
    input  wire aclk,
    input  wire aresetn,

    // AXI4-Stream Slave (Stereo Audio Input)
    input  wire [31:0] s_axis_tdata, 
    input  wire        s_axis_tlast,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,

    // AXI4-Stream Master (Stereo Audio Output with applied gain)
    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tlast,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,

    // AXI4-Lite Slave (Control Registers)
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input  wire                          s_axi_awvalid,
    output reg                           s_axi_awready,
    input  wire [C_S_AXI_DATA_WIDTH-1:0] s_axi_wdata,
    input  wire [3:0]                    s_axi_wstrb,
    input  wire                          s_axi_wvalid,
    output reg                           s_axi_wready,
    output reg  [1:0]                    s_axi_bresp,
    output reg                           s_axi_bvalid,
    input  wire                          s_axi_bready,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    input  wire                          s_axi_arvalid,
    output reg                           s_axi_arready,
    output reg  [C_S_AXI_DATA_WIDTH-1:0] s_axi_rdata,
    output reg  [1:0]                    s_axi_rresp,
    output reg                           s_axi_rvalid,
    input  wire                          s_axi_rready
);

    // =========================================================================
    // 1. AXI-LITE CONTROL REGISTERS
    // =========================================================================
    reg [31:0] reg_control;      // 0x00: Bit[0] = Enable (1: Active, 0: Bypass)
    reg [31:0] reg_threshold;    // 0x04: Amplitude limit to trigger the envelope
    reg [31:0] reg_target_level; // 0x08: Target gain when breached (Q4.12 Format)
    reg [31:0] reg_attack_rate;  // 0x0C: Cycles per 1-LSB envelope decrement
    reg [31:0] reg_release_rate; // 0x10: Cycles per 1-LSB envelope increment

    wire [2:0] addr_w = s_axi_awaddr[4:2];
    wire [2:0] addr_r = s_axi_araddr[4:2];

    always @(posedge aclk) begin
        if (!aresetn) begin
            s_axi_awready <= 0; s_axi_wready <= 0; s_axi_bvalid <= 0; s_axi_bresp <= 0;
            
            // Default Values for safe startup
            reg_control      <= 32'd1;
            reg_threshold    <= 32'd4000;
            reg_target_level <= 32'd2048;   // Default: 0.5 gain in Q4.12
            reg_attack_rate  <= 32'd6100;
            reg_release_rate <= 32'd15200;
        end else begin
            // Write Operations
            if (!s_axi_awready && s_axi_awvalid && s_axi_wvalid) begin
                s_axi_awready <= 1; s_axi_wready <= 1;
                case (addr_w)
                    3'h0: reg_control      <= s_axi_wdata;
                    3'h1: reg_threshold    <= s_axi_wdata;
                    3'h2: reg_target_level <= s_axi_wdata;
                    3'h3: reg_attack_rate  <= s_axi_wdata;
                    3'h4: reg_release_rate <= s_axi_wdata;
                    default: ;
                endcase
            end else begin
                s_axi_awready <= 0; s_axi_wready <= 0;
            end

            // Write Response
            if (s_axi_awready && !s_axi_bvalid) begin
                s_axi_bvalid <= 1; s_axi_bresp <= 0;
            end else if (s_axi_bready) begin
                s_axi_bvalid <= 0;
            end
        end
    end

    // Read Operations
    always @(posedge aclk) begin
        if (!aresetn) begin
            s_axi_arready <= 0; s_axi_rvalid <= 0; s_axi_rdata <= 0; s_axi_rresp <= 0;
        end else begin
            if (!s_axi_arready && s_axi_arvalid) begin
                s_axi_arready <= 1; s_axi_rvalid <= 1;
                case (addr_r)
                    3'h0: s_axi_rdata <= reg_control;
                    3'h1: s_axi_rdata <= reg_threshold;
                    3'h2: s_axi_rdata <= reg_target_level;
                    3'h3: s_axi_rdata <= reg_attack_rate;
                    3'h4: s_axi_rdata <= reg_release_rate;
                    default: s_axi_rdata <= 0;
                endcase
            end else begin
                s_axi_arready <= 0;
                if (s_axi_rvalid && s_axi_rready) s_axi_rvalid <= 0;
            end
        end
    end

    // =========================================================================
    // 2. CORE INSTANTIATION & AXI-STREAM HANDSHAKE
    // =========================================================================
    // Manage backpressure seamlessly
    wire stream_ready = m_axis_tready;
    assign s_axis_tready = stream_ready;

    // Unpack 32-bit stereo AXI-Stream into separate 16-bit channels
    wire signed [15:0] audio_l_in = s_axis_tdata[15:0];
    wire signed [15:0] audio_r_in = s_axis_tdata[31:16];
    
    wire signed [15:0] env_gain;
    wire core_valid_in = s_axis_tvalid && stream_ready;

    // Instantiate the pure DSP logic core
    envelope_follower_core core_inst (
        .aclk(aclk),
        .aresetn(aresetn),
        .en(reg_control[0]),
        .audio_l_in(audio_l_in),
        .audio_r_in(audio_r_in),
        .valid_in(core_valid_in),
        .threshold(reg_threshold[15:0]),
        .target_level(reg_target_level[15:0]),
        .attack_rate(reg_attack_rate),
        .release_rate(reg_release_rate),
        .current_gain(env_gain)
    );

    // =========================================================================
    // 3. APPLY GAIN TO AUDIO (Q4.12 Fixed-Point Math)
    // =========================================================================
    // Multiply incoming audio by the Q4.12 envelope gain.
    // This results in a 32-bit intermediate value.
    wire signed [31:0] mult_l = audio_l_in * env_gain;
    wire signed [31:0] mult_r = audio_r_in * env_gain;
    
    // Perform arithmetic right shift to remove the fractional bits, 
    // effectively truncating the 32-bit value back to 16-bit audio.
    wire signed [15:0] audio_l_out = mult_l >>> GAIN_FBITS;
    wire signed [15:0] audio_r_out = mult_r >>> GAIN_FBITS;

    // =========================================================================
    // 4. PIPELINED OUTPUT REGISTER (1 Clock Cycle Latency)
    // =========================================================================
    reg [31:0] out_tdata;
    reg        out_tlast;
    reg        out_tvalid;

    always @(posedge aclk) begin
        if (!aresetn) begin
            out_tdata  <= 0;
            out_tlast  <= 0;
            out_tvalid <= 0;
        end else if (stream_ready) begin
            // Pack the gain-adjusted audio back into a 32-bit AXI-Stream format
            out_tdata  <= {audio_r_out, audio_l_out};
            out_tlast  <= s_axis_tlast;
            out_tvalid <= s_axis_tvalid;
        end
    end

    assign m_axis_tdata  = out_tdata;
    assign m_axis_tlast  = out_tlast;
    assign m_axis_tvalid = out_tvalid;

endmodule
