module uart_tx #(
    parameter CLKS_PER_BIT = 1042       // For 9600 baud at 10MHz clock
)(
    input        i_clk,
    input        i_tx_dv,        // Data valid - pulse to start transmission
    input  [7:0] i_tx_byte,      // Byte to transmit
    output       o_tx_active,    // High when transmitting
    output reg   o_tx_serial,    // Serial output line
    output       o_tx_done       // Pulse when transmission complete
);

    // State definitions
    parameter s_IDLE       = 3'b000;
    parameter s_TX_START   = 3'b001;
    parameter s_TX_DATA    = 3'b010;
    parameter s_TX_STOP    = 3'b011;
    parameter s_CLEANUP    = 3'b100;

    // Internal registers
    reg [2:0] r_sm_main     = s_IDLE;
    reg [11:0] r_clk_count   = 0;
    reg [3:0] r_bit_index   = 0;
    reg [7:0] r_tx_data     = 0;
    reg       r_tx_done     = 0;
    reg       r_tx_active   = 0;

    // TODO: Implement your transmitter logic here
    // The stub currently does nothing - you need to implement:
    // 1. State machine to handle IDLE -> START -> DATA -> STOP -> CLEANUP
    // 2. Clock counter for baud rate timing
    // 3. Bit counter for data bits
    // 4. Serial output generation
    
    always @(posedge i_clk) begin
        // Your implementation goes here
        
        //state transition logic
        
        
        // r_sm_main <= s_IDLE;
        // r_clk_count <= 0;
        // r_bit_index <= 0;
        // r_tx_data <= 0;
        // r_tx_done <= 0;
        // r_tx_active <= 0;
        // o_tx_serial <= 1'b1;  // Idle high


        case(r_sm_main)
            s_IDLE :  begin
                // Wait for data valid signal
                r_tx_done <= 1'b0;
                if (i_tx_dv) begin
                    r_tx_data <= i_tx_byte;  // Load data to transmit
                    $display("i_tx_byte = %8b", i_tx_byte);
                    r_bit_index <= 0;         // Reset bit index
                    r_clk_count <= 0;         // Reset clock counter
                    r_tx_active <= 1;         // Set active flag
                    o_tx_serial <= 1'b0;      // Start bit (low)
                    r_sm_main <= s_TX_START;  // Move to start state
                    
                    $display("EXITING IDLE STATE");
                end
                else begin
                    r_tx_data <= 0;
                    r_bit_index <= 0;
                    r_clk_count <= 0;
                    r_tx_active <= 0;
                    o_tx_serial <= 1;
                    r_sm_main <= s_IDLE;
                end

            end
            s_TX_START :  begin
                //count cycles CLKS_PER_BIT for start bit, reset clock counter when complete
                //then move to data state
                
                if(r_clk_count == (CLKS_PER_BIT - 1)) begin
                    r_clk_count <= 0;
                    r_sm_main <= s_TX_DATA;
                    $display("EXITING START BIT STATE");
                end
                else begin
                    r_clk_count <= r_clk_count + 1;
                    r_sm_main <= s_TX_START;
                    o_tx_serial <= 1'b0;
                end
                r_tx_active <= 1;
                

            end
            s_TX_DATA : begin
                
                //count CLKS_PER_BIT cycles for each bit, 
                //update bit count after CLKS_PER_BIT cycles
                //if bit count = 8, reset bit count, move to S_TX_STOP
               
               
                    if(r_clk_count == (CLKS_PER_BIT - 1)) begin
                        
                        if(r_bit_index == 7) begin
                            //assert();
                            r_bit_index <= 0;
                            r_clk_count <= 0;
                            r_sm_main <= s_TX_STOP;
                            o_tx_serial <= 1'b0;
                            $display("Exiting DATA TRANSFER STATE");
                        end
                        else begin
                            r_bit_index <= r_bit_index + 1;
                            r_clk_count <= 0;
                            r_sm_main <= s_TX_DATA;
                        end
                        
                    end
                    else begin
                        r_clk_count <= r_clk_count + 1;
                        o_tx_serial <= r_tx_data[r_bit_index];
                        r_sm_main <= s_TX_DATA;
                    end
                    

            end
            s_TX_STOP: begin
                
                // send stop bit, count CLKS_PER_BIT  
                //after counting, move to idle state
                if(r_clk_count == (CLKS_PER_BIT - 1)) begin
                    r_clk_count <= 0;
                    r_sm_main <= s_CLEANUP;
                    $display("exiting STOP BIT STATE");
                end
                else begin
                    r_clk_count <= r_clk_count + 1;
                    o_tx_serial <= 1;
                end
                
            end
            s_CLEANUP : begin
                $display("CLEANUP STATE");
                r_clk_count <= 0;
                r_sm_main <= s_IDLE;
                o_tx_serial <= 1'b1;
                r_tx_done <= 1'b1;
                r_tx_active <= 1'b0;
                r_tx_data <= 0;
            end



        endcase

    end

    assign o_tx_active = r_tx_active;
    assign o_tx_done   = r_tx_done;

endmodule

