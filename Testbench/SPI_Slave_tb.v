`timescale 1ns/1ps

module SPI_Slave_tb;

    // Inputs
    reg SS_n;
    reg MOSI;
    reg rst_n;
    reg clk;
    reg tx_valid;
    reg [7:0] tx_data;

    // Outputs
    wire MISO;
    wire rx_valid;
    wire [9:0] rx_data;

    // Instantiate First DUT
    SPI_Slave DUT1 (
        .SS_n(SS_n),
        .MOSI(MOSI),
        .rst_n(rst_n),
        .clk(clk),
        .tx_valid(tx_valid),
        .tx_data(tx_data),
        .MISO(MISO),
        .rx_valid(rx_valid),
        .rx_data(rx_data)
    );

    // Clock generation (10ns period)
    always #5 clk = ~clk;

    // Task to send 10-bit frame (MSB first)
    task send_frame;
        input [9:0] data;
        integer i;
        begin
            for(i = 9; i >= 0; i = i - 1) begin
                MOSI = data[i];
                #10;
            end
        end
    endtask

    integer j;

    initial begin
        // Init
        clk = 0;
        rst_n = 0;
        SS_n = 1;
        MOSI = 0;
        tx_valid = 0;
        tx_data = 8'h00;

        // Reset
        #20;
        rst_n = 1;

        // =========================
        // 🔹 WRITE OPERATION
        // MOSI first bit = 0 → WRITE
        // =========================
        #10;
        SS_n = 0;  // Enable slave

        send_frame(10'b0_101010101); // WRITE command + data

        #10;
        SS_n = 1;  // End transaction
        #20;

        // =========================
        // 🔹 READ ADDRESS
        // MOSI first bit = 1 → READ_ADD
        // =========================
        SS_n = 0;

        send_frame(10'b1_110011001); // Address phase

        #10;
        SS_n = 1;
        #20;

        // =========================
        // 🔹 READ DATA
        // MOSI first bit = 1 again → READ_DATA
        // =========================
        SS_n = 0;

        // Send the 10-bit Read Command 
        send_frame(10'b1_110000000); 

        // Emulate RAM response
        #10;
        tx_valid = 1;      
        tx_data = 8'h3C;   // RAM data to send on MISO

        // Master provides 8 extra clock cycles to shift MISO out
        for(j = 0; j < 8; j = j + 1) begin
            MOSI = 0; // Send dummy bits to keep clocks going
            #10;
        end

        tx_valid = 0;
        #10;
        SS_n = 1;

        #50;
        $stop;
    end

endmodule