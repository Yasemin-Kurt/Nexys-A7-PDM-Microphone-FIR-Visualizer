`timescale 1ns / 1ps

module mic_vu_meter #(
    parameter integer Y_HEIGHT        = 375,
    parameter integer SAMPLE_RATE_DIV = 4096
)(
    input  logic       clk_i,             // 100 MHz Sistem Saati
    input  logic       sysclk,            // 100 MHz Sistem Saati
    input  logic       mic_m_data_i,      // Mikrofondan gelen PDM verisi
    input  logic       mic_m_clk_rising,  // Mikrofon saat yükselen kenar tetiklemesi
    output logic [8:0] sample_out,        // Display için dýþarý aktarýlan Genlik Deðeri
    output logic [7:0] leds_o             // 8 Adet LED Çýkýþý
);

    localparam integer SR_WIDTH     = Y_HEIGHT;
    localparam integer SAMPLE_WIDTH = $clog2(Y_HEIGHT);

    // Senkronizasyon ve Kenar Yakalama
    logic mic_m_clk_rising_syncasync;
    logic mic_m_clk_rising_sync1;
    logic mic_m_clk_rising_sync0;
    logic mic_m_clk_rising_sync;
    logic mic_m_clk_rising_os;

    // Kaydýrmalý Yazmaç ve Genlik Deðeri
    logic [SR_WIDTH-1:0]     mic_sr_reg = '0;
    logic [SAMPLE_WIDTH-1:0] sample_reg = '0;

    // Genlik deðerini dýþarý aktar
    assign sample_out = sample_reg;

    // 1. Senkronizatör Çaðrýsý
    sync_async #(
        .K_RESET_TO(1'b0),
        .K_STAGES(2)
    ) sync_inst (
        .aReset(1'b0),
        .aIn(mic_m_clk_rising),
        .OutClk(clk_i),
        .oOut(mic_m_clk_rising_syncasync)
    );

    // 2. One-Shot (Tek Darbe) Tespiti
    always_ff @(posedge clk_i) begin
        mic_m_clk_rising_sync1 <= mic_m_clk_rising_syncasync;
        mic_m_clk_rising_sync0 <= mic_m_clk_rising_sync1;
        mic_m_clk_rising_sync  <= mic_m_clk_rising_sync0;
    end

    assign mic_m_clk_rising_os = mic_m_clk_rising_sync0 & (~mic_m_clk_rising_sync);

    // 3. PDM Demodülasyonu
    always_ff @(posedge clk_i) begin
        if (mic_m_clk_rising_os) begin
            mic_sr_reg <= {mic_sr_reg[SR_WIDTH-2:0], mic_m_data_i};

            if ((mic_sr_reg[SR_WIDTH-1] == 1'b0) && (mic_m_data_i == 1'b1)) begin
                sample_reg <= sample_reg + 3'd3;
            end 
            else if ((mic_sr_reg[SR_WIDTH-1] == 1'b1) && (mic_m_data_i == 1'b0)) begin
                sample_reg <= sample_reg - 3'd3;
            end
        end
    end

    // 4. LED VU-Meter Karþýlaþtýrma Mantýðý
    always_ff @(posedge clk_i) begin
        if (sample_reg > 320)      leds_o <= 8'b1111_1111;
        else if (sample_reg > 280) leds_o <= 8'b0111_1111;
        else if (sample_reg > 240) leds_o <= 8'b0011_1111;
        else if (sample_reg > 200) leds_o <= 8'b0001_1111;
        else if (sample_reg > 160) leds_o <= 8'b0000_1111;
        else if (sample_reg > 120) leds_o <= 8'b0000_0111;
        else if (sample_reg > 80)  leds_o <= 8'b0000_0011;
        else if (sample_reg > 40)  leds_o <= 8'b0000_0001;
        else                       leds_o <= 8'b0000_0000;
    end

endmodule