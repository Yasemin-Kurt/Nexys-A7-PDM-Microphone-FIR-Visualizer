`timescale 1ns / 1ps

module seven_segment_ctrl (
    input  logic       clk_100mhz, // 100 MHz Ana Saat
    input  logic [8:0] sample_val, // Anlýk Ses Genliði (0 - 375)
    output logic [7:0] seg,        // Segment Çýkýþlarý (CA, CB, CC, CD, CE, CF, CG, DP)
    output logic [7:0] an         // Anot Çýkýþlarý (AN0 - AN7)
);

    // Display Taramasý Ýçin Sayaç (~1 kHz Tarama Hýzý)
    logic [16:0] refresh_counter = '0;
    always_ff @(posedge clk_100mhz) begin
        refresh_counter <= refresh_counter + 1'b1;
    end

    // Aktif Hane Seçimi (0 - 7)
    wire [2:0] active_digit = refresh_counter[16:14];

    // Anot Mantýðý (Active Low - '0' olan hane yanar)
    always_comb begin
        an = 8'b1111_1111;        // Hepsini kapat
        an[active_digit] = 1'b0;  // Sadece sýradaki haneyi aç
    end

    // Segment Tanýmlarý (Active Low - '0' olan segment yanar)
    // Bit Dizilimi: [7]=DP, [6]=CG(Orta), [5]=CF, [4]=CE, [3]=CD(Alt), [2]=CC, [1]=CB, [0]=CA(Üst)
    
    logic [7:0] seg_pattern;

    always_comb begin
        // Eþik deðerlerini daha hassas ayarladýk:
        if (sample_val > 85) begin
            // Yüksek Ses: Üst (CA) + Orta (CG) + Alt (CD) Çizgi  --> ?
            // CA=0, CG=0, CD=0, DP=1 (Nokta Kapalý)
            seg_pattern = 8'b1011_0110; 
        end else if (sample_val > 70) begin
            // Orta Ses: Orta (CG) + Alt (CD) Çizgi  --> =
            // CG=0, CD=0, DP=1
            seg_pattern = 8'b1011_0111; 
        end else begin
            // CD=0, DP=1
            seg_pattern = 8'b1111_0111; 
        end
    end

    assign seg = seg_pattern;

endmodule