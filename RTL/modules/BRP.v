module baud_rate_prescaler (
    input wire clk,              // Clock input
    input wire rst,              // Reset input
    input wire [31:0] baud_rate,  // Configurable baud rate
    
    input wire [31:0] sys_clk_freq,
    output reg [7:0] tq    // Time Quantum output
    output reg [15:0] brp,

);

    integer n_tq;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            brp<=0;
            tq <= 8'd0; // Reset TQ
        end else begin
            n_tq = 16;

            //calculate the brp
            brp <= sys_clk_freq/(baud_rate*n_tq);

            //time quant base on the brp
            tq<= brp/sys_clk_freq;
        
        end
    end

endmodule

