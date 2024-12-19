/////////////////spi memory
 
module spi_mem(
input clk, rst, cs, mosi,
output reg ready, miso, op_done
);
 
reg [7:0] mem [31:0] = '{default:0};
integer count = 0;
reg [15:0] datain;
reg [7:0]  dataout;
 
typedef enum bit [2:0] {idle = 0, detect = 1, store = 2, send_addr = 3, send_data = 4} state_type;
state_type state = idle;
 
always@(posedge clk)
begin
      if(rst) 
          begin
             state <= idle;
             count <= 0;
             miso  <= 0;
             ready <= 0;
             op_done <= 0;
             
          end
     else
         begin
                case(state)
                  idle: begin
                    count <= 0;
                    miso  <= 0;
                    ready <= 0;
                    op_done <= 0;
                    datain <= 0;
                  
                     if(!cs)
                       state <= detect;
                     else
                       state <= idle;
                  end
                  
                    
                  detect: begin 
                      if(mosi)
                        state <= store; ///write 
                      else
                        state <= send_addr;   ///read
                   end
                   
                    
                   store: begin
                      if(count <= 15) begin
                        datain[count]     <= mosi;
                        count             <= count + 1;
                        state             <= store;
                      end
                      else
                        begin
                         mem[datain[7:0]]  <= datain[15:8];
                         state <= idle;
                         count <= 0;
                         op_done <= 1'b1;
                        end
                    end
                    
                    send_addr: begin
                      if(count <= 7) begin
                       count <= count + 1;
                       datain[count] <= mosi;
                       state <= send_addr;
                       end
                       else begin
                       count <= 0;
                       state <= send_data;
                       ready <= 1'b1;
                       dataout <= mem[datain];
                       end
                    end
                       
                    send_data: begin
                       ready <= 1'b0;
                       if(count < 8) 
                       begin
                        count <= count + 1;
                        miso  <= dataout[count]; 
                        state <= send_data;
                       end 
                       else
                         begin
                         count <= 0;
                         state <= idle;
                         op_done <= 1'b1;
                         end     
                    end   
                    
                    default : state <= idle;
                    
                 endcase
          end
      end
endmodule
 
////////////////////////////////////////////////////////////