`timescale 1ns / 1ps

module fir_filter #(
    parameter integer DATA_WIDTH = 9
)(
    input  logic                  clk,          // 100 MHz Saati
    input  logic                  reset,        // Sýfýrlama
    input  logic                  sample_valid, // Yeni mikrofon verisi tetiklemesi (pdm_clk_rising)
    input  logic [DATA_WIDTH-1:0] sample_in,    // Ham Ses Verisi (Raw PCM)
    output logic [DATA_WIDTH-1:0] sample_out    // Filtrelenmiþ Ses Verisi (Filtered PCM)
);

    // 5-Tap Kaydýrmalý Yazmaç (X[n], X[n-1], X[n-2], X[n-3], X[n-4])
    logic [DATA_WIDTH-1:0] shift_reg [0:4];

    always_ff @(posedge clk) begin
        if (reset) begin
            shift_reg[0] <= '0;
            shift_reg[1] <= '0;
            shift_reg[2] <= '0;
            shift_reg[3] <= '0;
            shift_reg[4] <= '0;
        end else if (sample_valid) begin
            shift_reg[0] <= sample_in;
            shift_reg[1] <= shift_reg[0];
            shift_reg[2] <= shift_reg[1];
            shift_reg[3] <= shift_reg[2];
            shift_reg[4] <= shift_reg[3];
        end
    end

    // Katsayýlarla Çarpma: b = [1, 4, 6, 4, 1]
    // 1*X0 + 4*X1 + 6*X2 + 4*X3 + 1*X4
    // 6*X2 = (X2 << 2) + (X2 << 1)  (4*X2 + 2*X2)
    logic [DATA_WIDTH+3:0] mult0, mult1, mult2, mult3, mult4;
    logic [DATA_WIDTH+4:0] sum;

    always_comb begin
        mult0 = shift_reg[0];
        mult1 = shift_reg[1] << 2;                          // 4 * X[n-1]
        mult2 = (shift_reg[2] << 2) + (shift_reg[2] << 1);  // 6 * X[n-2]
        mult3 = shift_reg[3] << 2;                          // 4 * X[n-3]
        mult4 = shift_reg[4];

        sum = mult0 + mult1 + mult2 + mult3 + mult4;
    end

    // Normalizasyon: Toplamý 16'ya bölmek için 4-bit saða kaydýrýyoruz (>> 4)
    logic [DATA_WIDTH-1:0] filtered_reg;

    always_ff @(posedge clk) begin
        if (sample_valid) begin
            filtered_reg <= sum[DATA_WIDTH+3:4];
        end
    end

    assign sample_out = filtered_reg;

endmodule