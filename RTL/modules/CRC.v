module lpset6(
    input clock,          // Clock signal
    input start,          // Start signal to initiate the process
    input data,           // Data input (MSB first)
    output done,          // Done flag when the operation is complete
    output reg [15:0] r   // 16-bit register for CRC calculation
);

// Define FSM states
parameter IDLE = 0;
parameter CRC_CALC = 1;

// Internal signals
wire x16 = data;         // Input data
reg [5:0] counter = 0;   // Counter for FSM
reg state = IDLE;        // State register for FSM

// Sequential logic for FSM
always @(posedge clock) begin
    case (state)
        IDLE: begin
            if (start) begin
                state <= CRC_CALC;      // Move to CRC_CALC state if start is asserted
                r <= 16'hFFFF;          // Reset CRC register to initial value
                counter <= 47;          // Initialize counter for 48-bit data processing
            end else begin
                state <= IDLE;          // Remain in IDLE state if start is not asserted
            end
        end
        
        CRC_CALC: begin
            r[15] <= r[14] ^ x16;       // XOR with data and shift bits for CRC calculation
            r[14:3] <= r[13:2];         // Shift bits
            r[2] <= r[1] ^ r[15] ^ x16; // Continue CRC calculation
            r[1] <= r[0];               // Shift bits
            r[0] <= r[15] ^ x16;        // Update the least significant bit
            
            // Decrement counter
            counter <= counter - 1;
            
            // Transition to IDLE when counter reaches 0
            if (counter == 1) begin
                state <= IDLE;
            end else begin
                state <= CRC_CALC;
            end
        end
    endcase
end

// Output done signal when counter reaches 0
assign done = (counter == 0);

endmodule
