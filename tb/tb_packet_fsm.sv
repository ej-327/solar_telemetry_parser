
`timescale 1ns / 1ps

module tb_packet_fsm;

    //Clock and reset
    logic tb_Clock = 1'b0;
    logic tb_Reset = 1'b1;
    
    //Simulate UART_rx outputs
    logic [7:0] tb_Rx_Byte = 8'h00;
    logic       tb_Rx_DV   = 1'b0;
    
    //Signals for monitoring FSM outputs
    logic       tb_Pkt_Valid;
    logic [7:0] tb_Sensor_ID;
    logic [15:0] tb_Pkt_Data;
    logic       tb_Checksum_Err;
    logic       tb_ID_Err;
    
    //Device Under Test
    packet_fsm dut (
        
        //Inputs
        .i_Clock    (tb_Clock),
        .i_Reset    (tb_Reset),
        .i_Rx_Byte  (tb_Rx_Byte),
        .i_Rx_DV    (tb_Rx_DV),
        
        //Outputs
        .o_Pkt_Valid    (tb_Pkt_Valid),
        .o_Sensor_ID    (tb_Sensor_ID),
        .o_Pkt_Data     (tb_Pkt_Data),
        .o_Checksum_Err (tb_Checksum_Err),
        .o_ID_Err       (tb_ID_Err)
        
    );
    
    task automatic send_byte(input logic [7:0] byte_value);
       
        @(negedge tb_Clock);
        
        tb_Rx_Byte = byte_value;
        tb_Rx_DV   = 1'b1;
        
        @(negedge tb_Clock);
        
        tb_Rx_DV = 1'b0;
        
    endtask
    
    //100 MHz clock
    always #5 tb_Clock = ~tb_Clock;
    
    initial begin
    
        $display("Starting Packet FSM Testbench");
        
        
        //Hold reset for 4 cycles. Drop at 4th falling edge
        repeat  (4) @(negedge tb_Clock);
        
        tb_Reset = 1'b0;
        
        
        $display("Reset released at %0t", $time);
        
        //Send packet synchronization bytes, Test 1: Valid packet
        send_byte(8'h1A);
        send_byte(8'hCF);
        send_byte(8'h02);
        send_byte(8'h01);
        send_byte(8'h18);
        send_byte(8'h1B);
        
        //Check packet-valid is assertad
        if (tb_Pkt_Valid !== 1'b1)
            $fatal(1, "FAIL: Packet valid wasn't asserted");
        
        //Verify Sensor ID
        if (tb_Sensor_ID !== 8'h02)
            $fatal(1, "FAIL: Incorrect sensor ID");
            
        //Verify 16-bit measurement
        if (tb_Pkt_Data !== 16'h0118)
            $fatal (1, "FAIL: Incorrect packet data");
            
             //Verify that no error flag was asserted
        if (tb_Checksum_Err !== 1'b0 || tb_ID_Err !== 1'b0)
            $fatal(1, "FAIL: Unexpected packet error");
            
        $display("PASS: Valid packet acccepted correctly");
        
        //Wait for following falling edge
        @(negedge tb_Clock);
        
        //Valid must have returned LOW
        if (tb_Pkt_Valid !== 1'b0)
            $fatal(1, "FAIL: Packet valid pulse lasted too long");
            
        $display("PASS: Packet valid pulse width correct");
            
        //Allow 2 more cycles
        repeat (2) @(posedge tb_Clock);
        
        $finish;
        
    end
endmodule
    