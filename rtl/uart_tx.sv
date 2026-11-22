`timescale 1ns / 1ps

module uart_tx #(
    parameter integer CLK_FREQ  = 100_000_000, // 100 MHz Sistem Saati
    parameter integer BAUD_RATE = 115_200      // 115200 Baud Rate
)(
    input  logic       clk,         // 100 MHz Sistem Saati
    input  logic       reset,       // Sýfýrlama
    input  logic       tx_start,    // Veri Gönderme Tetiklemesi (Pulse)
    input  logic [7:0] tx_data,     // Gönderilecek 8-Bitlik Veri
    output logic       tx,          // FPGA UART_TX Çýkýþ Pini (D4)
    output logic       tx_busy      // Veri Gönderilirken 1 Olur
);

    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE; // ~868 clock döngüsü

    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        START = 2'b01,
        DATA  = 2'b10,
        STOP  = 2'b11
    } state_t;

    state_t state = IDLE;

    logic [15:0] clk_count = '0;
    logic [2:0]  bit_index = '0;
    logic [7:0]  tx_data_reg = '0;
    logic        tx_reg = 1'b1;

    assign tx = tx_reg;

    always_ff @(posedge clk) begin
        if (reset) begin
            state     <= IDLE;
            clk_count <= '0;
            bit_index <= '0;
            tx_reg    <= 1'b1;
            tx_busy   <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    tx_reg   <= 1'b1;
                    tx_busy  <= 1'b0;
                    clk_count <= '0;
                    bit_index <= '0;

                    if (tx_start) begin
                        tx_data_reg <= tx_data;
                        tx_busy     <= 1'b1;
                        state       <= START;
                    end
                end

                START: begin
                    tx_reg <= 1'b0; // Start bit = '0'

                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= '0;
                        state     <= DATA;
                    end
                end

                DATA: begin
                    tx_reg <= tx_data_reg[bit_index]; // LSB'den baþlayarak gönder

                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= '0;
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1'b1;
                        end else begin
                            bit_index <= '0;
                            state     <= STOP;
                        end
                    end
                end

                STOP: begin
                    tx_reg <= 1'b1; // Stop bit = '1'

                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= '0;
                        state     <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule