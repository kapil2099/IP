module uart_rx #(
    parameter CLKS_PER_BIT = 1042  // For 9600 baud at 10MHz clock
)(
    input        i_clk,
    input        i_rx_serial,    // Serial input line
    output       o_rx_dv,        // Data valid - high for one clock when byte received
    output [7:0] o_rx_byte       // Received byte
);

    // State definitions
    parameter s_IDLE       = 3'b000;
    parameter s_RX_START   = 3'b001;
    parameter s_RX_DATA    = 3'b010;
    parameter s_RX_STOP    = 3'b011;
    parameter s_CLEANUP    = 3'b100;

    // Internal registers
    reg [2:0] r_sm_main     = s_IDLE;
    reg [11:0] r_clk_count   = 0;
    reg [3:0] r_bit_count   = 0;
    reg [7:0] r_rx_byte     = 0;
    reg       r_rx_dv       = 0;
    
    // Input synchronization registers (important for real hardware)
    reg       r_rx_data_r   = 1'b1;
    reg       r_rx_data     = 1'b1;

    // TODO: Implement your receiver logic here
    // The stub currently does nothing - you need to implement:
    // 1. Input synchronization (double register RX input)
    // 2. Start bit detection
    // 3. State machine to handle IDLE -> START -> DATA -> STOP -> CLEANUP
    // 4. Clock counter for baud rate timing with mid-bit sampling
    // 5. Bit counter and data assembly
    // 6. Data valid pulse generation

    always @(posedge i_clk) begin
        // Input synchronization , double synchronizer
        r_rx_data_r <= i_rx_serial;
        r_rx_data   <= r_rx_data_r;
        //$display("**Entered always block**");
        // Your main logic goes here
        // Remove these placeholder assignments when implementing
        
        // r_sm_main <= s_IDLE;
        // r_clk_count <= 0;
        // r_bit_count <= 0;
        // r_rx_byte <= 0;
        // r_rx_dv <= 0;
        case(r_sm_main)

            s_IDLE : begin
		        if(r_rx_data == 1'b0)
                begin
                    $display("State : Idle, start bit detected");
                    r_sm_main <= s_RX_START;
                end
                else r_sm_main <= s_IDLE;
                r_clk_count <= 0;
                r_bit_count <= 0;
                r_rx_byte <= 0;
                r_rx_dv <= 0;
            end
            s_RX_START : begin
                //count upto 1.5 * CLKS_PER_BIT
                if(r_clk_count == (0.5 * CLKS_PER_BIT - 1))
                begin
                    r_clk_count <= 0;
                    r_sm_main <= s_RX_DATA;
                end
                else begin
                    r_clk_count <= r_clk_count + 1;
                    r_sm_main <= s_RX_START;
                end
                r_bit_count <= 0;
                r_rx_byte <= 0;
                r_rx_dv <= 0;
            end
            s_RX_DATA :  begin
                
                //when bit index = 7, move to s_RX_STOP
                // read 1 bit , count CLKS_PER_BIT, keep reading till bit_index = 7
                if(r_bit_count == 8) 
                begin
                    r_sm_main <= s_RX_STOP;
                    r_bit_count <= 0;
                    $display("State : Data, all bits received, going to Stop");
                end
                else if(r_clk_count == CLKS_PER_BIT - 1)
                begin
                    r_sm_main <= s_RX_DATA;
                    r_clk_count <= 0;
                    r_rx_byte[r_bit_count] <= r_rx_data;
                    r_bit_count <= r_bit_count + 1;
                    r_sm_main <= s_RX_DATA;
                    $display("State : Data, 1 bit received");
                end
                else 
                begin
                    r_clk_count <= r_clk_count + 1;
                    r_sm_main <= s_RX_DATA;
                end
                 
            end
            s_RX_STOP : begin
                    //check for stop bit = 1
                    if(r_clk_count == CLKS_PER_BIT - 1)
                    begin
                        if(r_rx_data == 1)
                        begin
                            $display("State : STOP, valid stop bit, going to Cleanup.");
                            r_sm_main <= s_CLEANUP;
                            r_clk_count <= 0;
                        end
                        else begin
                            $display("State : Stop , invalid stop bit, going to Idle.");
                            r_sm_main <= s_IDLE;
                            r_clk_count <= 0;
                            r_rx_byte <= 0;
                            r_bit_count <= 0;
                            r_rx_dv <= 0;
                        end
                    end
                    else begin
                        r_clk_count <= r_clk_count + 1;
                        r_sm_main <= s_RX_STOP;
                    end
            end
            s_CLEANUP : begin
                // set data valid bit
                // set data byte to ouput
                // and go to idle state
                if(r_clk_count == CLKS_PER_BIT / 2 - 1)
                begin
                    r_sm_main <= s_IDLE;
                    r_rx_dv <= 1;
                end
                else begin
                    r_clk_count <= r_clk_count + 1;
                    r_sm_main <= s_CLEANUP;
                end
            end


        endcase
    end

    assign o_rx_dv   = r_rx_dv;
    assign o_rx_byte = r_rx_byte;

endmodule

