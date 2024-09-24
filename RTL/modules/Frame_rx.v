module can_frame_receiver (
    input wire clk,
    input wire rst,
    input wire rx_bus,           // Input from CAN bus (received bit stream)
    output reg [10:0] message_id, // Received message ID for arbitration
    output reg [7:0] data,        // Received data
    output reg [3:0] dlc,         // Received Data Length Code (DLC)
    output reg crc_error,         // CRC error flag
    output reg ack_received,      // Acknowledgment flag
    output reg frame_received     // Indicates if a valid frame was received
);

    // State encoding for the receiver
    parameter IDLE = 3'b000,
              SOF_DETECTION = 3'b001,
              ARBITRATION = 3'b010,
              CONTROL_FIELD = 3'b011,
              DATA_FIELD = 3'b100,
              CRC_CHECK = 3'b101,
              ACK_SLOT = 3'b110;

    reg [2:0] state, next_state;  // State register
    reg [4:0] bit_counter;        // Bit counter for receiving fields
    reg [15:0] crc_received;      // Received CRC
    reg [15:0] crc_calculated;    // Calculated CRC
    reg [10:0] id_buffer;         // Temporary storage for message ID
    reg [7:0] data_buffer;        // Temporary storage for data

     // CRC module control signals
    reg crc_start;
    wire crc_done;
    wire [15:0] crc_output;


    lpset6 crc_inst (
        .clock(clk),
        .start(crc_start),
        .data(rx_bus),  // Assuming rx_bus is the input data stream
        .done(crc_done),
        .r(crc_output)
    );


//this module is different from the transmitter bit as in this module the counter sets to 0 every time the new state encounters
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            bit_counter <= 0;
            crc_error <= 0;
            frame_received <= 0;
            ack_received <= 0;
            message_id <= 11'b0;
            data <= 8'b0;
            dlc <= 4'b0;
        end else begin
            case (state)

                // IDLE state: Wait for Start of Frame (SOF)
                IDLE: begin
                    frame_received <= 0;
                    crc_error <= 0;
                    ack_received <= 0;
                    if (rx_bus == 1'b0) begin  // SOF is a dominant bit (0)
                        state <= SOF_DETECTION;
                        bit_counter <= 0;
                    end
                end

                // SOF detection state
                SOF_DETECTION: begin
                    if (rx_bus == 1'b0) begin  // Ensure it's still SOF
                        state <= ARBITRATION;
                        bit_counter <= 0;
                    end else begin
                        state <= IDLE;  // Invalid SOF, return to IDLE
                    end
                end

                // Arbitration state: Receive 11-bit Message ID
                ARBITRATION: begin
                    if (bit_counter < 11) begin
                        id_buffer[10 - bit_counter] <= rx_bus;  // Shift message ID bits
                        bit_counter <= bit_counter + 1;
                    end else begin
                        message_id <= id_buffer;
                        state <= CONTROL_FIELD;
                        bit_counter <= 0;
                    end
                end

                // Control field state: Receive the DLC (4 bits)
                CONTROL_FIELD: begin
                    if (bit_counter < 4) begin
                        dlc[3 - bit_counter] <= rx_bus;  // Shift DLC bits
                        bit_counter <= bit_counter + 1;
                    end else begin
                        state <= DATA_FIELD;
                        bit_counter <= 0;
                    end
                end

                // Data field state: Receive data based on DLC
                DATA_FIELD: begin
                    if (bit_counter < dlc * 8) begin  // DLC determines the number of data bits
                        data_buffer[(dlc * 8 - 1) - bit_counter] <= rx_bus;
                        bit_counter <= bit_counter + 1;
                    end else begin
                        data <= data_buffer;  // Store the received data
                        state <= CRC_CHECK;
                        bit_counter <= 0;
                        crc_start <= 1'b1;  // Start CRC calculation
                    end
                end

                // CRC check state: Receive the 15-bit CRC and compare
                CRC_CHECK: begin
                    if (bit_counter < 15) begin
                        crc_received[14 - bit_counter] <= rx_bus;  // Shift CRC bits
                        bit_counter <= bit_counter + 1;
                    end else if (crc_done) begin  // Wait until CRC calculation is done
                        crc_calculated <= crc_output;
                        // Compare the received CRC with calculated CRC
                        if (crc_received != crc_calculated) begin
                            crc_error <= 1'b1;  // CRC mismatch, flag error
                        end else begin
                            crc_error <= 1'b0;  // CRC valid
                        end
                        state <= ACK_SLOT;
                        bit_counter <= 0;
                        crc_start <= 1'b0;  // Stop CRC calculation
                    end
                end

                // ACK slot state: Check for acknowledgment
                ACK_SLOT: begin
                    if (rx_bus == 1'b0) begin  // ACK received (dominant bit)
                        ack_received <= 1'b1;
                    end else begin
                        ack_received <= 1'b0;
                    end
                    frame_received <= 1'b1;  // Mark the frame as received
                    state <= IDLE;  // Return to IDLE for the next frame
                end

                default: state <= IDLE;

            endcase
        end
    end

endmodule
