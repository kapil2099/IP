`timescale 1ns/10ps

module uart_tx_only_tb();

    // Testbench parameters for 9600 baud
    parameter c_CLOCK_PERIOD_NS = 100;
    parameter c_CLKS_PER_BIT    = 1042;  // For 9600 baud at 10MHz
    parameter c_BIT_PERIOD      = 104200; // ns (1042 * 100ns)
    
    reg r_clock = 0;
    reg r_tx_dv = 0;
    wire w_tx_done;
    reg [7:0] r_tx_byte = 0;
    wire w_tx_serial;
    wire w_tx_active;
    
    // Test control
    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;
    
    // Test data
    reg [7:0] test_bytes [0:7];
    integer i;

    // Clock generation
    always #(c_CLOCK_PERIOD_NS/2) r_clock <= !r_clock;

    // Instantiate ONLY the UART TX module
    uart_tx #(.CLKS_PER_BIT(c_CLKS_PER_BIT)) UART_TX_INST
    (
        .i_clk(r_clock),
        .i_tx_dv(r_tx_dv),
        .i_tx_byte(r_tx_byte),
        .o_tx_active(w_tx_active),
        .o_tx_serial(w_tx_serial),
        .o_tx_done(w_tx_done)
    );

    // Task to capture and verify TX transmission
    task VERIFY_TX_TRANSMISSION;
        input [7:0] expected;
        reg [7:0] captured_byte;
        integer bit_count;
        begin
            $display("Verifying TX transmission of 0x%02h", expected);
            
            // Wait for TX to become active
            wait(w_tx_active == 1'b1);
            $display("TX became active");
            
            // Wait for start bit
            wait(w_tx_serial == 1'b0);
            $display("Start bit detected");
            #(c_BIT_PERIOD/2); // Move to middle of start bit
            
            if (w_tx_serial !== 1'b0) begin
                $display("ERROR: Start bit verification failed");
                fail_count = fail_count + 1;
                disable VERIFY_TX_TRANSMISSION;
            end
            
            #(c_BIT_PERIOD); // Move to first data bit
            
            // Capture data bits (LSB first)
            captured_byte = 0;
            for (bit_count = 0; bit_count < 8; bit_count = bit_count + 1) begin
                captured_byte[bit_count] = w_tx_serial;
                $display("Data bit %0d: %b", bit_count, w_tx_serial);
                #(c_BIT_PERIOD);
            end
            
            // Check stop bit
            if (w_tx_serial !== 1'b1) begin
                $display("ERROR: Stop bit verification failed");
                fail_count = fail_count + 1;
                disable VERIFY_TX_TRANSMISSION;
            end else begin
                $display("Stop bit verified");
            end
            
            // Wait for TX done signal
            wait(w_tx_done == 1'b1);
            $display("TX done signal received");
            
            // Verify captured data
            test_count = test_count + 1;
            if (captured_byte == expected) begin
                $display("PASS: TX correctly transmitted 0x%02h", captured_byte);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: TX transmitted 0x%02h, expected 0x%02h", captured_byte, expected);
                fail_count = fail_count + 1;
            end
            
            // Wait for TX to become inactive
            wait(w_tx_active == 1'b0);
            $display("TX became inactive\n");
        end
    endtask

    // Main test sequence
    initial begin
        $display("Starting UART TX Only Tests...");
        $dumpfile("uart_tx_tb.vcd");
        $dumpvars(0, uart_tx_only_tb);
        
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
        
        // Test TX with various patterns
        $display("=== Testing UART Transmitter Only ===");
        for (i = 0; i < 8; i = i + 1) begin
            
            // Start transmission
            @(posedge r_clock);
            r_tx_dv <= 1'b1;
            r_tx_byte <= test_bytes[i];
            $display("Starting transmission %0d: 0x%02h", i+1, test_bytes[i]);
            
            @(posedge r_clock);
            r_tx_dv <= 1'b0;
            
            // Verify the transmission
            VERIFY_TX_TRANSMISSION(test_bytes[i]);
            
            // Wait between tests
            // In testbench, add this wait:
            wait(w_tx_done == 1'b1);  // Wait for done pulse
            wait(w_tx_done == 1'b0);  // Wait for done to clear  
            repeat(100) @(posedge r_clock);  // Then small delay

        end
        
        // Test edge cases
        $display("=== Testing Edge Cases ===");
        
        // Test back-to-back transmissions
        $display("Testing back-to-back transmissions...");
        for (i = 0; i < 3; i = i + 1) begin
            fork
                begin
                    @(posedge r_clock);
                    r_tx_dv <= 1'b1;
                    r_tx_byte <= 8'h55 + i;
                    @(posedge r_clock);
                    r_tx_dv <= 1'b0;
                end
                begin
                    VERIFY_TX_TRANSMISSION(8'h55 + i);
                end
            join
        end
        
        // Final results
        $display("\n=== TX Test Results ===");
        $display("Total Tests: %0d", test_count);
        $display("Passed: %0d", pass_count);
        $display("Failed: %0d", fail_count);
        
        if (fail_count == 0) begin
            $display("*** ALL TX TESTS PASSED! ***");
            $display("You can now proceed to implement and test the RX module");
        end else begin
            $display("*** TX TESTS FAILED ***");
            $display("Fix TX implementation before proceeding to RX");
        end
        
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #100_000_000; // 10ms timeout (plenty for 9600 baud)
        $display("ERROR: Test timeout!");
        $finish;
    end

endmodule

