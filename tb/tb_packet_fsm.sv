
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
            
            
            
            
            
            
        //Test 2: Mismatching Checksum
        send_byte(8'h1A);
        send_byte(8'hCF);
        send_byte(8'h03);
        send_byte(8'h12);
        send_byte(8'h34);
        send_byte(8'h24);
        
        //Corrupted packet must not be accepted
        if (tb_Pkt_Valid !== 1'b0)
            $fatal(1, "FAIL: Corrupted packet was accepted");
            
        //Checksum error must be asserted
        if (tb_Checksum_Err !== 1'b1)
            $fatal(1, "FAIL: Checksum error was not detected");
            
        //Previous packet output must remain unmodified
        if (tb_Sensor_ID !== 8'h02)
            $fatal(1, "FAIL: Sensor ID was overwritten");
        
        if (tb_Pkt_Data !== 16'h0118)
            $fatal(1, "FAIL: Measurement was overwritten");
            
        $display("PASS: Corrupted packet was rejected as expected");
        
        //Allow next rising edge to clear error pulse
        @(negedge tb_Clock);
        
        if (tb_Checksum_Err !== 1'b0)
            $fatal(1, "FAIL: Checksum error stayed HIGH");
            
        $display("PASS: Checksum error pulse width correct");
        
        
        
        
        
        //Invalid Sensor ID
        send_byte(8'h1A);
        send_byte(8'hCF);
        send_byte(8'h05);
        
        //Invalid ID must trigger error
        if (tb_ID_Err !== 1'b1)
            $fatal(1, "FAIL: Sensor ID invalid not detected");
            
        //Rejected packet must not be accepted
        if (tb_Pkt_Valid !== 1'b0)
            $fatal(1, "FAIL: Invalid sensor packet was accepted");
            
         //Previous packet output must remain unmodified
         if (tb_Sensor_ID !== 8'h02 || tb_Pkt_Data !== 16'h0118)
            $fatal(1, "FAIL: Invalid ID overwrote packet data");
            
         @(negedge tb_Clock);
         
         //Error pulse should be cleared
         if (tb_ID_Err !== 1'b0)
            $fatal(1, "FAIL:ID error pulse still HIGH");
            
        $display("PASS: Invalid sensor ID rejected correctly");
        
        
        
        
        
        
        //Test 4: Noise before synchronization
        
        send_byte(8'h55);
        send_byte(8'h1A);
        send_byte(8'h99);
        send_byte(8'hAA);
        
        //Noise must not generate valid packet
        if (tb_Pkt_Valid !== 1'b0)
            $fatal(1, "FAIL: Noise produced valid packet");
            
        //Previously accepted data must remain
        if (tb_Sensor_ID !== 8'h02 || tb_Pkt_Data !== 16'h0118)
            $fatal(1, "FAIL: Noise changed accepted data.");
        
        //Recover synchronization and send valid packet
        send_byte(8'h1A);
        send_byte(8'h1A);
        send_byte(8'hCF);
        
        send_byte(8'h04);
        send_byte(8'h00);
        send_byte(8'h2A);
        
        send_byte(8'h2E);
        
        //Verify parser recovered succesfully
        if (tb_Pkt_Valid !== 1'b1)
            $fatal(1, "FAIL: Parser did not recover from noise");
            
        if (tb_Sensor_ID !== 8'h04)
            $fatal(1, "FAIL: Incorrect sensor after recovery");
            
        if (tb_Pkt_Data !== 16'h002A)
            $fatal(1, "FAIL: Unexpected error after recovery");
            
        $display("PASS: Noise ignored and synchronization recovered");
        
        //Verify packet valid pulse clears
        @(negedge tb_Clock);
        
        if (tb_Pkt_Valid !== 1'b0)
            $fatal(1, "FAIL: Recovery packet valid pulse too long)");
              
              
              
              
        //Test 5: Reset during incomplete packet
        send_byte(8'h1A);
        send_byte(8'hCF);
        send_byte(8'h03);
        send_byte(8'h12);      
              
        //Interrupt packet w/ reset
        tb_Reset = 1'b1;
        
        //Hold reset for 2 cycles
        repeat (2) @(negedge tb_Clock);
        
        //Release reset
        tb_Reset = 1'b0;
        
        
        //All outputs should clear
        if (tb_Pkt_Valid !== 1'b0)
            $fatal(1, "FAIL: Packet valid after reset");
            
        if (tb_Sensor_ID !== 8'h00 || tb_Pkt_Data !== 16'h0000)
            $fatal(1, "FAIL: Outputs not cleared by reset");
            
        $display("PASS: Mid packet reset cleared all outputs");
        
        //Remaining bytes of interrupted packet
        send_byte(8'h34);
        send_byte(8'h25);
        
        //Bytes musn't complete packet
        if (tb_Pkt_Valid !== 1'b0)
            $fatal(1, "FAIL: Abandoned packet accepted");
            
        if (tb_Sensor_ID !== 8'h00 || tb_Pkt_Data !== 16'h0000)
            $fatal(1, "FAIL: Abandoned packet changed outputs");
            
        $display("PASS: Abandoned packet ignored");
       
       
       
                
        //Test 6A: First conscutive packet
        send_byte(8'h1A);
        send_byte(8'hCF);
        send_byte(8'h01);
        send_byte(8'h00);
        send_byte(8'h64);
        send_byte(8'h65);
        
        if (tb_Pkt_Valid !== 1'b1)
            $fatal(1, "FAIL: Packet A not accepted");
            
        if (tb_Sensor_ID !== 8'h01 || tb_Pkt_Data !== 16'h0064)
            $fatal(1, "FAIL: Unexpected error in Packet A");
            
        $display("PASS: Packet A accepted");
        
                
        @(negedge tb_Clock);
        
        if (tb_Pkt_Valid !== 1'b0)
            $fatal(1, "FAIL: Packet A valid pulse too long");
        
        //Test 6B: Second packet without reset
        send_byte(8'h1A);
        send_byte(8'hCF);
        send_byte(8'h04);
        send_byte(8'h01);
        send_byte(8'h2C);
        send_byte(8'h29);
        
        
        // Verify second packet accepted
        if (tb_Pkt_Valid !== 1'b1)
            $fatal(1, "FAIL: Packet B not accepted");

        // Verify updated sensor and measurement
        if (tb_Sensor_ID !== 8'h04 || tb_Pkt_Data !== 16'h012C)
            $fatal(1, "FAIL: Packet B data incorrect");

        // No errors should occur
        if (tb_Checksum_Err !== 1'b0 || tb_ID_Err !== 1'b0)
            $fatal(1, "FAIL: Unexpected error in Packet B");
        
        $display("PASS: Consecutive packets accepted");
        
        
        $display("PASS: Consecutive packets accepted");

        // Verify the second valid pulse clears
        @(negedge tb_Clock);

        if (tb_Pkt_Valid !== 1'b0)
            $fatal(1, "FAIL: Packet B valid pulse too long");

        $display("PASS: Packet B valid pulse correct");

        $finish;
        
     
        
    end
endmodule
    