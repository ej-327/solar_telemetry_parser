`timescale 1ns / 1ps

module dsp_filter(
    
    input wire      i_Clock,
    input wire      i_Reset,
    input wire      i_Pkt_Valid,
    input wire      i_Pkt_Data,
    
    output reg [15:0] o_Filtered_Data,
    output reg        o_Filtered_Val

);

    //Prev 3 valid telemetry measurements
    reg [15:0] r_Sample_1;
    reg [15:0] r_Sample_2;
    reg [15:0] r_Sample_3;
    
    //Track accepted samples until filter initializes
    reg [1:0] r_Sample_Count;
    
    //18-bit sum of four sensor measurements
    wire [17:0] w_Sum;
    
    assign w_Sum = {2'b00, i_Pkt_Data}
                 + {2'b00, r_Sample_1}
                 + {2'b00, r_Sample_2}
                 + {2'b00, r_Sample_3};


    always @(posedge i_Clock) begin
        
        if (i_Reset) begin
            r_Sample_1      <= 16'd0;
            r_Sample_2      <= 16'd0;
            r_Sample_3      <= 16'd0;
            r_Sample_Count  <= 2'd0;
            o_Filtered_Data <= 1'd0;
            o_Filtered_Val  <= 1'd0;
        end
        
        else begin
        
            o_Filtered_Val <= 1'b0;
            
        end
        
        
        
        if (i_Pkt_Valid) begin
        
            r_Sample_3 <= r_Sample_2;
            r_Sample_2 <= r_Sample_1;
            r_Sample_1 <= i_Pkt_Data;
            
        end
        
        
        
        if (r_Sample_Count < 2'd3)
            r_Sample_Count <= r_Sample_Count + 1'b1;
  
            
            
            
        if (r_Sample_Count == 2'd3) begin
            o_Filtered_Data <= w_Sum[17:2];
            o_Filtered_Val  <= 1'b1;
        end
        
        
        
        
        
        
    end


endmodule