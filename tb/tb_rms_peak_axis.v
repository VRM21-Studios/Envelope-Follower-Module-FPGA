`timescale 1 ns / 1 ps

// ============================================================================
// Testbench: rms_peak_axis
// ----------------------------------------------------------------------------
// System-level verification for RMS / Peak Envelope AXI module.
//
// Scope:
// - AXI-Lite control path (enable, bypass, alpha)
// - AXI-Stream stereo data path
// - Envelope behavior under various stimuli
//
// Logged output:
//   CSV file for offline analysis and plotting.
//
// Notes:
// - AXI-Stream backpressure is disabled (m_axis_tready always high)
// - AXI-Lite read channel is not exercised (write-only focus)
// ============================================================================

module tb_rms_peak_axis;

    // ========================================================================
    // 1. PARAMETERS
    // ========================================================================
    parameter integer C_S_AXI_DATA_WIDTH = 32;
    parameter integer C_S_AXI_ADDR_WIDTH = 4;
    parameter integer CLK_PERIOD         = 20; // 50 MHz clock

    // ========================================================================
    // 2. SIGNAL DECLARATIONS
    // ========================================================================
    reg  aclk;
    reg  aresetn;

    // ------------------------------------------------------------------------
    // AXI4-Stream Slave (Input Stimulus)
    // ------------------------------------------------------------------------
    reg  [31:0] s_axis_tdata;
    reg         s_axis_tlast;
    reg         s_axis_tvalid;
    wire        s_axis_tready;

    // ------------------------------------------------------------------------
    // AXI4-Stream Master (DUT Output)
    // ------------------------------------------------------------------------
    wire [31:0] m_axis_tdata;
    wire        m_axis_tlast;
    wire        m_axis_tvalid;
    reg         m_axis_tready;

    // ------------------------------------------------------------------------
    // AXI4-Lite Control Interface
    // ------------------------------------------------------------------------
    reg  [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr;
    reg                           s_axi_awvalid;
    wire                          s_axi_awready;
    reg  [C_S_AXI_DATA_WIDTH-1:0] s_axi_wdata;
    reg  [3:0]                    s_axi_wstrb;
    reg                           s_axi_wvalid;
    wire                          s_axi_wready;
    wire [1:0]                    s_axi_bresp;
    wire                          s_axi_bvalid;
    reg                           s_axi_bready;

    // Read channel (tied off, not used)
    reg  [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr;
    reg                           s_axi_arvalid;
    wire                          s_axi_arready;
    wire [C_S_AXI_DATA_WIDTH-1:0] s_axi_rdata;
    wire [1:0]                    s_axi_rresp;
    wire                          s_axi_rvalid;
    reg                           s_axi_rready;

    // CSV file handle
    integer file_h;

    // ========================================================================
    // 3. DUT INSTANTIATION
    // ========================================================================
    rms_peak_axis #(
        .C_S_AXI_DATA_WIDTH(32),
        .C_S_AXI_ADDR_WIDTH(4),
        .AUDIO_WIDTH       (16),
        .ALPHA_WIDTH       (16)
    ) uut (
        .aclk(aclk),
        .aresetn(aresetn),

        // AXI-Stream In
        .s_axis_tdata (s_axis_tdata),
        .s_axis_tlast (s_axis_tlast),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),

        // AXI-Stream Out
        .m_axis_tdata (m_axis_tdata),
        .m_axis_tlast (m_axis_tlast),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),

        // AXI-Lite Control
        .s_axi_awaddr (s_axi_awaddr),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata  (s_axi_wdata),
        .s_axi_wstrb  (s_axi_wstrb),
        .s_axi_wvalid (s_axi_wvalid),
        .s_axi_wready (s_axi_wready),
        .s_axi_bresp  (s_axi_bresp),
        .s_axi_bvalid (s_axi_bvalid),
        .s_axi_bready (s_axi_bready),
        .s_axi_araddr (s_axi_araddr),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata  (s_axi_rdata),
        .s_axi_rresp  (s_axi_rresp),
        .s_axi_rvalid (s_axi_rvalid),
        .s_axi_rready (s_axi_rready)
    );

    // ========================================================================
    // 4. CLOCK GENERATION
    // ========================================================================
    initial begin
        aclk = 1'b0;
        forever #(CLK_PERIOD / 2) aclk = ~aclk;
    end

    // ========================================================================
    // 5. AXI-LITE HELPER TASKS
    // ========================================================================
    // AXI-Lite single-beat write transaction
    task axi_write;
        input [3:0]  addr;
        input [31:0] data;
        begin
            @(posedge aclk);
            s_axi_awaddr  <= addr;
            s_axi_awvalid <= 1'b1;
            s_axi_wdata   <= data;
            s_axi_wvalid  <= 1'b1;
            s_axi_wstrb   <= 4'hF;
            s_axi_bready  <= 1'b1;

            // Wait for address & data handshake
            wait (s_axi_awready && s_axi_wready);

            @(posedge aclk);
            s_axi_awvalid <= 1'b0;
            s_axi_wvalid  <= 1'b0;

            // Wait for write response
            wait (s_axi_bvalid);
            @(posedge aclk);
            s_axi_bready <= 1'b0;

            $display("AXI-Lite Write: Addr 0x%h = 0x%h", addr, data);
        end
    endtask

    // ========================================================================
    // 6. CSV LOGGING
    // ========================================================================
    // Logged columns:
    //   time   : simulation time
    //   in_L   : left-channel input sample
    //   in_R   : right-channel input sample
    //   out_L  : left-channel envelope output
    //   out_R  : right-channel envelope output
    //   valid  : AXI-Stream valid flag
    initial begin
        file_h = $fopen("tb_data_rms_peak_axis.csv", "w");
        $fdisplay(file_h, "time,in_L,in_R,out_L,out_R,valid_out");

        forever begin
            @(posedge aclk);
            if (aresetn && m_axis_tvalid && m_axis_tready) begin
                $fdisplay(
                    file_h,
                    "%0d,%0d,%0d,%0d,%0d,%b",
                    $time,
                    $signed(s_axis_tdata[15:0]),
                    $signed(s_axis_tdata[31:16]),
                    $signed(m_axis_tdata[15:0]),
                    $signed(m_axis_tdata[31:16]),
                    m_axis_tvalid
                );
            end
        end
    end

    // ========================================================================
    // 7. MAIN STIMULUS SEQUENCE
    // ========================================================================
    integer i;
    real    phi;
    real    freq;
    reg signed [15:0] stim_l, stim_r;

    initial begin
        // --------------------------------------------------------------------
        // Initial Conditions
        // --------------------------------------------------------------------
        aresetn = 1'b0;
        i       = 0;

        // AXI-Stream idle
        s_axis_tdata  = 32'd0;
        s_axis_tvalid = 1'b0;
        s_axis_tlast  = 1'b0;

        // AXI-Lite idle
        s_axi_awaddr  = 4'd0; 
        s_axi_awvalid = 1'b0;
        s_axi_wdata   = 32'd0; 
        s_axi_wvalid  = 1'b0; 
        s_axi_wstrb   = 4'd0;
        s_axi_bready  = 1'b0;
        s_axi_araddr  = 4'd0; 
        s_axi_arvalid = 1'b0; 
        s_axi_rready  = 1'b0;

        // Downstream always ready
        m_axis_tready = 1'b1;

        // --------------------------------------------------------------------
        // Reset Sequence
        // --------------------------------------------------------------------
        #(CLK_PERIOD * 10);
        aresetn = 1'b1;
        #(CLK_PERIOD * 10);

        // --------------------------------------------------------------------
        // Configuration Phase
        // --------------------------------------------------------------------
        $display("--- Configuring Core via AXI-Lite ---");

        // Alpha = 0.5 (fast envelope response)
        axi_write(4'h4, 32'h0000_4000);

        // Enable core, bypass disabled
        axi_write(4'h0, 32'h0000_0001);

        #(CLK_PERIOD * 10);

        // --------------------------------------------------------------------
        // TEST 1: Stereo Pulse
        // --------------------------------------------------------------------
        // Left: positive, Right: negative
        // Verifies absolute value and channel independence.
        $display("--- Test 1: Stereo Pulse ---");
        s_axis_tvalid = 1'b1;

        stim_l = 16'sd15000;
        stim_r = -16'sd15000;
        s_axis_tdata = {stim_r, stim_l};

        #(CLK_PERIOD);
        s_axis_tdata = 32'd0;

        // Observe decay
        #(CLK_PERIOD * 50);

        // --------------------------------------------------------------------
        // TEST 2: Stereo Sine Wave (Phase Offset)
        // --------------------------------------------------------------------
        $display("--- Test 2: Stereo Sine Wave ---");

        // Alpha = slow / smooth
        axi_write(4'h4, 32'h0000_0200);

        freq = 0.05;
        for (i = 0; i < 300; i = i + 1) begin
            phi = 2.0 * 3.14159 * freq * i;

            stim_l = $rtoi(20000.0 * $sin(phi)); // sine
            stim_r = $rtoi(10000.0 * $cos(phi)); // cosine (90 deg phase)

            s_axis_tdata  = {stim_r, stim_l};
            s_axis_tvalid = 1'b1;
            @(posedge aclk);
        end

        s_axis_tvalid = 1'b0;
        s_axis_tdata  = 32'd0;
        #(CLK_PERIOD * 20);

        // --------------------------------------------------------------------
        // TEST 3: Bypass Mode
        // --------------------------------------------------------------------
        $display("--- Test 3: Bypass Mode ---");

        // Enable + Bypass
        axi_write(4'h0, 32'h0000_0003);

        s_axis_tvalid = 1'b1;
        for (i = 0; i < 20; i = i + 1) begin
            stim_l = (i % 2 == 0) ? 16'sd10000 : -16'sd10000;
            stim_r = 16'sd5000;
            s_axis_tdata = {stim_r, stim_l};
            @(posedge aclk);
        end

        s_axis_tvalid = 1'b0;

        // --------------------------------------------------------------------
        // End of Simulation
        // --------------------------------------------------------------------
        #(CLK_PERIOD * 20);
        $display("--- Simulation Done ---");
        $fclose(file_h);
        $stop;
    end

endmodule
