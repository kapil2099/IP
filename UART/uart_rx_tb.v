`timescale 1ns/10ps

module uart_rx_only_tb();

    // Testbench parameters for 9600 baud
    parameter c_CLOCK_PERIOD_NS = 100;   // 10 MHz clock
    parameter c_CLKS_PER_BIT    = 1042;  // For 9600 baud at 10MHz
    parameter c_BIT_PERIOD      = 104200; // ns (1042 * 100ns)
    
    // Clock and signals
    reg r_clock = 0;
    reg r_rx_serial = 1;  // Start idle high
    wire w_rx_dv;
    wire [7:0] w_rx_byte;
    
    // Test control
    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;
    
    // Test data
    reg [7:0] test_bytes [0 : 25];
    reg [7:0] expected_byte;
    integer i;

    // Clock generation
    always #(c_CLOCK_PERIOD_NS/2) r_clock <= !r_clock;

    // Instantiate ONLY the UART RX module
    uart_rx #(.CLKS_PER_BIT(c_CLKS_PER_BIT)) UART_RX_INST
    (
        .i_clk(r_clock),
        .i_rx_serial(r_rx_serial),
        .o_rx_dv(w_rx_dv),
        .o_rx_byte(w_rx_byte)
    );

    // Task to send a byte serially to the RX module
    task SEND_BYTE_TO_RX;
        input [7:0] byte_to_send;
        integer bit_index;
        begin
            $display("Sending byte 0x%02h (%08b) to RX module", byte_to_send, byte_to_send);
            
            // Send Start Bit (logic 0)
            r_rx_serial <= 1'b0;
            $display("  Start bit sent (0)");
            #(c_BIT_PERIOD);
            
            // Send Data Bytes (LSB first)
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                r_rx_serial <= byte_to_send[bit_index];
                $display("  Data bit %0d sent (%b) - bit value from byte_to_send[%0d]", 
                         bit_index, byte_to_send[bit_index], bit_index);
                #(c_BIT_PERIOD);
            end
            
            // Send Stop Bit (logic 1)
            r_rx_serial <= 1'b1;
            $display("  Stop bit sent (1)");
            #(c_BIT_PERIOD);
            
            $display("Complete byte transmission finished\n");
        end
    endtask

    // Task to wait for and verify RX reception
   // Task to wait for and verify RX reception
task WAIT_AND_VERIFY_RX;
    input [7:0] expected;
    reg timeout_occurred;
    integer timeout_counter;
    begin
        $display("Waiting for RX to receive byte 0x%02h...", expected);
        timeout_occurred = 0;
        timeout_counter = 0;
        
        // Wait for data valid signal with timeout
        while (!w_rx_dv && !timeout_occurred) begin
            @(posedge r_clock);
            timeout_counter = timeout_counter + 1;
            if (timeout_counter > 200000) begin
                timeout_occurred = 1;
            end
        end
        
        if (timeout_occurred) begin
            $display("ERROR: Timeout waiting for RX data valid signal");
            fail_count = fail_count + 1;
            test_count = test_count + 1;
        end else begin
            // Sample the received data IMMEDIATELY when DV is high
            // NO EXTRA CLOCK DELAY!
            $display("RX data valid asserted! Received: 0x%02h (%08b)", w_rx_byte, w_rx_byte);
            
            test_count = test_count + 1;
            if (w_rx_byte == expected) begin
                $display("PASS: RX correctly received 0x%02h", w_rx_byte);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: RX received 0x%02h, expected 0x%02h", w_rx_byte, expected);
                fail_count = fail_count + 1;
            end
            
            // Wait for data valid to go low
            while (w_rx_dv) begin
                @(posedge r_clock);
            end
            $display("RX data valid deasserted\n");
        end
    end
endtask

    // Task to test a complete byte reception
    task TEST_RX_BYTE;
        input [7:0] test_byte;
        begin
            fork
                // Send the byte to RX
                SEND_BYTE_TO_RX(test_byte);
                // Wait and verify reception
                WAIT_AND_VERIFY_RX(test_byte);
            join
            
            // Wait a bit between tests
            repeat(50) @(posedge r_clock);
        end
    endtask

    // Main test sequence
    initial begin
        $display("Starting UART RX Only Tests...");
        $dumpfile("uart_rx_tb.vcd");
        $dumpvars(0, uart_rx_only_tb);
        
        // Initialize test data with various patterns
        test_bytes[0]  = 8'h00; // All zeros
        test_bytes[1]  = 8'hFF; // All ones
        test_bytes[2]  = 8'h55; // Alternating 01010101
        test_bytes[3]  = 8'hAA; // Alternating 10101010
        test_bytes[4]  = 8'h0F; // Low nibble only
        test_bytes[5]  = 8'hF0; // High nibble only
        test_bytes[6]  = 8'h3C; // 00111100
        test_bytes[7]  = 8'hC3; // 11000011
        test_bytes[8]  = 8'h01; // Single bit (LSB)
        test_bytes[9]  = 8'h80; // Single bit (MSB)
        test_bytes[10] = 8'h7F; // All but MSB
        test_bytes[11] = 8'hFE; // All but LSB
        test_bytes[12] = 8'h33; // 00110011
        test_bytes[13] = 8'hCC; // 11001100
        test_bytes[14] = 8'h5A; // 01011010
        test_bytes[15] = 8'hA5; // 10100101
        
        // Wait for initial settling
        repeat(20) @(posedge r_clock);
        
        // Test basic byte reception
        $display("\n=== Testing UART Receiver Basic Functionality ===");
        for (i = 0; i < 16; i = i + 1) begin
            $display("--- Test %0d of 16 ---", i + 1);
            TEST_RX_BYTE(test_bytes[i]);
        end
        
        // Test edge cases
        $display("\n=== Testing Edge Cases ===");
        
        // Test back-to-back reception
        $display("Testing back-to-back byte reception...");
        for (i = 0; i < 3; i = i + 1) begin
            TEST_RX_BYTE(8'hA0 + i);
        end
        
        // Test ASCII characters
        $display("Testing common ASCII characters...");
        TEST_RX_BYTE(8'h41); // 'A'
        TEST_RX_BYTE(8'h42); // 'B'
        TEST_RX_BYTE(8'h30); // '0'
        TEST_RX_BYTE(8'h39); // '9'
        TEST_RX_BYTE(8'h20); // Space
        TEST_RX_BYTE(8'h0D); // Carriage return
        TEST_RX_BYTE(8'h0A); // Line feed
        
        // Test with extra idle time between bytes
        $display("Testing with extended idle periods...");
        r_rx_serial <= 1'b1;
        #(c_BIT_PERIOD * 10);  // Long idle period
        TEST_RX_BYTE(8'h96);
        
        // Final results
        $display("\n=== RX Test Results ===");
        $display("Total Tests: %0d", test_count);
        $display("Passed: %0d", pass_count);
        $display("Failed: %0d", fail_count);
        
        if (fail_count == 0) begin
            $display("*** ALL RX TESTS PASSED! ***");
            $display("Your UART receiver implementation is working correctly!");
        end else begin
            $display("*** %0d RX TESTS FAILED ***", fail_count);
            $display("Check your receiver implementation:");
            $display("- Verify start bit detection");
            $display("- Check baud rate timing");
            $display("- Ensure LSB-first data assembly");
            $display("- Verify stop bit detection");
            $display("- Check data valid signal timing");
        end
        
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #40_000_000; // 20ms timeout
        $display("ERROR: Test timeout! Check if RX is stuck in a state.");
        $finish;
    end
    
    // Monitor for debugging
    initial begin
        $monitor("Time=%0t: rx_serial=%b, rx_dv=%b, rx_byte=0x%02h", 
                 $time, r_rx_serial, w_rx_dv, w_rx_byte);
    end

endmodule

