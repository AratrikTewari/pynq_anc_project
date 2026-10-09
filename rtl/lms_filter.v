`timescale 1ns / 1ps

module lms_filter #(
    parameter TAPS       = 16,
    parameter DATA_WIDTH = 16
)(
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         sample_valid,
    input  wire signed [DATA_WIDTH-1:0] ref_in,      // Reference noise x[n]
    input  wire signed [DATA_WIDTH-1:0] err_in,      // Residual error e[n]
    input  wire [3:0]                   mu_shift,    // Dynamic shift from controller
    output wire signed [DATA_WIDTH-1:0] filter_out,  // Estimated noise y[n]
    output wire                         out_valid
);

    reg signed [DATA_WIDTH-1:0] x_pipe [0:TAPS-1];
    reg signed [DATA_WIDTH-1:0] w_pipe [0:TAPS-1];

    wire [(TAPS*DATA_WIDTH)-1:0] x_vector_flat;
    wire [(TAPS*DATA_WIDTH)-1:0] w_vector_flat;

    reg fir_start;
    wire engine_done;
    
    // Pipelined adaptation registers
    reg signed [2*DATA_WIDTH-1:0] grad_prod_reg [0:TAPS-1];
    reg [3:0]                     mu_shift_reg;
    reg                           update_stage2;

    reg signed [DATA_WIDTH-1:0]   w_delta;
    reg signed [DATA_WIDTH:0]     w_sum;
    integer i;

    // Pack 2D arrays into 1D buses
    genvar g;
    generate
        for (g = 0; g < TAPS; g = g + 1) begin : gen_flat_vectors
            assign x_vector_flat[g*DATA_WIDTH +: DATA_WIDTH] = x_pipe[g];
            assign w_vector_flat[g*DATA_WIDTH +: DATA_WIDTH] = w_pipe[g];
        end
    endgenerate

    // Pipelined FIR Engine
    fir_engine #(
        .TAPS(TAPS),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_fir_engine (
        .clk(clk),
        .rst_n(rst_n),
        .compute_en(fir_start),
        .x_vector(x_vector_flat),
        .w_vector(w_vector_flat),
        .y_out(filter_out),
        .done(engine_done)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < TAPS; i = i + 1) begin
                x_pipe[i]        <= 'd0;
                w_pipe[i]        <= 'd0;
                grad_prod_reg[i] <= 'd0;
            end
            fir_start     <= 1'b0;
            update_stage2 <= 1'b0;
            mu_shift_reg  <= 4'd1;
        end else begin
            // 1. Shift reference delay line on sample arrival
            if (sample_valid) begin
                x_pipe[0] <= ref_in;
                for (i = 1; i < TAPS; i = i + 1) begin
                    x_pipe[i] <= x_pipe[i-1];
                end
                fir_start <= 1'b1;
            end else begin
                fir_start <= 1'b0;
            end

            // 2. Adaptation Pipeline Stage 1: Multiply and register product
            if (engine_done) begin
                for (i = 0; i < TAPS; i = i + 1) begin
                    grad_prod_reg[i] <= x_pipe[i] * err_in;
                end
                mu_shift_reg  <= mu_shift;
                update_stage2 <= 1'b1;
            end else begin
                update_stage2 <= 1'b0;
            end

            // 3. Adaptation Pipeline Stage 2: Barrel shift + Add + Clamp into weights
            if (update_stage2) begin
                for (i = 0; i < TAPS; i = i + 1) begin
                    w_delta = grad_prod_reg[i] >>> (16 + mu_shift_reg);
                    w_sum   = {w_pipe[i][DATA_WIDTH-1], w_pipe[i]} + {w_delta[DATA_WIDTH-1], w_delta};

                    if (w_sum > 17'sh0_7FFF)
                        w_pipe[i] <= 16'sh7FFF;
                    else if (w_sum < -17'sh0_8000)
                        w_pipe[i] <= 16'sh8000;
                    else
                        w_pipe[i] <= w_sum[DATA_WIDTH-1:0];
                end
            end
        end
    end

    assign out_valid = engine_done;

endmodule