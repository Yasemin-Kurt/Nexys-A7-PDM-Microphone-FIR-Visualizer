`timescale 1ns / 1ps

module sync_async #(
    parameter bit     K_RESET_TO = 1'b0,
    parameter integer K_STAGES   = 2
)(
    input  logic aReset,
    input  logic aIn,
    input  logic OutClk,
    output logic oOut
);

    (* ASYNC_REG = "TRUE" *) logic [K_STAGES-1:0] sync_regs;

    always_ff @(posedge OutClk or posedge aReset) begin
        if (aReset) begin
            sync_regs <= {K_STAGES{K_RESET_TO}};
        end else begin
            sync_regs <= {sync_regs[K_STAGES-2:0], aIn};
        end
    end

    assign oOut = sync_regs[K_STAGES-1];

endmodule