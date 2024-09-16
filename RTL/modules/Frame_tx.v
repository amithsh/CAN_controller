module can_frame_transmitter (
    input wire clk,
    input wire rst,
    input wire [10:0] message_id,   // Message ID for arbitration
    input wire RTR,                  //RTR bit for the indication of the data bit or the remote bit
    input wire IDE_BIT              //indication for the standard or the extetnded CAN
    input wire [8*8-1:0] data,          // Data to be transmitted
    input wire [3:0] dlc,           // Data Length Code (DLC)
    input wire rx_bus,              // Bus value to check during arbitration
    input wire [2:0]bus_idle,       //indication of the bus is idle (includes the 3 bit recessive bits)
    output reg tx_bus,              // Transmit to CAN bus
    output reg ack_received,        // Acknowledgment received
    output reg arbitration_lost,    // Indicates if arbitration is lost
    output reg error_flag           // Error flag for transmission issues
);

    // State encoding for frame transmission
    parameter IDLE = 3'b000, // 0
              SOF_TRANSMISSION   = 4'b0001, 
              ARBITRATION        = 4'b0010, 
              CONTROL_FIELD_TX   = 4'b0011, 
              DATA_FIELD         = 4'b0100, 
              CRC_TRANSMISSION   = 4'b0101, //includes CRC_FIELD and CRC_delimeter
              ACK_FIELD          = 4'b0110,//includes the ACK_SLOT and ACK_DELIMETER
              EOF_TRANSMISSION   = 4'b0111, 
              IFS_TRANSMISSION   = 4'b1000, 
              ERROR_CHECK        = 4'b1001

    reg [2:0] state, next_state;    // State register
    reg [4:0] bit_counter;          // Bit counter for the arbitration and frame transmission
    reg arbitration_won;            // Indicates if arbitration is won
    reg crc_valid;                  // CRC valid signal
    reg [15:0] crc;                 // CRC calculated value
    reg ack_check;                  // Signal to check for ACK
    reg [3:0] retransmission_count; // Counter for retransmission attempts
    parameter MAX_RETRANSMISSIONS = 4; // Maximum number of retransmissions

    // CRC Calculation (Assumed to be pre-calculated for simplicity)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            crc <= 16'b0;  // Reset CRC
        end else if (state == FRAME_TRANSMISSION) begin
            // Calculate CRC based on the transmitted data and other parts of the frame
            // Implement the actual CRC calculation logic here based on your CAN protocol
        end
    end

    // Arbitration Logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            arbitration_won <= 1'b0;
            arbitration_lost <= 1'b0;
            state <= IDLE;
            bit_counter <= 0;
            crc_valid <=0;
            ack_check<=0;
            retransmission_count <= 0;
        end else begin
            case (state)
                IDLE: begin
                    arbitration_won <='b0;
                    arbitration_lost <= 1'b0;
                    ack_received <= 1'b0;
                    error_flag <= 1'b0;
                    if (bus_idle === 111) begin
                        state <= SOF_TRANSMISSION;
                        bit_counter <= 0;
                    end
                end

                SOF_TRANSMISSION:begin
                    if(bit_counter <= 0)begin
                        tx_bus <= 'b0;
                       
                        state <= ARBITRATION; 
                    end else begin
                        state <= IDLE;
                    end
                    bit_counter <= bit_counter + 1;
                end

                ARBITRATION: begin
                    if (bit_counter < 12 && bit_counter > 0) begin
                        // Transmit each bit of message ID
                        tx_bus <= message_id[11 - bit_counter]; 

                        // Check the bus to see if we lost arbitration
                        if (message_id[11 - bit_counter] == 1'b1 && rx_bus == 1'b0) begin
                            // Lost arbitration: we transmitted a recessive bit (1)
                            // but the bus reads a dominant bit (0)
                            arbitration_lost <= 1'b1;
                            arbitration_won <= 'b0;
                            state <= IDLE;  // Return to IDLE after losing arbitration
                        end else if (bit_counter == 11) begin
                            // Won arbitration if no mismatch detected
                            arbitration_won <= 1'b1;
                            arbitration_lost <='b0;
                            if(IDE_BIT == 'b0)begin
                                bit_counter = bit_counter + 1;
                                state <= CONTROL_FIELD_TX;
                            end
                        end
                        bit_counter <= bit_counter + 1;
                    end       
            end



//begin of the control field
                CONTROL_FIELD_TX: begin
                    if (bit_counter == 12) begin
                        tx_bus <= RTR;
                        bit_counter = bit_counter + 1;
                        state <= CONTROL_FIELD_TX;
                    end
                    if(bit_counter == 13) begin
                        tx_bus <= IDE_BIT;
                        bit_counter = bit_counter +1;
                        state <=CONTROL_FIELD_TX;
                    end
                    if(bit_counter == 14)begin
                        tx_bus <= reserve;    //reserve have to be defined by used or default 
                        bit_counter = bit_counter +1;
                        state <= CONTROL_FIELD_TX;
                    end
                    if(arbitration_won && bit_counter >= 15 && bit_counter < 20)begin
                        tx_bus <=dlc[20 - bit_counter-1];
                        bit_counter = bit_counter + 1;
                        state = CONTROL_FIELD_TX;
                    end   
                end


//DATA field starts here

                DATA_FIELD: begin
                    if(bit_counter >=20 && bit_counter < (20+dlc*8))begin
                        tx_bus <= data[(dlc*8-1) - bit_counter-20 ];
                        bit_counter = bit_counter + 1;
                        state = DATA_FIELD;
                    end else if(bit_counter == (20+dlc*8)) begin
                        bit_counter = bit_counter +1;
                        state = CRC_TRANSMISSION;
                        $display("error transmitting the data bits");
                    end else if( bit_counter > (20+dlc*8)) begin
                        $display("error transmitting the data field -------> error in the data field");
                        state = IDLE;
                    end
                end



//CRC field starts here

                CRC_TRANSMISSION:begin

                    

                end




//ACK field starts here






//EOF field starts here






//IFS field starts here
                FRAME_TRANSMISSION: begin
                    if (arbitration_won) begin
                     // Transmit the DLC (Data Length Code) after arbitration, starting after the 11-bit message ID
                    if (bit_counter >= 11 && bit_counter < 15) begin
                    tx_bus <= dlc[14 - bit_counter];  // DLC is 4 bits
                    end else if (bit_counter >= 15 && bit_counter < (15 + dlc * 8)) begin
                    // Transmit data bits based on the DLC (number of bytes in the frame)
                    tx_bus <= data[(dlc * 8 - 1) - (bit_counter - 15)];
                    end else if (bit_counter >= (15 + dlc * 8)) begin
                    // Once data is transmitted, move to CRC transmission
                    state <= CRC_TRANSMISSION;
                    end

        // Keep incrementing the bit counter for continuous frame transmission
        bit_counter <= bit_counter + 1;
    end
end

                CRC_TRANSMISSION: begin
    // Assuming the CRC is 15 bits long and starts transmitting after the data frame
    if (bit_counter >= (15 + dlc * 8) && bit_counter < (15 + dlc * 8 + 15)) begin
        tx_bus <= crc[(15 + dlc * 8 + 15 - 1) - bit_counter];  // Transmit CRC bit by bit
    end else if (bit_counter == (15 + dlc * 8 + 15)) begin
        state <= ACK_WAIT;  // Transition to acknowledgment wait state after CRC transmission
    end

    // Continue incrementing bit_counter through CRC transmission
    bit_counter <= bit_counter + 1;
end

                ACK_WAIT: begin

                     bit_counter <= bit_counter + 1;

                    if (bit_counter < 32) begin
                    // Assume we're checking for a fixed duration; adjust as needed
                     if (rx_bus == 1'b0) begin  // ACK received (dominant bit)
                     ack_received <= 1'b1;
                     ack_check <= 1'b1;  // Indicate that we are checking for acknowledgment
                end else begin
                     ack_received <= 1'b0;
                     ack_check <= 1'b0;  // No acknowledgment received
                end
                end

                    if (bit_counter >= 32) begin
                    // Move to the ERROR_CHECK state if acknowledgment is not received or other issues are detected
                    if (ack_check == 1'b0) begin
                    // No acknowledgment received, flag as error
                    crc_valid <= 1'b1;
                    end
                    state <= ERROR_CHECK;
                end
                end

                ERROR_CHECK: begin
                    // Handle CRC errors, etc.
                    if (crc_valid == 1'b0) begin  // Assume CRC error
                        error_flag <= 1'b1;
                    end
                    ERROR_CHECK: begin
                    // Handle CRC errors, etc.
                    if (error_flag == 1'b1) begin
                        // Retry transmission if errors are detected
                        if (retransmission_count < MAX_RETRANSMISSIONS) begin
                            retransmission_count <= retransmission_count + 1;
                            state <= ARBITRATION;  // Re-attempt arbitration
                        end else begin
                            // Max retransmissions reached, return to IDLE
                            state <= IDLE;
                        end
                    end else begin
                        // If no error flag set, just go back to IDLE
                        state <= IDLE;
                    end
                    // Reset bit_counter for the next transmission attempt
                    bit_counter <= 0;
                end
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
