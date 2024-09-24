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
    parameter IDLE = 4'b0000, // 0
              SOF_TRANSMISSION   = 4'b0001, 
              ARBITRATION        = 4'b0010, 
              CONTROL_FIELD_TX   = 4'b0011, 
              DATA_FIELD         = 4'b0100, 
              CRC_TRANSMISSION   = 4'b0101, //includes CRC_FIELD and CRC_delimeter
              ACK_FIELD          = 4'b0110,//includes the ACK_SLOT and ACK_DELIMETER
              EOF_TRANSMISSION   = 4'b0111, 
              IFS_TRANSMISSION   = 4'b1000, 
              ERROR_CHECK        = 4'b1001;

    reg [3:0] state, next_state;    // State register
    reg [4:0] bit_counter;          // Bit counter for the arbitration and frame transmission
    reg arbitration_won;            // Indicates if arbitration is won
    reg crc_valid;                  // CRC valid signal
    reg [15:0] crc;                 // CRC calculated value
    reg ack_check;                  // Signal to check for ACK
    reg [3:0] retransmission_count; // Counter for retransmission attempts
    parameter MAX_RETRANSMISSIONS = 4; // Maximum number of retransmissions

    reg crc_start;
    wire [15:0] crc_output;
    wire crc_done;
    
    lpset6 crc_module (
        .clock(clk),
        .start(crc_start),
        .data(tx_bus),  // Assuming tx_bus is the input data stream
        .done(crc_done),
        .r(crc_output)
    );


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
            bit_counter <= 0;
            crc_valid <=0;
            ack_check<=0;
            retransmission_count <= 0;
            state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    arbitration_won <='b0;
                    arbitration_lost <= 1'b0;
                    ack_received <= 1'b0;
                    error_flag <= 1'b0;
                    bit_counter <= 0;                                       //bit_counter = 0
//we need to evaluate the IDLE state as we are redirecting the all the states after the failuers and it bus wont be containis the 111 in the middle of the transmission
                    if (bus_idle == 111) begin
                        state <= SOF_TRANSMISSION;
                    end else begin
                        state <=IDLE;
                    end
                end

                SOF_TRANSMISSION:begin
                    if(bit_counter <= 0)begin
                        tx_bus <= 'b0;
                        state <= ARBITRATION; 
                    end else begin
                        $display("error in sof_transmission state");
                        state <= ERROR_CHECK;
                    end
                    bit_counter <= bit_counter + 1;                         //bit_counter = 1;
                end

                ARBITRATION: begin
                    if (bit_counter <= 11 && bit_counter >= 1) begin        //bit_counter starts at 1 and ends at 11
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
                        bit_counter <= bit_counter + 1;                 //bit counter = 12
                    end  else begin
                        $display("error in the arbitration field");
                        state <= ERROR_CHECK;
                    end     
            end



//begin of the control field
                CONTROL_FIELD_TX: begin
                    if (bit_counter == 12) begin
                        tx_bus <= RTR;
                        bit_counter = bit_counter + 1;                  //bitcounter =13
                        
                    end
                    if(bit_counter == 13) begin
                        tx_bus <= IDE_BIT;
                        bit_counter = bit_counter +1;                   //bitcounter = 14
                        
                    end
                    if(bit_counter == 14)begin
                        tx_bus <= reserve;    //reserve have to be defined by used or default 
                        bit_counter = bit_counter +1;                   //bitcounter = 15
                        
                    end
                    if(arbitration_won && bit_counter >= 15 && bit_counter <19)begin
                        tx_bus <=dlc[19 - (bit_counter+1)];
                        bit_counter = bit_counter + 1;                  //bitcounter = 19 at the fourth round of this 
                       
                    end   
                end


//DATA field starts here

                DATA_FIELD: begin
                    if(bit_counter >=19 && bit_counter < (19+dlc*8))begin
                        tx_bus <= data[(dlc*8-1) - (bit_counter-19) ];
                        bit_counter = bit_counter + 1;
                        
                    end else if(bit_counter == (19+dlc*8)) begin
                        bit_counter = bit_counter +1;
                        crc_start <= 1;
                        state = CRC_TRANSMISSION;
                        $display("Data transmission completed, starting CRC transmission");
                    end else if( bit_counter > (20+dlc*8)) begin
                        $display("error transmitting the data field -------> error in the data field");
                        state = IDLE;
                    end
                end



//CRC field starts here

                CRC_TRANSMISSION:begin
                    if(bit_counter >= (19+(dlc*8)) && bit_counter < (19+16+(dlc*8)))begin
                        tx_bus = crc_output[(16-1)-(bit_counter-(19+dlc*8))];
                        bit_counter = bit_counter + 1;
                        
                    end else if(bit_counter == (19+16+(dlc*8)+1)) begin
                        tx_bus = 'b1;
                        state = ACK_FIELD;
                    end else begin
                        $display("error transmitting the crc bits");
                        state = IDLE;
                    end
                end



//ACK field starts here

                ACK_FIELD: begin
                    if(bit_counter == (19+16+(dlc*8)+2)) begin
                        if(rx_bus == 'b0 )begin
                            $display("acknowledgment received");
                            ack_received <= 'b1;
                            bit_counter = bit_counter +1;
                            state = EOF_TRANSMISSION;
                        end else begin
                            $display("acknowledgment not received");
                            ack_received <= 'b0;
                            state = IDLE
                        end
                    end else begin
                        $display("error in the bit_counter ft- ack field");
                        state = IDLE;
                    end
                end
                


//EOF field starts here

                EOF_TRANSMISSION: begin
                    if(bit_counter == (19+16+(dlc*8)+3)) begin
                        tx_bus = 'b1;
                        bit_counter = bit_counter+1;
                        state = IFS_TRANSMISSION;
                    end else begin
                        state = IDLE;
                    end
                end



//IFS field starts here
                IFS_TRANSMISSION: begin
                    if(bit_counter <= (19+16+(dlc*8)+6) ) begin
                        tx_bus = 'b1;
                        bit_counter = bit_counter+1;
                        state = IFS_TRANSMISSION;
                    end else begin
                        state = IDLE;
                    end
                end


//error_check _field starts here
                ERROR_CHECK:begin
                   error_flag <='b1;
                   state<=IDLE;
                end


//defalult starts here
                default: state <= IDLE;
            endcase
        end
    end

endmodule
