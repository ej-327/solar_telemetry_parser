`timescale 1ns / 1ps

module tb_uart_packet;

    localparam int CLKS_PER_BIT = 100;
    localparam int CLK_PERIOD = 10;
    localparam int BIT_PERIOD = CLKS_PER_BIT * CLK_PERIOD;
    
    //TB inputs
    logic tb_Clock      = 1'b0;
    logic tb_Reset      = 1'b1;
    logic tb_Rx_Serial  = 1'b1;
    
    //Connections between DUTs
    logic [7:0] rx_Byte;
    logic       rx_DV;
    
    
    //Packet FSM outputs
    logic        tb_Pkt_Valid;
    logic [7:0]  tb_Sensor_ID;
    logic [15:0] tb_Pkt_Data;
    logic        tb_Checksum_Err;
    logic        tb_ID_Err;
    
        
    //Integration monitoring var
    int rx_count = 0;
    int pkt_count= 0;
    int checksum_err_count = 0;
    int id_err_count = 0;
    
    logic [7:0] captured_id;
    logic [15:0] captured_data;


    int tests_passed = 0;


    
    //UART RX DUT
    uart_rx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) uart_dut (
        .i_Clock     (tb_Clock),
        .i_Rx_Serial (tb_Rx_Serial),
        .o_Rx_DV     (rx_DV),
        .o_Rx_Byte   (rx_Byte)
    );
    
    //Packet FSM DUT
    packet_fsm packet_dut (
        .i_Clock        (tb_Clock),
        .i_Reset        (tb_Reset),
        .i_Rx_Byte      (rx_Byte),
        .i_Rx_DV        (rx_DV),
        .o_Pkt_Valid    (tb_Pkt_Valid),
        .o_Sensor_ID    (tb_Sensor_ID),
        .o_Pkt_Data     (tb_Pkt_Data),
        .o_Checksum_Err (tb_Checksum_Err),
        .o_ID_Err       (tb_ID_Err)
    );
    
    
    
    
    task automatic send_uart_byte(
        input logic [7:0] data,
        input bit align_start = 1'b1
    );

        if (align_start)
            @(negedge tb_Clock);

        // Start bit
        tb_Rx_Serial = 1'b0;
        #(BIT_PERIOD);

        // Eight data bits, LSB first
        for (int i = 0; i < 8; i++) begin
            tb_Rx_Serial = data[i];
            #(BIT_PERIOD);
        end

        // Stop bit
        tb_Rx_Serial = 1'b1;
        #(BIT_PERIOD);

    endtask
    
    
    task automatic send_uart_packet(
        input logic [7:0] sensor_id,
        input logic [15:0] measurement,
        input logic [7:0] checksum
    );
    
        send_uart_byte(8'h1A);
        send_uart_byte(8'hCF, 1'b0);
        send_uart_byte(sensor_id, 1'b0);
        send_uart_byte(measurement[15:8], 1'b0);
        send_uart_byte(measurement[7:0], 1'b0);
        send_uart_byte(checksum, 1'b0);
    
    endtask
    
        
    
    
    
    
    //100 MHz clock
    always #(CLK_PERIOD / 2) tb_Clock = ~tb_Clock;
    
    
            
      
    //Continuous integration monitor
    always @(posedge tb_Clock) begin
    
        #1;
        
        if (!tb_Reset) begin
            
            if (rx_DV === 1'b1)
                rx_count++;
                
            if (tb_Pkt_Valid === 1'b1) begin
                pkt_count++;
                captured_id = tb_Sensor_ID;
                captured_data = tb_Pkt_Data;
            end
            
            
            if (tb_Checksum_Err === 1'b1)
                checksum_err_count++;
                
            if (tb_ID_Err === 1'b1)
                id_err_count++;
            end
            
        end
      
    
    
    
    initial begin
    
        $display("Starting UART-Packet Integration Testbench");
        
        //Reset packet FSM
        repeat (4) @(negedge tb_Clock);
        tb_Reset = 1'b0;
        
        //Remain idle
        repeat (5) @(negedge tb_Clock);
        
        //Test 1: Valid telemetry packet
        send_uart_packet(8'h02, 16'h0118, 8'h1B);
        
        //Allow processing to complete
        repeat (5) @(negedge tb_Clock);
        
        $display("Serial packet transmission complete");
        
        
        // Verify UART reception
        if (rx_count !== 6)
            $fatal(1, "FAIL: Incorrect UART byte count");

        // Verify packet acceptance
        if (pkt_count !== 1)
            $fatal(1, "FAIL: Incorrect valid packet count");

        // Verify decoded measurement
        if (captured_id !== 8'h02 || captured_data !== 16'h0118)
            $fatal(1, "FAIL: Incorrect telemetry data");

        // Verify no errors occurred
        if (checksum_err_count !== 0 || id_err_count !== 0)
            $fatal(1, "FAIL: Unexpected packet error");
        
        
        $display("PASS: All six UART bytes received");
        $display("PASS: Telemetry packet accepted");
        $display("PASS: Sensor ID and measurement correct");
        $display("PASS: No packet errors detected");

        tests_passed++;


        
        // TEST 2: Single-bit corruption
        send_uart_packet(8'h03, 16'h1235, 8'h25);

        // Allow processing to complete
        repeat (5) @(negedge tb_Clock);
        
        // Verify UART received all additional bytes
        if (rx_count !== 12)
            $fatal(1, "FAIL: Incorrect UART byte count");

        // Corrupted packet must not be accepted
        if (pkt_count !== 1)
            $fatal(1, "FAIL: Corrupted packet accepted");

        // Verify checksum error detected
        if (checksum_err_count !== 1)
            $fatal(1, "FAIL: Checksum corruption not detected");

        // No sensor ID error should occur
        if (id_err_count !== 0)
            $fatal(1, "FAIL: Unexpected sensor ID error");
        
        
        
        // Verify previous accepted outputs remain intact
        if (tb_Sensor_ID !== 8'h02 ||
            tb_Pkt_Data !== 16'h0118)
            $fatal(1, "FAIL: Corrupted packet overwrote outputs");

        $display("PASS: Single-bit corruption detected");
        $display("PASS: Corrupted telemetry packet rejected");
        $display("PASS: Previous measurement preserved");
        
        tests_passed++;
        
        
        
        // TEST 3: Recovery after corrupted packet
        send_uart_packet(8'h04, 16'h002A, 8'h2E);

        repeat (5) @(negedge tb_Clock);
        
        // Verify total UART bytes received
        if (rx_count !== 18)
            $fatal(1, "FAIL: Incorrect UART byte count");

        // Verify successful packet recovery
        if (pkt_count !== 2)
            $fatal(1, "FAIL: Packet recovery unsuccessful");

        // Verify recovered telemetry
        if (captured_id !== 8'h04 || captured_data !== 16'h002A)
            $fatal(1, "FAIL: Incorrect recovery data");

        // Verify no additional errors
        if (checksum_err_count !== 1 || id_err_count !== 0)
            $fatal(1, "FAIL: Unexpected recovery error");
        
        $display("PASS: System recovered after corruption");
        $display("PASS: Recovery telemetry data correct");
        
        tests_passed++;
        
        
        
        
        // Final integration regression
        if (tests_passed !== 3)
            $fatal(1, "FAIL: Incomplete integration regression");

        $display("--------------------------------");
        $display("UART-PACKET REGRESSION SUMMARY");
        $display("Tests Passed: %0d / 3", tests_passed);
        $display("UART Bytes Received: %0d", rx_count);
        $display("Accepted Packets: %0d", pkt_count);
        $display("Rejected Checksum Errors: %0d", checksum_err_count);
        $display("Sensor ID Errors: %0d", id_err_count);
        $display("RESULT: ALL TESTS PASSED");
        $display("--------------------------------");
        
        
        $finish;
        
        
        
        
    end
endmodule
