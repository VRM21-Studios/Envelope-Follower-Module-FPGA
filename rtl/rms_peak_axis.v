`timescale 1 ns / 1 ps

// ============================================================================
// RMS / Peak Envelope (AXI-Stream Wrapper)
// ----------------------------------------------------------------------------
// AXI-integrated stereo envelope follower based on rms_peak_core.
// - AXI4-Stream for audio data
// - AXI4-Lite for control (enable, bypass, alpha)
// - Explicit latency alignment between data and control signals
//
// Notes:
// - Core latency is fixed and parameterized
// - Backpressure-aware: core pauses cleanly when downstream stalls
// - Designed for real-time streaming DSP pipelines
// ============================================================================

module rms_peak_axis #(
    // AXI-Lite Parameters
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 4,

    // Audio / DSP Parameters
    parameter integer AUDIO_WIDTH        = 16,
    parameter integer ALPHA_WIDTH        = 16,

    // Core latency (cycles)
    // rms_peak_core total latency = 3 cycles
    parameter integer CORE_LATENCY       = 3 
)(
    // ------------------------------------------------------------------------
    // Global Clock & Reset
    // ------------------------------------------------------------------------
    input  wire aclk,
    input  wire aresetn,

    // ------------------------------------------------------------------------
    // AXI4-Stream Slave (Input Audio)
    // ------------------------------------------------------------------------
    input  wire [31:0] s_axis_tdata,
    input  wire        s_axis_tlast,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,

    // ------------------------------------------------------------------------
    // AXI4-Stream Master (Output Audio)
    // ------------------------------------------------------------------------
    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tlast,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,

    // ------------------------------------------------------------------------
    // AXI4-Lite Slave (Control)
    // ------------------------------------------------------------------------
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input  wire                          s_axi_awvalid,
    output wire                          s_axi_awready,
    input  wire [C_S_AXI_DATA_WIDTH-1:0] s_axi_wdata,
    input  wire [3:0]                    s_axi_wstrb,
    input  wire                          s_axi_wvalid,
    output wire                          s_axi_wready,
    output wire [1:0]                    s_axi_bresp,
    output wire                          s_axi_bvalid,
    input  wire                          s_axi_bready,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    input  wire                          s_axi_arvalid,
    output wire                          s_axi_arready,
    output wire [C_S_AXI_DATA_WIDTH-1:0] s_axi_rdata,
    output wire [1:0]                    s_axi_rresp,
    output wire                          s_axi_rvalid,
    input  wire                          s_axi_rready
);

    // =========================================================================
    // 1. AXI-LITE CONTROL REGISTERS
    // =========================================================================
    // 0x00 : CTRL
    //        Bit 0 = Global Enable
    //        Bit 1 = Bypass
    //
    // 0x04 : ALPHA
    //        Envelope smoothing coefficient (Q0.16)
    reg [31:0] reg_ctrl;
    reg [31:0] reg_alpha;

    // Internal AXI-Lite handshake signals
    reg        axi_awready, axi_wready, axi_bvalid;
    reg        axi_arready, axi_rvalid;
    reg [31:0] axi_rdata;

    // AXI-Lite outputs
    assign s_axi_awready = axi_awready;
    assign s_axi_wready  = axi_wready;
    assign s_axi_bvalid  = axi_bvalid;
    assign s_axi_bresp   = 2'b00; // OKAY
    assign s_axi_arready = axi_arready;
    assign s_axi_rvalid  = axi_rvalid;
    assign s_axi_rresp   = 2'b00; // OKAY
    assign s_axi_rdata   = axi_rdata;

    // ------------------------------------------------------------------------
    // AXI-Lite Write Channel
    // ------------------------------------------------------------------------
    always @(posedge aclk) begin
        if (!aresetn) begin
            axi_awready <= 1'b0;
            axi_wready  <= 1'b0;
            axi_bvalid  <= 1'b0;

            // Default register values
            reg_ctrl  <= 32'h0000_0001; // Enabled, not bypassed
            reg_alpha <= 32'h0000_0800; // Small default alpha
        end else begin
            // Address & data handshake
            if (!axi_awready && s_axi_awvalid && s_axi_wvalid) begin
                axi_awready <= 1'b1;
                axi_wready  <= 1'b1;
            end else begin
                axi_awready <= 1'b0;
                axi_wready  <= 1'b0;
            end

            // Register write
            if (axi_awready && axi_wready) begin
                case (s_axi_awaddr[3:2])
                    2'h0: reg_ctrl  <= s_axi_wdata;
                    2'h1: reg_alpha <= s_axi_wdata;
                endcase
            end

            // Write response
            if (axi_awready && axi_wready)
                axi_bvalid <= 1'b1;
            else if (s_axi_bready)
                axi_bvalid <= 1'b0;
        end
    end

    // ------------------------------------------------------------------------
    // AXI-Lite Read Channel
    // ------------------------------------------------------------------------
    always @(posedge aclk) begin
        if (!aresetn) begin
            axi_arready <= 1'b0;
            axi_rvalid  <= 1'b0;
            axi_rdata   <= 32'b0;
        end else begin
            // Address handshake
            if (!axi_arready && s_axi_arvalid)
                axi_arready <= 1'b1;
            else
                axi_arready <= 1'b0;

            // Read data
            if (axi_arready && !axi_rvalid) begin
                axi_rvalid <= 1'b1;
                case (s_axi_araddr[3:2])
                    2'h0: axi_rdata <= reg_ctrl;
                    2'h1: axi_rdata <= reg_alpha;
                    default: axi_rdata <= 32'b0;
                endcase
            end else if (s_axi_rready) begin
                axi_rvalid <= 1'b0;
            end
        end
    end

    // =========================================================================
    // 2. CORE LOGIC & PIPELINING
    // =========================================================================
    
    // Control signals
    wire        global_en   = reg_ctrl[0];
    wire        core_bypass = reg_ctrl[1];
    wire [15:0] alpha_val  = reg_alpha[15:0];

    // Valid / TLAST pipelines (latency alignment)
    reg [CORE_LATENCY-1:0] valid_pipe;
    reg [CORE_LATENCY-1:0] last_pipe;

    // Core enable condition:
    // - input valid
    // - downstream ready
    // - core globally enabled
    wire core_ce = s_axis_tvalid && m_axis_tready && global_en;

    // Stereo split
    wire signed [15:0] in_l = s_axis_tdata[15:0];
    wire signed [15:0] in_r = s_axis_tdata[31:16];
    wire [15:0]        out_l, out_r;

    // ------------------------------------------------------------------------
    // RMS / Peak Envelope Cores
    // ------------------------------------------------------------------------
    rms_peak_core #(
        .DATA_W (AUDIO_WIDTH),
        .ALPHA_W(ALPHA_WIDTH)
    ) u_rms_l (
        .clk    (aclk),
        .rst_n  (aresetn),
        .en     (core_ce),
        .bypass (core_bypass),
        .alpha  (alpha_val),
        .din    (in_l),
        .dout   (out_l)
    );

    rms_peak_core #(
        .DATA_W (AUDIO_WIDTH),
        .ALPHA_W(ALPHA_WIDTH)
    ) u_rms_r (
        .clk    (aclk),
        .rst_n  (aresetn),
        .en     (core_ce),
        .bypass (core_bypass),
        .alpha  (alpha_val),
        .din    (in_r),
        .dout   (out_r)
    );

    // ------------------------------------------------------------------------
    // Pipeline control (valid / last alignment)
    // ------------------------------------------------------------------------
    always @(posedge aclk) begin
        if (!aresetn) begin
            valid_pipe <= 0;
            last_pipe  <= 0;
        end else if (m_axis_tready) begin
            // Shift only when downstream is ready.
            // When s_axis_tvalid is low, bubbles are inserted naturally.
            valid_pipe <= {valid_pipe[CORE_LATENCY-2:0],
                           s_axis_tvalid && global_en};
            last_pipe  <= {last_pipe[CORE_LATENCY-2:0],
                           s_axis_tlast};
        end
    end

    // =========================================================================
    // 3. OUTPUT ASSIGNMENTS
    // =========================================================================
    
    // Backpressure propagation
    assign s_axis_tready = m_axis_tready;

    // Stereo repacking
    assign m_axis_tdata  = {out_r, out_l};
    assign m_axis_tvalid = valid_pipe[CORE_LATENCY-1];
    assign m_axis_tlast  = last_pipe[CORE_LATENCY-1];

endmodule
