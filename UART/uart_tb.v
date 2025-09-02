`timescale 1ns/10ps

module uart_tb();

    // Testbench uses a 10 MHz clock
    // Want to interface to 115200 baud UART
    // 10000000 / 115200 = 87 Clocks Per Bit.
    parameter c_CLOCK_PERIOD_NS = 100;
    parameter c_CLKS_PER_BIT    = 1042;
    parameter c_BIT_PERIOD      = c_CLOCK_PERIOD_NS * c_CLKS_PER_BIT;  // ns
    
    reg r_clock = 0;
    reg r_tx_dv = 0;
    wire w_tx_done;
    reg [7:0] r_tx_byte = 0;
    wire w_tx_serial;
    
    // Receiver connections
    reg r_rx_serial = 1;
    wire w_rx_dv;
    wire [7:0] w_rx_byte;
    
    // Test control
    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;
    
    parameter NUM_TESTS = 8; // Total number of tests to run
    // Test data
    reg [7:0] test_bytes [NUM_TESTS-1:0];
    reg [7:0] expected_byte;
    integer i;

    // Clock generation
    always #(c_CLOCK_PERIOD_NS/2) r_clock <= !r_clock;

    // Instantiate UART modules
    uart_tx #(.CLKS_PER_BIT(c_CLKS_PER_BIT)) UART_TX_INST
    (
        .i_clk(r_clock),
        .i_tx_dv(r_tx_dv),
        .i_tx_byte(r_tx_byte),
        .o_tx_active(),
        .o_tx_serial(w_tx_serial),
        .o_tx_done(w_tx_done)
    );
    
    uart_rx #(.CLKS_PER_BIT(c_CLKS_PER_BIT)) UART_RX_INST
    (
        .i_clk(r_clock),
        .i_rx_serial(r_rx_serial),
        .o_rx_dv(w_rx_dv),
        .o_rx_byte(w_rx_byte)
    );

    // Task to send a byte serially (for testing RX)
    task UART_WRITE_BYTE;
        input [7:0] i_data;
        integer ii;
        begin
            $display("Sending byte 0x%02h to RX", i_data);
            
            // Send Start Bit
            r_rx_serial <= 1'b0;
            #(c_BIT_PERIOD);
            
            // Send Data Byte (LSB first)
            for (ii = 0; ii < 8; ii = ii + 1) begin
                r_rx_serial <= i_data[ii];
                #(c_BIT_PERIOD);
            end
            
            // Send Stop Bit
            r_rx_serial <= 1'b1;
            #(c_BIT_PERIOD);
        end
    endtask

    // Task to wait for TX transmission and capture result
    task WAIT_FOR_TX;
        input [7:0] expected;
        reg [7:0] captured_byte;
        integer bit_count;
        begin
            $display("Waiting for TX to transmit 0x%02h", expected);
            
            // Wait for start bit
            wait(w_tx_serial == 1'b0);
            #(c_BIT_PERIOD/2); // Move to middle of start bit
            
            if (w_tx_serial !== 1'b0) begin
                $display("ERROR: Start bit not detected correctly");
                fail_count = fail_count + 1;
                    disable WAIT_FOR_TX;
            end
            
            #(c_BIT_PERIOD); // Move to first data bit
            
            // Capture data bits (LSB first)
            captured_byte = 0;
            for (bit_count = 0; bit_count < 8; bit_count = bit_count + 1) begin
                captured_byte[bit_count] = w_tx_serial;
                #(c_BIT_PERIOD);
            end
            
            // Check stop bit
            if (w_tx_serial !== 1'b1) begin
                $display("ERROR: Stop bit not detected correctly");
                fail_count = fail_count + 1;
                disable WAIT_FOR_TX;
            end
            
            // Verify captured data
            test_count = test_count + 1;
            if (captured_byte == expected) begin
                $display("PASS: TX correctly transmitted 0x%02h", captured_byte);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: TX transmitted 0x%02h, expected 0x%02h", captured_byte, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // Main test sequence
    initial begin
        $display("Starting UART Tests...");
        $dumpfile("uart_tb.vcd");
        $dumpvars(0, uart_tb);
        
        // Initialize test data
        test_bytes[0] = 8'h55; // Alternating pattern
        test_bytes[1] = 8'hAA; // Alternating pattern
        test_bytes[2] = 8'h00; // All zeros
        test_bytes[3] = 8'hFF; // All ones
        test_bytes[4] = 8'h0F; // Low nibble
        test_bytes[5] = 8'hF0; // High nibble
        test_bytes[6] = 8'h3C; // Random pattern
        test_bytes[7] = 8'hC3; // Random pattern
        
        // Wait for initial settling
        repeat(10) @(posedge r_clock);
        
        // Test 1: UART TX Tests
        $display("\n=== Testing UART Transmitter ===");
        for (i = 0; i < 8; i = i + 1) begin
            fork
                begin
                    // Send byte via TX
                    @(posedge r_clock);
                    r_tx_dv <= 1'b1;
                    r_tx_byte <= test_bytes[i];
                    @(posedge r_clock);
                    r_tx_dv <= 1'b0;
                end
                begin
                    // Capture and verify TX output
                    WAIT_FOR_TX(test_bytes[i]);
                end
            join
            
            // In testbench, add this wait:
            wait(w_tx_done == 1'b1);  // Wait for done pulse
            wait(w_tx_done == 1'b0);  // Wait for done to clear  
            //repeat(100) @(posedge r_clock);  // Then small delay

        end
        
        // Test 2: UART RX Tests
        $display("\n=== Testing UART Receiver ===");
        for (i = 0; i < 8; i = i + 1) begin
            fork
                begin
                    // Send byte to RX
                    UART_WRITE_BYTE(test_bytes[i]);
                end
                begin
                    // Wait for RX to receive
                    expected_byte = test_bytes[i];
                    wait(w_rx_dv == 1'b1);
                    @(posedge r_clock); // Sample on clock edge
                    
                    test_count = test_count + 1;
                    if (w_rx_byte == expected_byte) begin
                        $display("PASS: RX correctly received 0x%02h", w_rx_byte);
                        pass_count = pass_count + 1;
                    end else begin
                        $display("FAIL: RX received 0x%02h, expected 0x%02h", w_rx_byte, expected_byte);
                        fail_count = fail_count + 1;
                    end
                end
            join
            
            // Wait for RX data valid to go low
            wait(w_rx_dv == 1'b0);
            repeat(100) @(posedge r_clock);
        end
        
        // Test 3: Loopback Test (TX -> RX)
        $display("\n=== Testing UART Loopback ===");
       // Test 3: Loopback Test (TX -> RX)
$display("\n=== Testing UART Loopback ===");
    for (i = 0; i < 4; i = i + 1) begin
        fork: loopback_test
            begin
                // Send via TX
                @(posedge r_clock);
                r_tx_dv <= 1'b1;
                r_tx_byte <= test_bytes[i];
                @(posedge r_clock);
                r_tx_dv <= 1'b0;
            end
            begin
                // Connect TX to RX for limited time
                repeat(20000) begin
                    @(posedge r_clock);
                    r_rx_serial <= w_tx_serial;
                end
            end
            begin
                // Wait for RX to receive
                expected_byte = test_bytes[i];
                wait(w_rx_dv == 1'b1);
                @(posedge r_clock);
                
                test_count = test_count + 1;
                if (w_rx_byte == expected_byte) begin
                    $display("PASS: Loopback test 0x%02h", w_rx_byte);
                    pass_count = pass_count + 1;
                end else begin
                    $display("FAIL: Loopback test got 0x%02h, expected 0x%02h", w_rx_byte, expected_byte);
                    fail_count = fail_count + 1;
                end
                
                disable loopback_test; // Exit all parallel processes
            end
        join
    
    // Reset and wait
    r_rx_serial <= 1'b1;
    wait(w_rx_dv == 1'b0);
    repeat(200) @(posedge r_clock);
end

        
        // Final results
        $display("\n=== Test Results ===");
        $display("Total Tests: %0d", test_count);
        $display("Passed: %0d", pass_count);
        $display("Failed: %0d", fail_count);
        
        if (fail_count == 0) begin
            $display("*** ALL TESTS PASSED! ***");
        end else begin
            $display("*** SOME TESTS FAILED ***");
            $display("Implement the UART TX and RX logic to make tests pass");
        end
        
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #50_000_000; // 50ms timeout
        $display("ERROR: Test timeout!");
        $finish;
    end

endmodule

