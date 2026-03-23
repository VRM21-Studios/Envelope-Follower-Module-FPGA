`timescale 1 ns / 1 ps

// ============================================================================
// Testbench: rms_peak_core
// ----------------------------------------------------------------------------
// Functional verification for RMS / Peak envelope core.
//
// Test coverage:
// 1. Step response (fast attack)
// 2. Sine wave smoothing (slow alpha)
// 3. Dynamic alpha change during steady input
// 4. Corner case: minimum signed input (-32768)
// 5. Bypass mode timing and correctness
//
// Output data is logged to CSV for offline inspection and plotting.
// ============================================================================

module tb_rms_peak_core;

    // ========================================================================
    // 1. PARAMETERS
    // ========================================================================
    parameter integer DATA_W     = 16;
    parameter integer ALPHA_W    = 16;
    parameter integer CLK_PERIOD = 20; // 50 MHz clock (period in ns)

    // ========================================================================
    // 2. SIGNAL DECLARATIONS
    // ========================================================================
    reg                 clk;
    reg                 rst_n;
    reg                 en;
    reg                 bypass;

    // Control parameter (alpha, fixed-point Q0.16)
    reg  [ALPHA_W-1:0]  alpha;

    // Audio data
    reg  signed [DATA_W-1:0] din;
    wire [DATA_W-1:0]        dout;

    // CSV file handle
    integer file_h;

    // ========================================================================
    // 3. UNIT UNDER TEST (UUT)
    // ========================================================================
    rms_peak_core #(
        .DATA_W (DATA_W),
        .ALPHA_W(ALPHA_W)
    ) uut (
        .clk    (clk),
        .rst_n  (rst_n),
        .en     (en),
        .bypass (bypass),
        .alpha  (alpha),
        .din    (din),
        .dout   (dout)
    );

    // ========================================================================
    // 4. CLOCK GENERATION
    // ========================================================================
    // Explicit initialization guarantees no X/Z clock startup.
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // ========================================================================
    // 5. CSV DATA LOGGING
    // ========================================================================
    // Logged fields:
    //   time   : simulation time
    //   din    : signed input sample
    //   dout   : envelope output
    //   alpha  : smoothing coefficient
    //   bypass : bypass state
    initial begin
        file_h = $fopen("tb_data_rms_peak_core.csv", "w");
        $fdisplay(file_h, "time,din,dout,alpha,bypass");

        forever begin
            @(posedge clk);
            if (rst_n) begin
                $fdisplay(
                    file_h,
                    "%0d,%0d,%0d,%0d,%b",
                    $time,
                    $signed(din),
                    dout,
                    alpha,
                    bypass
                );
            end
        end
    end

    // ========================================================================
    // 6. STIMULUS SEQUENCES
    // ========================================================================
    integer i;
    real    phi;
    real    freq;

    initial begin
        // --------------------------------------------------------------------
        // A. Initial Conditions
        // --------------------------------------------------------------------
        i      = 0;
        rst_n  = 1'b0;
        en     = 1'b0;
        bypass = 1'b0;
        alpha  = 16'h0000;
        din    = 16'sd0;

        // --------------------------------------------------------------------
        // B. Reset Sequence
        // --------------------------------------------------------------------
        #(CLK_PERIOD * 10); // Hold reset for 10 cycles
        rst_n = 1'b1;
        en    = 1'b1;
        #(CLK_PERIOD * 5);

        // --------------------------------------------------------------------
        // TEST 1: Step Response (Fast Attack)
        // --------------------------------------------------------------------
        $display("Time: %0d | Test 1: Step Response", $time);
        alpha = 16'h4000; // Alpha = 0.5 (fast response)
        din   = 16'sd15000;
        #(CLK_PERIOD * 50);

        // Return to zero input
        din = 16'sd0;
        #(CLK_PERIOD * 50);

        // --------------------------------------------------------------------
        // TEST 2: Sine Wave Input (Slow Smoothing)
        // --------------------------------------------------------------------
        $display("Time: %0d | Test 2: Sine Wave", $time);
        alpha = 16'h0200; // Small alpha (smooth envelope)
        freq  = 0.05;

        for (i = 0; i < 300; i = i + 1) begin
            phi = 2.0 * 3.14159 * freq * i;
            din = $rtoi(20000.0 * $sin(phi));
            @(posedge clk);
        end

        // --------------------------------------------------------------------
        // TEST 3: Dynamic Alpha Change
        // --------------------------------------------------------------------
        // Observe envelope response as alpha transitions
        // from slow to fast while input is constant.
        $display("Time: %0d | Test 3: Dynamic Alpha", $time);
        din = 16'sd25000;

        for (i = 0; i < 100; i = i + 1) begin
            alpha = alpha + 16'h00A0;
            @(posedge clk);
        end
        #(CLK_PERIOD * 20);

        // --------------------------------------------------------------------
        // TEST 4: Corner Case (Minimum Signed Value)
        // --------------------------------------------------------------------
        $display("Time: %0d | Test 4: Corner Case Input", $time);
        alpha = 16'h7FFF;      // Maximum alpha
        din   = -16'sd32768;   // Minimum signed 16-bit value
        @(posedge clk);
        #(CLK_PERIOD * 10);

        din = 16'sd0;
        #(CLK_PERIOD * 20);

        // --------------------------------------------------------------------
        // TEST 5: Bypass Mode
        // --------------------------------------------------------------------
        // Verify timing alignment and correct bypass behavior.
        $display("Time: %0d | Test 5: Bypass Mode", $time);
        bypass = 1'b1;
        din    = 16'sd10000;
        #(CLK_PERIOD * 10);

        din = -16'sd5000;
        #(CLK_PERIOD * 10);

        // --------------------------------------------------------------------
        // END OF SIMULATION
        // --------------------------------------------------------------------
        $display("Time: %0d | Simulation Finished", $time);
        $fclose(file_h);
        $stop;
    end

endmodule
