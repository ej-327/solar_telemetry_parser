`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/01/2026 08:58:52 PM
// Design Name: 
// Module Name: uart_rx
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


module uart_rx #(


    parameter CLKS_PER_BIT = 100
)(
    input i_Clock, //100 MHz Master Clock
    input i_Rx_Serial, //Async serial stream from PC
    output o_Rx_DV, //1-cycle valid pulse
    output[7:0] o_Rx_Byte //8-bit payload
    );
    
    //FSM State Encoding
    
    localparam IDLE         = 3'b000;
    localparam RX_START_BIT = 3'b001;
    localparam RX_DATA_BITS = 3'b010;
    localparam RX_STOP_BIT  = 3'b011;
    localparam CLEANUP      = 3'b100;
    
    //Register
    reg [2:0] r_SM_Main     = IDLE;
    reg [7:0] r_Clock_Count = 0;
    reg [2:0] r_Bit_Index   = 0;
    reg [7:0] r_Rx_Byte     = 0;
    reg       r_Rx_DV       = 0;
    
    //Double-Flop Synchronizer for Metastability
    reg r_Rx_Data_R = 1'b1;
    reg r_Rx_Data   = 1'b1;
    
    //Cross asynchronous input into 
    always @(posedge i_Clock) begin
        r_Rx_Data_R <= i_Rx_Serial;
        r_Rx_Data   <= r_Rx_Data_R;
    end
    
    //Main UART FSM
    always @(posedge i_Clock)begin
        case (r_SM_Main)
        
            IDLE: begin
            r_Rx_DV       <= 1'b0;
            r_Clock_Count <= 0;
            r_Bit_Index   <= 0;
            
            //Start bit detected (line drops low)
            if (r_Rx_Data == 1'b0)
                r_SM_Main <= RX_START_BIT;
            else
                r_SM_Main <= IDLE;
        end
        
        RX_START_BIT: begin
            //Wait for dead-center of StartBit
            if (r_Clock_Count == (CLKS_PER_BIT - 1) / 2) begin
                if (r_Rx_Data == 1'b0) begin
                    r_Clock_Count <= 0;
                    r_SM_Main     <= RX_DATA_BITS;
                end else begin
                    r_SM_Main     <= IDLE; 
                end
            end else begin
                r_Clock_Count   <= r_Clock_Count + 1;
                r_SM_Main       <= RX_START_BIT;
            end
        end
        
        RX_DATA_BITS: begin
            //Wait for dead-center of Data Bit
            if (r_Clock_Count < CLKS_PER_BIT - 1) begin
                r_Clock_Count <= r_Clock_Count + 1;
                r_SM_Main <= RX_DATA_BITS;
            end else begin  
                r_Clock_Count          <= 0;
                r_Rx_Byte[r_Bit_Index] <= r_Rx_Data;   
                
                //Check if we have received 8 bits
                if (r_Bit_Index < 7) begin
                r_Bit_Index <= r_Bit_Index + 1;
                r_SM_Main   <= RX_DATA_BITS;
            end else begin
                r_Bit_Index <= 0;
                r_SM_Main   <= RX_STOP_BIT;
                end
            end
        end
        
        RX_STOP_BIT: begin
            //Wait for dead-center Stop Bit
            if (r_Clock_Count < CLKS_PER_BIT - 1) begin
                r_Clock_Count <= r_Clock_Count + 1;
                r_SM_Main     <=RX_STOP_BIT;
            end else begin
                r_Rx_DV     <= 1'b1; //Fire Data Valid pulse
                r_Clock_Count<= 0;
                r_SM_Main   <= CLEANUP;
            end 
        end
        
        CLEANUP: begin
            //Pull DV back low after exactly 1 clock cycle 
            r_SM_Main <= IDLE;
            r_Rx_DV   <= 1'b0;
        end
        
        default:
            r_SM_Main <= IDLE;
    endcase
end

//Map internal registers to output ports
assign o_Rx_Byte = r_Rx_Byte;
assign o_Rx_DV   = r_Rx_DV;

endmodule             
            
    

