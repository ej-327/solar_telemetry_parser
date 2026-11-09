`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/03/2026 09:52:03 AM
// Design Name: 
// Module Name: packet_fsm
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module packet_fsm (

    input wire i_Clock, //100Mhz Clock
    input wire i_Reset, // Synchronous active-high reset
    input wire [7:0] i_Rx_Byte, //Recieved UART Byte
    input wire i_Rx_DV, // one-cycle pulse from uart_rx
    
    output reg o_Pkt_Valid, //Accepted packet pulse
    output reg [7:0] o_Sensor_ID, //Channel ID
    output reg [15:0] o_Pkt_Data, //Measurement
    output reg o_Checksum_Err, //Checksum-rejection pulse
    output reg o_ID_Err //Invalid channel pulse
    
    );
    
    //FSM State encoding
    localparam [2:0]
        S_SYNC1 = 3'd0, 
        S_SYNC2 = 3'd1, 
        S_ID    = 3'd2, // Recieve and Validate sensor ID, Binary:010
        S_DATA  = 3'd3, // Recieve two data bytes, Binary:011
        S_CHECK = 3'd4; // Verify XOR Checksum, Binary:100
        
    //Current FSM State
    reg [2:0] r_State;
        
    //Packet Storage Registers
    reg [7:0] r_Sensor_ID;
    reg [7:0] r_Data_High;
    reg [7:0] r_Data_Low;
    reg [7:0] r_Checksum;
    
    //Tracks which payload byte arrives next
    reg r_Data_Phase;
    
always @(posedge i_Clock) begin

    if (i_Reset) begin
    
        //Return FSM to initial state
        r_State <= S_SYNC1;
        
        //Clear temporary packet storage
        r_Sensor_ID <= 8'd0;
        r_Data_High <= 8'd0;
        r_Data_Low  <= 8'd0;
        r_Checksum  <= 8'd0;
        r_Data_Phase <= 1'b0;
        
        //Clear output registers
        o_Pkt_Valid     <= 1'b0;
        o_Sensor_ID     <= 8'd0;
        o_Pkt_Data      <= 16'd0;
        o_Checksum_Err  <= 1'b0;
        o_ID_Err        <= 1'b0;
        
    end
    
    else begin 
        
        //Default: status pulses stay LOW
        o_Pkt_Valid     <= 1'b0;
        o_Checksum_Err  <= 1'b0;
        o_ID_Err        <= 1'b0;
        
        if (i_Rx_DV) begin
            
            case (r_State)
                
                S_SYNC1: begin
                
                    //Wait for first sync byte (0x1A)
                    if (i_Rx_Byte == 8'h1A)
                        r_State <= S_SYNC2;
                        
                end
                
                S_SYNC2: begin
                
                    //Wait for second sync byte
                    if (i_Rx_Byte == 8'hCF)
                        r_State <= S_ID;
                     
                    else if (i_Rx_Byte == 8'h1A)
                         r_State <= S_SYNC2;
                         
                    else
                        r_State <= S_SYNC1;
                end
                    
                S_ID: begin
                    
                    //Check whether valid Sensor ID
                    if ((i_Rx_Byte >= 8'h01) && (i_Rx_Byte <= 8'h04)) begin
                        
                        //Store accepted sensor ID
                        r_Sensor_ID <= i_Rx_Byte;
                        
                        //Initialize checksum
                        r_Checksum <= i_Rx_Byte;
                        
                        //first byte DATA_HIGH
                        r_Data_Phase <= 1'b0;
                        
                        //Move to payload-reading state
                        r_State <= S_DATA;
                    
            end
            else begin
                
                //Invalid sensor ID, reject packet
                o_ID_Err <= 1'b1;
                
                //Recover if this byte could be new sync
                if (i_Rx_Byte == 8'h1a)
                    r_State <= S_SYNC2;
                else
                    r_State <= S_SYNC1;
            end
        end
                S_DATA: begin
                    
                    r_Checksum <= r_Checksum ^ i_Rx_Byte;
                    
                    if (r_Data_Phase == 1'b0) begin
                        
                        //First byte : high 8 bits
                        r_Data_High <= i_Rx_Byte;
                        r_Data_Phase <= 1'b1;
                        
                    end else begin
                    
                        //Second byte:
                        r_Data_Low <= i_Rx_Byte;
                        r_State    <= S_CHECK;
                        
                    end
                    
                end
                
                S_CHECK: begin
                
                //Compare received checksum with calculated checksum
                if (i_Rx_Byte == r_Checksum) begin
                
                    //Packet accepted: publish verified data
                    o_Sensor_ID <= r_Sensor_ID;
                    o_Pkt_Data  <= {r_Data_High, r_Data_Low};
                    o_Pkt_Valid <= 1'b1;
                end else begin
                    
                    //Packet rejected
                    o_Checksum_Err <= 1'b1;
                    
                end
                
                r_State <= S_SYNC1;
                
            end
                
                default: r_State <= S_SYNC1;
                
            endcase
            
        end
        
    end
        
end
    
endmodule
