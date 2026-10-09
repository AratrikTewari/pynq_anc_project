`timescale 1ns / 1ps

module anc_core #(
    parameter DATA_WIDTH  = 16,
    parameter FILTER_TAPS = 16
)(
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         sample_valid,
    input  wire signed [DATA_WIDTH-1:0] primary_in,   // d[n] = signal + noise
    input  wire signed [DATA_WIDTH-1:0] ref_noise_in, // x[n] = correlated noise
    output reg  signed [DATA_WIDTH-1:0] cleaned_out,  // e[n] = cleaned audio
    output wire [3:0]                   active_mu_shift,
    output reg                          data_ready
);

    wire signed [DATA_WIDTH-1:0] y_est;
    wire                         filter_rdy;
    wire [3:0]                   mu_shift;

    reg signed [DATA_WIDTH-1:0] err_feedback;
    reg signed [DATA_WIDTH-1:0] primary_d1;
    reg signed [DATA_WIDTH-1:0] primary_d2;
    reg signed [DATA_WIDTH-1:0] primary_d3;

    // Step-size controller
    step_size_controller #(
        .DATA_WIDTH(DATA_WIDTH),
        .SHIFT_MIN(1),
        .SHIFT_MAX(6)
    ) u_step_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .sample_valid(sample_valid),
        .error_in(err_feedback),
        .mu_shift(mu_shift)
    );

    // Adaptive FIR filter with embedded fir_engine
    lms_filter #(
        .TAPS(FILTER_TAPS),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_lms_filter (
        .clk(clk),
        .rst_n(rst_n),
        .sample_valid(sample_valid),
        .ref_in(ref_noise_in),
        .err_in(err_feedback),
        .mu_shift(mu_shift),
        .filter_out(y_est),
        .out_valid(filter_rdy)
    );

    // Delay match shift-register: tracks latency through fir_engine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            primary_d1   <= 'd0;
            primary_d2   <= 'd0;
            primary_d3   <= 'd0;
            cleaned_out  <= 'd0;
            err_feedback <= 'd0;
            data_ready   <= 1'b0;
        end else begin
            if (sample_valid)
                primary_d1 <= primary_in;
            primary_d2 <= primary_d1;
            primary_d3 <= primary_d2;

            // Compute e[n] = d[n] - y[n] when engine produces valid output
            if (filter_rdy) begin
                cleaned_out  <= primary_d3 - y_est;
                err_feedback <= primary_d3 - y_est;
                data_ready   <= 1'b1;
            end else begin
                data_ready   <= 1'b0;
            end
        end
    end

    assign active_mu_shift = mu_shift;

endmodule