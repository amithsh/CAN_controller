module bit_timing_module (
    input wire clk,               // System clock
    input wire rst,               // Reset signal
    input wire [7:0] tq,          // Time Quantum (TQ) from Baud Rate Prescaler
    output reg sample_point,      // Signal to indicate the sampling point in the bit time
    output reg bit_end            // Signal to indicate the end of the bit
);

    // // Bit timing segments (assigning values based on typical CAN configurations)
    // parameter Sync_Seg  = 1;      // Sync Segment = 1 TQ (fixed)
    // parameter Prop_Seg  = 5;      // Propagation Segment (can be adjusted)
    // parameter Phase_Seg1 = 6;     // Phase Segment 1 (can be adjusted)
    // parameter Phase_Seg2 = 4;     // Phase Segment 2 (can be adjusted)



    wire [7:0] prop_seg;
    wire [7:0] phase_seg1;
    wire [7:0] phase_seg2;
    wire [7:0] sync_seg;



    bit_timing_module_params timing_params (
        .config_data(8'b0), // Config data can be passed for dynamic configuration
        .prop_seg(prop_seg),
        .phase_seg1(phase_seg1),
        .phase_seg2(phase_seg2),
        .sync_seg(sync_seg)
    );

    // Total number of Time Quanta per bit
    localparam TOTAL_TQ = Sync_Seg + Prop_Seg + Phase_Seg1 + Phase_Seg2;

    reg [7:0] tq_counter;         // Counter to track TQ

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tq_counter <= 8'd0;
            sample_point <= 1'b0;
            bit_end <= 1'b0;
        end else begin
            if (tq_counter < (TOTAL_TQ * tq)) begin
                tq_counter <= tq_counter + 1;
                
                // Detect sample point (end of Phase_Seg1)
                if (tq_counter == ((Sync_Seg + Prop_Seg + Phase_Seg1) * tq)) begin
                    sample_point <= 1'b1;
                end else begin
                    sample_point <= 1'b0;
                end

                // Detect end of bit time (end of Phase_Seg2)
                if (tq_counter == (TOTAL_TQ * tq)) begin
                    bit_end <= 1'b1;
                    tq_counter <= 8'd0;  // Reset counter for next bit
                end else begin
                    bit_end <= 1'b0;
                end
            end
        end
    end

endmodule
