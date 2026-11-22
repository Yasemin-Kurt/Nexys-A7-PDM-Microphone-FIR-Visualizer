`timescale 1ns / 1ps

module vga_controller (
    input  logic        pxl_clk,        // 108 MHz Pixel Clock
    input  logic        sysclk,         // 100 MHz Sistem Saati
    input  logic        mic_data,       // PDM Mikrofon Verisi
    input  logic        mic_clk_rising, // PDM Yükselen Kenar
    
    // VGA Çýkýþ Sinyalleri
    output logic        vga_hs,
    output logic        vga_vs,
    output logic [3:0]  vga_r,
    output logic [3:0]  vga_g,
    output logic [3:0]  vga_b
);

    // 1280x1024 @ 60Hz Zamanlama Sabitleri
    localparam integer FRAME_WIDTH  = 1280;
    localparam integer FRAME_HEIGHT = 1024;
    localparam integer H_FP         = 48;
    localparam integer H_PW         = 112;
    localparam integer H_MAX        = 1688;
    localparam integer V_FP         = 1;
    localparam integer V_PW         = 3;
    localparam integer V_MAX        = 1066;
    localparam logic   H_POL        = 1'b1;
    localparam logic   V_POL        = 1'b1;

    // Mikrofon Çerçeve Sabitleri
    localparam integer SZ_MIC_WIDTH  = 915;
    localparam integer SZ_MIC_HEIGHT = 375;
    localparam integer FRM_MIC_H_LOC = 25;
    localparam integer FRM_MIC_V_LOC = 615;

    localparam integer MIC_LEFT   = FRM_MIC_H_LOC - 1;
    localparam integer MIC_RIGHT  = FRM_MIC_H_LOC + SZ_MIC_WIDTH + 1;
    localparam integer MIC_TOP    = FRM_MIC_V_LOC - 1;
    localparam integer MIC_BOTTOM = FRM_MIC_V_LOC + SZ_MIC_HEIGHT + 1;

    // Sayaçlar ve Senkron Sinyaller
    logic [11:0] h_cntr_reg = '0;
    logic [11:0] v_cntr_reg = '0;
    logic [11:0] h_cntr_reg_dly = '0;
    logic [11:0] v_cntr_reg_dly = '0;

    logic h_sync_reg = ~H_POL;
    logic v_sync_reg = ~V_POL;
    logic h_sync_reg_dly = ~H_POL;
    logic v_sync_reg_dly = ~V_POL;

    logic active;

    // Yatay Sayaç
    always_ff @(posedge pxl_clk) begin
        if (h_cntr_reg == H_MAX - 1)
            h_cntr_reg <= '0;
        else
            h_cntr_reg <= h_cntr_reg + 1'b1;
    end

    // Dikey Sayaç
    always_ff @(posedge pxl_clk) begin
        if ((h_cntr_reg == H_MAX - 1) && (v_cntr_reg == V_MAX - 1))
            v_cntr_reg <= '0;
        else if (h_cntr_reg == H_MAX - 1)
            v_cntr_reg <= v_cntr_reg + 1'b1;
    end

    // Sync Sinyalleri
    always_ff @(posedge pxl_clk) begin
        if ((h_cntr_reg >= H_FP + FRAME_WIDTH - 1) && (h_cntr_reg < H_FP + FRAME_WIDTH + H_PW - 1))
            h_sync_reg <= H_POL;
        else
            h_sync_reg <= ~H_POL;

        if ((v_cntr_reg >= V_FP + FRAME_HEIGHT - 1) && (v_cntr_reg < V_FP + FRAME_HEIGHT + V_PW - 1))
            v_sync_reg <= V_POL;
        else
            v_sync_reg <= ~V_POL;
    end

    // Active Region (Görüntülenebilir Alan)
    assign active = (h_cntr_reg_dly < FRAME_WIDTH) && (v_cntr_reg_dly < FRAME_HEIGHT);

    // Dinamik Hareketli Arka Plan (Moving Colorbar - OOB Demo Ýle Birebir)
    logic [27:0] cntDyn = '0;
    always_ff @(posedge pxl_clk) cntDyn <= cntDyn + 1'b1;

    logic [3:0] bg_red, bg_green, bg_blue;
    logic [3:0] bg_red_dly, bg_green_dly, bg_blue_dly;

 // Alternatif & En Saðlam Yöntem
    logic [7:0] calc_red, calc_green, calc_blue;

    always_comb begin
        calc_red   = - v_cntr_reg - h_cntr_reg - cntDyn[27:20];
        calc_green =   h_cntr_reg - cntDyn[27:20];
        calc_blue  =   v_cntr_reg - cntDyn[27:20];

        bg_red   = calc_red[7:4];
        bg_green = calc_green[7:4];
        bg_blue  = calc_blue[7:4];
    end

    // Mikrofon Gösterim Modülü Örneklemesi (Instantiation)
    logic [3:0] mic_red, mic_green, mic_blue;
    logic [3:0] mic_red_dly, mic_green_dly, mic_blue_dly;

    mic_display #(
        .X_WIDTH(SZ_MIC_WIDTH),
        .Y_HEIGHT(SZ_MIC_HEIGHT),
        .X_START(FRM_MIC_H_LOC),
        .Y_START(FRM_MIC_V_LOC),
        .PXLCLK_FREQ_HZ(108000000),
        .H_MAX(H_MAX),
        .SAMPLE_RATE_DIV(4096)
    ) inst_mic_display (
        .clk_i(pxl_clk),
        .sysclk(sysclk),
        .mic_m_data_i(mic_data),
        .mic_m_clk_rising(mic_clk_rising),
        .h_count_i(h_cntr_reg),
        .v_count_i(v_cntr_reg),
        .red_o(mic_red),
        .green_o(mic_green),
        .blue_o(mic_blue)
    );

    // Sinyalleri 1 Saat Geciktirme (Pipeline Alignment)
    always_ff @(posedge pxl_clk) begin
        mic_red_dly   <= mic_red;
        mic_green_dly <= mic_green;
        mic_blue_dly  <= mic_blue;

        bg_red_dly    <= bg_red;
        bg_green_dly  <= bg_green;
        bg_blue_dly   <= bg_blue;

        h_cntr_reg_dly <= h_cntr_reg;
        v_cntr_reg_dly <= v_cntr_reg;
    end

    // Ana RGB Multiplexer
    logic [3:0] vga_red_cmb, vga_green_cmb, vga_blue_cmb;

    always_comb begin
        if (h_cntr_reg_dly > MIC_LEFT && h_cntr_reg_dly < MIC_RIGHT &&
            v_cntr_reg_dly > MIC_TOP  && v_cntr_reg_dly < MIC_BOTTOM) begin
            vga_red_cmb   = mic_red_dly;
            vga_green_cmb = mic_green_dly;
            vga_blue_cmb  = mic_blue_dly;
        end else begin
            vga_red_cmb   = bg_red_dly;
            vga_green_cmb = bg_green_dly;
            vga_blue_cmb  = bg_blue_dly;
        end
    end

    // Aktif Ekran Bölgesi Maskelemesi ve Çýkýþ Kaydedicileri
    logic [3:0] vga_red_reg, vga_green_reg, vga_blue_reg;

    always_ff @(posedge pxl_clk) begin
        v_sync_reg_dly <= v_sync_reg;
        h_sync_reg_dly <= h_sync_reg;

        vga_red_reg   <= active ? vga_red_cmb   : 4'h0;
        vga_green_reg <= active ? vga_green_cmb : 4'h0;
        vga_blue_reg  <= active ? vga_blue_cmb  : 4'h0;
    end

    assign vga_hs = h_sync_reg_dly;
    assign vga_vs = v_sync_reg_dly;
    assign vga_r  = vga_red_reg;
    assign vga_g  = vga_green_reg;
    assign vga_b  = vga_blue_reg;

endmodule