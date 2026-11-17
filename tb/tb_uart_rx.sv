`timescale 1ns / 1ps

module tb_uart_rx;

    //UART simulation parameters
    localparam int CLKS_PER_BIT = 100;
    localparam int CLK_PERIOD    = 10;
    localparam int BIT_PERIOD    = CLKS_PER_BIT * CLK_PERIOD;
    
    //Tb input signals
    logic tb_Clock      = 1'b0;
    logic tb_Rx_Serial  = 1'b1;
    
    //Observed UART rx outputs
    logic       tb_Rx_DV;
    logic [7:0] tb_Rx_Byte;
    
    int rx_valid_count = 0;
    logic[7:0] captured_byte = 8'h00;
    
    logic [7:0] rx_history [0:7];
    
    logic prev_Rx_DV = 1'b0;
    int tests_passed = 0;
    
    
    
    // Instantiate UART receiver
    uart_rx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) dut (
        .i_Clock     (tb_Clock),
        .i_Rx_Serial (tb_Rx_Serial),
        .o_Rx_DV     (tb_Rx_DV),
        .o_Rx_Byte   (tb_Rx_Byte)
    ); 
    
    
    
    task automatic send_uart_byte(input logic [7:0] data, input bit align_start = 1'b1 );
    
    
        if (align_start)
        @(negedge tb_Clock);
    
        //Transmit start bit
        tb_Rx_Serial = 1'b0;
        #(BIT_PERIOD);
    
        //Transmit 8 bits
        for (int i = 0; i < 8; i++) begin
            tb_Rx_Serial = data[i];
            #(BIT_PERIOD);
        end

        //Transmit stop bit
        tb_Rx_Serial = 1'b1;
        #(BIT_PERIOD);
    
    endtask



    always @(posedge tb_Clock) begin
    
        #1;
        
        //Verify valid pulse width
        if (tb_Rx_DV === 1'b1 && prev_Rx_DV === 1'b1)
            $fatal(1, "FAIL: RX valid lasted multiple cycles");
        
        //Capture received data
        if (tb_Rx_DV === 1'b1) begin
        
            if(rx_valid_count >= 8)
                $fatal(1, "FAIL: RX history overflow");
                
            rx_history[rx_valid_count] = tb_Rx_Byte;
            captured_byte = tb_Rx_Byte;
            
            rx_valid_count++;
            
            
        end
    end

    //Generate Clock
    always #5 tb_Clock = ~tb_Clock;
    
    initial begin 
        $display("Starting UART RX Testbench");
        
        repeat (5) @(negedge tb_Clock);

        //Transmit byte 0x53
        send_uart_byte(8'h53);
        
        repeat (5) @(negedge tb_Clock);
        
        
        if (rx_valid_count !== 1)
            $fatal(1, "FAIL: Expected exactly one RX valid cycle");
            
        if (captured_byte !== 8'h53)
            $fatal(1, "FAIL: Received incorrect UART byte");
            
        $display("PASS: UART byte 0x53 received correctly");
        $display("PASS: RX Data Valid lasted one clock cycle");
        tests_passed++;
        


        //Test 2: Consecutive frames
        send_uart_byte(8'hFF);
        send_uart_byte(8'h00, 1'b0);
        send_uart_byte(8'hA5, 1'b0);
        send_uart_byte(8'h80, 1'b0);
        
        repeat (5) @(negedge tb_Clock);
        
        //Verify total number of received bytes
        if (rx_valid_count !== 5) 
            $fatal(1, "FAIL: Incorrect number of valid cycles");
            
        //Verify received bytes
        if (rx_history[1] !== 8'hFF)
            $fatal(1, "FAIL: Incorrect FF reception");

        if (rx_history[2] !== 8'h00)
            $fatal(1, "FAIL: Incorrect 00 reception");

        if (rx_history[3] !== 8'hA5)
            $fatal(1, "FAIL: Incorrect A5 reception");

        if (rx_history[4] !== 8'h80)
            $fatal(1, "FAIL: Incorrect 80 reception");

        $display("PASS: Consecutive UART frames received");
        $display("PASS: All received byte patterns correct");
        tests_passed++;

        
        //Test 3 UART idle behavior
        tb_Rx_Serial = 1'b1;
        
        #(BIT_PERIOD * 2);
        
        if (rx_valid_count !== 5)
            $fatal(1, "FAIL: Unexpected byte during idle");
            
        $display("PASS: UART idle behavior correct");
        tests_passed++;
        
        
        
        //Test 4: False start bit
        @(negedge tb_Clock);
        
        tb_Rx_Serial = 1'b0;
        
        #(BIT_PERIOD / 4);
        
        tb_Rx_Serial = 1'b1;
        
        #(BIT_PERIOD * 12);
        
        if(rx_valid_count !== 5)
            $fatal(1, "FAIL: False start generated a byte");
            
        $display("PASS: False start rejected");
        tests_passed++;
        
        
        
        //Test 5: Recovery after false start
        send_uart_byte(8'h96);
        
        repeat (5) @(negedge tb_Clock);
        
        if (rx_valid_count !== 6)
            $fatal(1, "FAIL: Receiver failed to recover");
            
        if (rx_history[5] !== 8'h96)
            $fatal(1, "FAIL: Incorrect byte after false start signal");
            
        $display("PASS: Receiver recovered after false start");
        tests_passed++;
        
        
         // Final UART regression summary
        $display("--------------------------------");
        $display("UART RX REGRESSION SUMMARY");
        $display("Tests Passed: %0d / 5", tests_passed);
        $display("Bytes Received: %0d / 6", rx_valid_count);

        if (tests_passed !== 5 || rx_valid_count !== 6)
            $fatal(1, "FAIL: Incomplete UART regression");

        $display("RESULT: ALL TESTS PASSED");
        $display("--------------------------------");
        
        

        $finish;
        
    end
    
    
    
endmodule
