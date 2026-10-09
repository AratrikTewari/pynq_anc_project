`timescale 1ns / 1ps

module fir_engine #(
    parameter TAPS       = 16,
    parameter DATA_WIDTH = 16
)(
    input  wire                               clk,
    input  wire                               rst_n,
    input  wire                               compute_en,
    input  wire signed [(TAPS*DATA_WIDTH)-1:0] x_vector,
    input  wire signed [(TAPS*DATA_WIDTH)-1:0] w_vector,
    output reg  signed [DATA_WIDTH-1:0]       y_out,
    output reg                                done
);

    // Stage 1: DSP48 Multiplications (16 parallel products)
    reg signed [2*DATA_WIDTH-1:0] product_pipe [0:TAPS-1];
    reg compute_p1;

    // Stage 2: Adder Tree Level 1 (16 -> 4 partial sums)
    reg signed [2*DATA_WIDTH+1:0] sum_lvl1 [0:3];
    reg compute_p2;

    // Stage 3: Adder Tree Level 2 (4 -> 1 accumulator)
    reg signed [2*DATA_WIDTH+3:0] accumulator;
    reg compute_p3;

    integer k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (k = 0; k < TAPS; k = k + 1) begin
                product_pipe[k] <= 'd0;
            end
            sum_lvl1[0] <= 'd0; sum_lvl1[1] <= 'd0;
            sum_lvl1[2] <= 'd0; sum_lvl1[3] <= 'd0;
            accumulator <= 'd0;
            y_out       <= 'd0;
            compute_p1  <= 1'b0;
            compute_p2  <= 1'b0;
            compute_p3  <= 1'b0;
            done        <= 1'b0;
        end else begin
            // Pipeline valid shift register
            compute_p1 <= compute_en;
            compute_p2 <= compute_p1;
            compute_p3 <= compute_p2;
            done       <= compute_p3;

            // Pipeline Stage 1: Multipliers (Maps directly into DSP48E1)
            if (compute_en) begin
                for (k = 0; k < TAPS; k = k + 1) begin
                    product_pipe[k] <= $signed(x_vector[k*DATA_WIDTH +: DATA_WIDTH]) *
                                       $signed(w_vector[k*DATA_WIDTH +: DATA_WIDTH]);
                end
            end

            // Pipeline Stage 2: Balanced 4-way intermediate partial sums
            if (compute_p1) begin
                sum_lvl1[0] <= product_pipe[0]  + product_pipe[1]  + product_pipe[2]  + product_pipe[3];
                sum_lvl1[1] <= product_pipe[4]  + product_pipe[5]  + product_pipe[6]  + product_pipe[7];
                sum_lvl1[2] <= product_pipe[8]  + product_pipe[9]  + product_pipe[10] + product_pipe[11];
                sum_lvl1[3] <= product_pipe[12] + product_pipe[13] + product_pipe[14] + product_pipe[15];
            end

            // Pipeline Stage 3: Final accumulation
            if (compute_p2) begin
                accumulator <= sum_lvl1[0] + sum_lvl1[1] + sum_lvl1[2] + sum_lvl1[3];
            end

            // Pipeline Stage 4: Rounding, Saturation & Output latching
            if (compute_p3) begin
                if (accumulator > 36'sh00_3FFF_FFFF)
                    y_out <= 16'sh7FFF;
                else if (accumulator < -36'sh00_4000_0000)
                    y_out <= 16'sh8000;
                else
                    y_out <= accumulator[(2*DATA_WIDTH-2) -: DATA_WIDTH];
            end
        end
    end

endmodule