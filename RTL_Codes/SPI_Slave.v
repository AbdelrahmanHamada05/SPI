module SPI_Slave #(
    parameter IDLE = 3'b000,
    parameter WRITE = 3'b001,
    parameter CHK_CMD = 3'b010,
    parameter READ_ADD = 3'b011,
    parameter READ_DATA = 3'b100 
) ( 
    input SS_n, MOSI, rst_n, clk, tx_valid,
    input [7:0] tx_data,

    output reg MISO, rx_valid,
    output reg [9:0] rx_data
);

reg [2:0] current_state, next_state;
reg [3:0] counter;
reg [2:0] tx_counter; 
reg read_recieved;

/* --------------- Next State Logic --------------- */
always @(*) begin
    case(current_state)
        IDLE: begin
            if(!SS_n) begin
                next_state = CHK_CMD;
            end
            else next_state = IDLE;
        end
        WRITE: begin
            if(SS_n) begin
                next_state = IDLE;
            end
            else next_state = WRITE;
        end
        CHK_CMD: begin
            if(SS_n) begin
                next_state = IDLE;
            end
            else if(!MOSI) begin
                next_state = WRITE;
            end
            else if(MOSI && read_recieved) begin
                next_state = READ_DATA;
            end
            else if(MOSI && !read_recieved) begin
                next_state = READ_ADD;
            end
        end
        READ_ADD: begin
            if(SS_n) begin
                next_state = IDLE;
            end
            else next_state = READ_ADD;    
        end
        READ_DATA: begin
            if(SS_n) begin
                next_state = IDLE;
            end
            else next_state = READ_DATA;
        end
        default: next_state = IDLE;
    endcase
end
/* -------------------------------------------- */

/* --------------- State Memory --------------- */
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        current_state <= IDLE;
    end
    else current_state <= next_state;
end
/* --------------------------------------------- */

/* --------------- Output_Logic ---------------- */
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        MISO <= 0;
        rx_valid <= 0;
        rx_data <= 0;
        counter <= 0;
        read_recieved <= 0;
        tx_counter <= 7; 
    end
    else begin
        case(current_state)
            IDLE: begin
                counter <= 0;
                rx_valid <= 0;
                tx_counter <= 7; 
            end
            WRITE: begin
                read_recieved <= 0; 

                if(counter < 10) begin
                    counter <= counter + 1;
                    rx_data <= {rx_data[8:0], MOSI};
                end
                if(counter == 9) begin
                    rx_valid <= 1;
                end
                else begin
                    rx_valid <= 0;
                end
            end
            CHK_CMD: begin
                rx_valid <= 0;
            end
            READ_ADD: begin
                if(counter < 10) begin
                    counter <= counter + 1;
                    rx_data <= {rx_data[8:0], MOSI};
                end
                
                if(counter == 9) begin
                    rx_valid <= 1;
                    read_recieved <= 1;
                end
                else begin
                    rx_valid <= 0;
                end
            end
            READ_DATA: begin
                if(counter < 10) begin
                    counter <= counter + 1;
                    rx_data <= {rx_data[8:0], MOSI};
                end
                
                if(counter == 9) begin
                    rx_valid <= 1;
                    read_recieved <= 0; 
                end
                else begin 
                    rx_valid <= 0;
                end

                if(tx_valid) begin
                    MISO <= tx_data[tx_counter];
                    tx_counter <= tx_counter - 1; 
                end
            end
        endcase
    end
end
/* --------------------------------------------- */

endmodule