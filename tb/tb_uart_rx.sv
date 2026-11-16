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
    
    
    // Instantiate UART receiver
    uart_rx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) dut (
        .i_Clock     (tb_Clock),
        .i_Rx_Serial (tb_Rx_Serial),
        .o_Rx_DV     (tb_Rx_DV),
        .o_Rx_Byte   (tb_Rx_Byte)
    ); 
    
    
    
    task automatic send_uart_byte(input logic [7:0] data);
    
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
        
        if (tb_Rx_DV === 1'b1) begin
            rx_valid_count++;
            captured_byte = tb_Rx_Byte;
            
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
        
        
        $display("UART transmission complete");


        $finish;
        
    end
    
    
    
endmodule
