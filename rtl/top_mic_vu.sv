`timescale 1ns / 1ps

module top_mic_vu (
    input  logic       clk_100mhz,  // E3 Pini (100 MHz Osilatör)
    input  logic       mic_data,    // H5 Pini (PDM Data)
    input  logic       filter_sw,   // J15 Pini (SW0: 0=Ham Ses, 1=FIR Filtreli Ses)
    output logic       mic_clk,     // J5 Pini (PDM Clock)
    output logic       mic_lr_sel,  // K5 Pini (Sol/Sað Kanal Seçimi)
    output logic [7:0] leds,        // LED0 - LED7
    output logic [7:0] seg,         // 7-Segment Segment Çýkýþlarý
    output logic [7:0] an,          // 7-Segment Anot Çýkýþlarý

    // VGA Çýkýþ Pinleri
    output logic       vga_hs,
    output logic       vga_vs,
    output logic [3:0] vga_r,
    output logic [3:0] vga_g,
    output logic [3:0] vga_b,

    // UART Çýkýþ Pini
    output logic       uart_tx_out  // D4 Pini (USB-UART TX)
);

    assign mic_lr_sel = 1'b0;

    // -------------------------------------------------------------
    // Clocking Wizard IP (100 MHz -> 108 MHz VGA Pixel Clock)
    // -------------------------------------------------------------
    logic pxl_clk_108mhz;
    
    clk_wiz_0 clk_gen (
        .clk_in1(clk_100mhz),
        .clk_out1(pxl_clk_108mhz)
    );

    // 100 MHz -> ~2.44 MHz PDM Clock Divider
    logic [5:0] clk_div = '0;
    logic       pdm_clk_reg = '0;

    always_ff @(posedge clk_100mhz) begin
        if (clk_div == 20) begin
            clk_div     <= '0;
            pdm_clk_reg <= ~pdm_clk_reg;
        end else begin
            clk_div <= clk_div + 1'b1;
        end
    end

    assign mic_clk = pdm_clk_reg;

    // Yükselen Kenar Tespiti
    logic pdm_clk_d1;
    always_ff @(posedge clk_100mhz) begin
        pdm_clk_d1 <= pdm_clk_reg;
    end
    wire pdm_clk_rising = pdm_clk_reg & ~pdm_clk_d1;

    // Ham Ses Genliði (Demodüle Veri)
    logic [8:0] raw_sample;

    // LED VU-Meter Modülü
    mic_vu_meter #(
        .Y_HEIGHT(375),
        .SAMPLE_RATE_DIV(4096)
    ) vu_inst (
        .clk_i            (clk_100mhz),
        .sysclk           (clk_100mhz),
        .mic_m_data_i     (mic_data),
        .mic_m_clk_rising (pdm_clk_rising),
        .sample_out       (raw_sample),
        .leds_o           (leds)
    );

    // -------------------------------------------------------------
    // FIR Alçak Geçiren Filtre (Low-Pass Filter)
    // -------------------------------------------------------------
    logic [8:0] filtered_sample;

    fir_filter #(
        .DATA_WIDTH(9)
    ) fir_inst (
        .clk          (clk_100mhz),
        .reset        (1'b0),
        .sample_valid (pdm_clk_rising),
        .sample_in    (raw_sample),
        .sample_out   (filtered_sample)
    );

    // SW0 Anahtarýna Göre Seçim Yap: 0 -> Ham Ses, 1 -> Filtrelenmiþ Ses
    logic [8:0] final_sample;
    assign final_sample = (filter_sw) ? filtered_sample : raw_sample;

    // 7-Segment Modülü
    seven_segment_ctrl seg_inst (
        .clk_100mhz (clk_100mhz),
        .sample_val (final_sample),
        .seg        (seg),
        .an         (an)
    );

    // VGA Modülü (Seçilen Veri Ekrana Çizilir)
    vga_controller vga_inst (
        .pxl_clk        (pxl_clk_108mhz),
        .sysclk         (clk_100mhz),
        .mic_data       (mic_data),
        .mic_clk_rising (pdm_clk_rising),
        .vga_hs         (vga_hs),
        .vga_vs         (vga_vs),
        .vga_r          (vga_r),
        .vga_g          (vga_g),
        .vga_b          (vga_b)
    );

    // -------------------------------------------------------------
    // UART TX Entegrasyonu (115200 Baud)
    // -------------------------------------------------------------
    logic tx_busy;
    logic tx_start;

    assign tx_start = pdm_clk_rising & ~tx_busy;

    uart_tx #(
        .CLK_FREQ(100_000_000),
        .BAUD_RATE(115_200)
    ) uart_inst (
        .clk      (clk_100mhz),
        .reset    (1'b0),
        .tx_start (tx_start),
        .tx_data  (final_sample[8:1]), // Seçilen final veriyi 8-bit'e indirgeyip gönder
        .tx       (uart_tx_out),
        .tx_busy  (tx_busy)
    );

endmodule