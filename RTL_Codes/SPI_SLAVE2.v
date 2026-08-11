module SPI_SLAVE2
#
(
parameter IDLE = 3'B000 ,
parameter CHK_CMD =3'B001 ,
parameter WRITE = 3'B010 ,
parameter READ_DATA = 3'B011 ,
parameter READ_ADD = 3'B100 
)
( 
input wire mosi ,
input wire ss_n ,
input wire clk,
input wire rst_n ,
input wire [7:0] tx_data, 
input wire tx_valid, 

output reg     miso,
output reg    [9:0] rx_data, 
output  reg   rx_valid 
);
reg [2:0] cs; 
reg [2:0] ns;
reg is_there_prev_addres;
reg [9:0] mosi_data_parallel ;
reg [4:0] count ; 
reg [7:0] tx_reg;  
// state memory 
always @(posedge clk or negedge rst_n) begin
    if (~rst_n) cs<= IDLE ; 
    else  cs<=ns;     
end 

        //////////////////////////////////////////////////////////////////////////
//next state logic 
always @(*) begin
    case (cs) 
        IDLE: begin
        if (ss_n )
        ns =IDLE; 
        else ns = CHK_CMD ; 
        end
        CHK_CMD: begin
          if (ss_n) ns=IDLE ; 
          else begin
            if (~mosi) ns=WRITE; 
            else  begin
            if (is_there_prev_addres) ns=READ_DATA; 
            else ns=READ_ADD ;
            end
          end
        end
        WRITE:begin
            if (ss_n) ns=IDLE;
            else 
            ns= WRITE; 
            end
        READ_DATA: begin 
            if (ss_n) ns=IDLE;
            else 
            ns= READ_DATA; 
        end
        READ_ADD: begin 
            if (ss_n) ns=IDLE;
            else 
            ns= READ_ADD; 
        end
        default : begin
            ns=IDLE; 
        end
        endcase
end



        //////////////////////////////////////////////////////////////////////////
//output logic 

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        rx_data<=10'b 0000000000; 
        rx_valid<= 0; 
        count<=0; 
        is_there_prev_addres<=0; 
         miso <= 0;
    end
   else 
    case(cs)


    IDLE: begin 
         rx_valid <= 0; 
        miso <= 0;
     end
    CHK_CMD: begin 
        count <= 0;
     end

    WRITE: begin
    if (count < 10 ) begin
    rx_data<={rx_data[8:0],mosi};
    count<= count+1 ; 
    end
    else if (count==10)
    rx_valid <= 1; 
    end

    READ_ADD: begin
    if (count < 10 ) begin
    rx_data<={rx_data[8:0],mosi};
    count<= count+1 ; 
    end
    else if (count==10) begin
    rx_valid <= 1;
    is_there_prev_addres<=1 ; 
    end
    end

    READ_DATA: begin
    if (count < 10 ) begin
    rx_data<={rx_data[8:0],mosi};
    count<= count+1 ; 
    end
    else if (count==10) begin 
    rx_valid <= 1; 
    
    if (tx_valid) begin
       
        tx_reg<= tx_data;
        count<=count+1 ;   
        end
        end
        else if (count > 10 && count < 19) begin 
             rx_valid<=0;
            miso <= tx_reg[7]; 
            tx_reg<={tx_reg[6:0],1'b0}; 
            count<=count+1 ;
        end 
        else if (count==19)
        is_there_prev_addres<=0; 

    end 
endcase
end
endmodule