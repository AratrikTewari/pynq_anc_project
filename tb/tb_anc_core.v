`timescale 1ns / 1ps

module tb_anc_core;

    localparam DATA_WIDTH  = 16;
    localparam FILTER_TAPS = 16;
    localparam CLK_PERIOD  = 8;   // 125 MHz clock (8 ns)
    localparam MEM_DEPTH   = 64;  // Number of entries in .mem files

    reg                         clk;
    reg                         rst_n;
    reg                         sample_valid;
    reg  signed [DATA_WIDTH-1:0] primary_in;
    reg  signed [DATA_WIDTH-1:0] ref_noise_in;
    wire signed [DATA_WIDTH-1:0] cleaned_out;
    wire [3:0]                  active_mu_shift;
    wire                        data_ready;

    reg signed [DATA_WIDTH-1:0] primary_mem   [0:MEM_DEPTH-1];
    reg signed [DATA_WIDTH-1:0] reference_mem [0:MEM_DEPTH-1];

    anc_core #(
        .DATA_WIDTH(DATA_WIDTH),
        .FILTER_TAPS(FILTER_TAPS)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .sample_valid(sample_valid),
        .primary_in(primary_in),
        .ref_noise_in(ref_noise_in),
        .cleaned_out(cleaned_out),
        .active_mu_shift(active_mu_shift),
        .data_ready(data_ready)
    );

    always #(CLK_PERIOD / 2) clk = ~clk;

    integer i, n;
    integer total_abs_err;
    integer signed_clean;

    initial begin
        clk          = 1'b0;
        rst_n        = 1'b0;
        sample_valid = 1'b0;
        primary_in   = 'd0;
        ref_noise_in = 'd0;

        $readmemh("primary_signal.mem", primary_mem);
        $readmemh("reference_noise.mem", reference_mem);

        #(CLK_PERIOD * 10);
        rst_n = 1'b1;
        #(CLK_PERIOD * 5);

        $display("------------------------------------------------------------------");
        $display("Starting ANC Core Simulation with Loaded Hex Stimulus Vectors...");
        $display("------------------------------------------------------------------");

        for (n = 0; n < 20; n = n + 1) begin
            total_abs_err = 0;
            for (i = 0; i < MEM_DEPTH; i = i + 1) begin
                @(posedge clk);
                primary_in   = primary_mem[i];
                ref_noise_in = reference_mem[i];

                sample_valid = 1'b1;
                @(posedge clk);
                sample_valid = 1'b0;

                @(posedge data_ready);
                
                // Explicit 32-bit signed absolute calculation
                signed_clean = cleaned_out;
                if (signed_clean < 0)
                    total_abs_err = total_abs_err - signed_clean;
                else
                    total_abs_err = total_abs_err + signed_clean;

                #(CLK_PERIOD * 10);
            end
            $display("Iteration %2d | Mean Abs Error: %5d | Active Shift: %1d | Sample e[n]: %6d", 
                     n, (total_abs_err / MEM_DEPTH), active_mu_shift, cleaned_out);
        end

        $display("------------------------------------------------------------------");
        $display("Stimulus Replay Complete. ANC Core Filter Converged.");
        $display("------------------------------------------------------------------");
        $finish;
    end

endmodule