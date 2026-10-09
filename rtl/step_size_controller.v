`timescale 1ns / 1ps

module step_size_controller #(
    parameter DATA_WIDTH = 16,
    parameter SHIFT_MIN  = 1,   // Coarse shift (Fastest adaptation)
    parameter SHIFT_MAX  = 6    // Fine shift (Steady-state precision)
)(
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         sample_valid,
    input  wire signed [DATA_WIDTH-1:0] error_in,
    output reg  [3:0]                   mu_shift
);

    reg [23:0] error_energy;
    wire [DATA_WIDTH-1:0] abs_error = error_in[DATA_WIDTH-1] ? -error_in : error_in;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            error_energy <= 24'd40000;
            mu_shift     <= SHIFT_MIN;
        end else if (sample_valid) begin
            // Leaky integrator: E[n] = (31/32)*E[n-1] + |e[n]|
            error_energy <= (error_energy - (error_energy >> 5)) + abs_error;

            // Progressive gear shift: As error energy drops, shift steps up
            if (error_energy > 24'd30000)
                mu_shift <= SHIFT_MIN;      // 1: Fast tracking
            else if (error_energy > 24'd15000)
                mu_shift <= SHIFT_MIN + 1;  // 2
            else if (error_energy > 24'd8000)
                mu_shift <= SHIFT_MIN + 2;  // 3
            else if (error_energy > 24'd4000)
                mu_shift <= SHIFT_MIN + 3;  // 4
            else if (error_energy > 24'd2000)
                mu_shift <= SHIFT_MIN + 4;  // 5
            else
                mu_shift <= SHIFT_MAX;      // 6: Ultra-fine steady state
        end
    end

endmodule