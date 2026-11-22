`timescale 1ns / 1ps

module mic_display #(
    parameter integer X_WIDTH        = 915,
    parameter integer Y_HEIGHT       = 375,
    parameter integer X_START        = 25,
    parameter integer Y_START        = 615,
    parameter integer PXLCLK_FREQ_HZ = 108000000,
    parameter integer H_MAX          = 1688,
    parameter integer SAMPLE_RATE_DIV= 4096,
    parameter logic [11:0] BG_COLOR    = 12'hFFF, // Beyaz
    parameter logic [11:0] ACTIVE_COLOR= 12'h008  // Koyu Mavi Dalga
)(
    input  logic        clk_i,             // 108 MHz Pixel Clock
    input  logic        sysclk,            // 100 MHz Sistem Saati
    input  logic        mic_m_data_i,      // PDM Data
    input  logic        mic_m_clk_rising,  // 100 MHz domain yükselen kenar
    input  logic [11:0] h_count_i,
    input  logic [11:0] v_count_i,
    output logic [3:0]  red_o,
    output logic [3:0]  green_o,
    output logic [3:0]  blue_o
);

    localparam integer SAMPLE_OFFSET = 105;
    localparam integer MIC_LEFT   = X_START - 1;
    localparam integer MIC_RIGHT  = X_START + X_WIDTH + 1;
    localparam integer MIC_TOP    = Y_START - 1;
    localparam integer MIC_BOTTOM = Y_START + Y_HEIGHT + 1;

    localparam integer SAMPLE_WIDTH = $clog2(Y_HEIGHT);
    localparam integer SR_WIDTH     = Y_HEIGHT;

    // Buffer boyutu hesaplamalarý (OOB Demo ile birebir)
    localparam integer BUF_PADDING_NEEDED = integer'( $ceil( (real'(Y_HEIGHT) * real'(H_MAX)) / real'(SAMPLE_RATE_DIV) ) );
    localparam integer BUF_DEPTH_NEEDED   = X_WIDTH + BUF_PADDING_NEEDED;
    localparam integer BUF_ADDR_WIDTH     = $clog2(BUF_DEPTH_NEEDED);
    localparam integer BUF_DEPTH          = 2**BUF_ADDR_WIDTH;
    localparam integer BUF_PADDING        = BUF_DEPTH - X_WIDTH;

    // Dual-Port Block RAM Tanýmý (Inferred Block RAM)
    (* ram_style = "block" *) logic [SAMPLE_WIDTH-1:0] sample_buf_ram [0:BUF_DEPTH-1];

    logic en_wr_sample_buf_ram;
    logic [SAMPLE_WIDTH-1:0] rd_data;

    logic [BUF_ADDR_WIDTH-1:0] wr_addr_reg        = '0;
    logic [BUF_ADDR_WIDTH-1:0] rd_addr_reg        = '0;
    logic [BUF_ADDR_WIDTH-1:0] rd_frame_start_reg = '0;

    // 100 MHz Saatten PDM Kenarýný Senkronize Etme
    logic syncasync_out;
    logic sync1, sync0, sync_r, mic_m_clk_rising_os;

    sync_async #(
        .K_RESET_TO(1'b0),
        .K_STAGES(2)
    ) sync_inst (
        .aReset(1'b0),
        .aIn(mic_m_clk_rising),
        .OutClk(clk_i),
        .oOut(syncasync_out)
    );

    always_ff @(posedge clk_i) begin
        sync1  <= syncasync_out;
        sync0  <= sync1;
        sync_r <= sync0;
    end

    assign mic_m_clk_rising_os = sync0 & (~sync_r);

    // Sample Rate Timer (100 MHz Domain)
    integer clk_cntr_reg = 0;
    always_ff @(posedge sysclk) begin
        if (clk_cntr_reg == SAMPLE_RATE_DIV - 1)
            clk_cntr_reg <= 0;
        else
            clk_cntr_reg <= clk_cntr_reg + 1;
    end

    assign en_wr_sample_buf_ram = (clk_cntr_reg == SAMPLE_RATE_DIV - 1) ? 1'b1 : 1'b0;

    // Demodülasyon Yazmacý
    logic [SR_WIDTH-1:0]     mic_sr_reg = '0;
    logic [SAMPLE_WIDTH-1:0] sample_reg = '0;

    always_ff @(posedge clk_i) begin
        if (mic_m_clk_rising_os) begin
            mic_sr_reg <= {mic_sr_reg[SR_WIDTH-2:0], mic_m_data_i};

            if ((mic_sr_reg[SR_WIDTH-1] == 1'b0) && (mic_m_data_i == 1'b1))
                sample_reg <= sample_reg + 3'd3;
            else if ((mic_sr_reg[SR_WIDTH-1] == 1'b1) && (mic_m_data_i == 1'b0))
                sample_reg <= sample_reg - 3'd3;
        end
    end

    // RAM Yazma Adres Sayacý
    always_ff @(posedge clk_i) begin
        if (en_wr_sample_buf_ram) begin
            if (wr_addr_reg == BUF_DEPTH - 1)
                wr_addr_reg <= '0;
            else
                wr_addr_reg <= wr_addr_reg + 1'b1;
        end
    end

    // Çerçeve Yýrtýlmasýný (Tearing) Önleyen Okuma Baþlangýç Adresi Tespiti
    always_ff @(posedge clk_i) begin
        if (h_count_i == 0 && v_count_i == Y_START) begin
            if ((wr_addr_reg + BUF_PADDING) >= BUF_DEPTH)
                rd_frame_start_reg <= (wr_addr_reg + BUF_PADDING) - BUF_DEPTH;
            else
                rd_frame_start_reg <= (wr_addr_reg + BUF_PADDING);
        end
    end

    // RAM Okuma Adresi Sayacý
    always_ff @(posedge clk_i) begin
        if (h_count_i == (X_START - 1))
            rd_addr_reg <= rd_frame_start_reg;
        else if (rd_addr_reg == BUF_DEPTH - 1)
            rd_addr_reg <= '0;
        else
            rd_addr_reg <= rd_addr_reg + 1'b1;
    end

    // Block RAM Okuma/Yazma Ýþlemi
    always_ff @(posedge clk_i) begin
        if (en_wr_sample_buf_ram)
            sample_buf_ram[wr_addr_reg] <= sample_reg + SAMPLE_OFFSET;
        
        rd_data <= sample_buf_ram[rd_addr_reg];
    end

    // Renk Karþýlaþtýrma Mantýðý (Dalga Genliði Çizimi)
    logic [11:0] color_out;
    always_comb begin
        if ((((v_count_i - Y_START) - rd_data) <= 3) || (((rd_data + Y_START) - v_count_i) <= 3))
            color_out = ACTIVE_COLOR;
        else
            color_out = BG_COLOR;
    end

    // Çýkýþ Atamalarý
    always_comb begin
        if ((h_count_i > MIC_LEFT && h_count_i < MIC_RIGHT) &&
            (v_count_i > MIC_TOP  && v_count_i < MIC_BOTTOM)) begin
            red_o   = color_out[11:8];
            green_o = color_out[7:4];
            blue_o  = color_out[3:0];
        end else begin
            red_o   = 4'hF;
            green_o = 4'hF;
            blue_o  = 4'hF;
        end
    end

endmodule