//module spi_mem(clk, rst, wr, start_m, addr, din, data_m_rd, done, state_master, state_slave);
module i2c_mem(clk, rst, wr, start_m, addr, din, data_m_rd, done);

	input clk, rst, wr, start_m;
	input [6:0] addr;
	input [7:0] din;
	output reg [7:0] data_m_rd;
	output reg done;
//	output [3:0] state_master, state_slave;
	
	wire sda;
	reg scl, en, sda_m, sda_s, slave_done;
	reg [7:0] addr_m, addr_s, data_s_rd, data_s;
	reg [7:0] temprd;
	
	integer count_m = 0;
	integer count_s = 0;
	
	reg [7:0] mem [16];
	
	typedef enum bit [3:0] {idle = 0, start = 1, send_addr = 2, get_ack1 = 3, send_data = 4, get_ack2= 5, read_data = 6, complete = 7, get_addr = 8, send_ack1 = 9, get_data = 10, send_ack2 = 11 } state_type;
	state_type state_s, state_m;
	
//	assign state_master = state_m;
//	assign state_slave = state_s;

	assign sda = (en) ? sda_m : sda_s; // if enable set, means sda_m sending something
	//////////////////////// master ///////////////////////////////////////////
	always @(posedge clk) begin
		if(rst) begin
			addr_m <= 0;
			temprd <= 0;
			sda_m <= 0;
			en <= 0;
			count_m <= 0;
			done <= 0;
		end
		
		else begin
			case(state_m)
				idle: begin
					scl <= 1;
					en <= 1;
					sda_m <= 1;
					done <= 0;
					temprd <= 0;
					data_m_rd <= 0;
					count_m <= 0;
					if (start_m) begin
						state_m <= start;
					end
					else begin
						state_m <= idle;
					end
				end
				
				start: begin
					sda_m <= 0;
					addr_m <= {addr, wr};
					state_m <= send_addr;
				end
				
				send_addr: begin
					if(count_m <= 7) begin
						sda_m <= addr_m[count_m];
						count_m <= count_m + 1;
					end
					else begin
						en <= 0;
						count_m <= 0;
						state_m <= get_ack1;
					end
				end
				
				get_ack1: begin
					if(!sda) begin
						if(wr) begin
							en <= 0;
							state_m <= send_data;
						end
						else if (!wr) begin
							en <= 0;
							state_m <= read_data;
						end
					end
					else begin
						state_m <= get_ack1;
					end
				end
				
				read_data: begin
					if(count_m <= 9) begin
						temprd[7:0] <= {sda,temprd[7:1]};
						count_m <= count_m + 1;
					end
					else begin
						count_m <= 0;
						state_m <= complete;
						data_m_rd <= temprd;
					end
				end
				
				send_data: begin
					if(count_m <= 7) begin
						sda_m <= din[count_m];
						count_m <= count_m + 1;
					end
					else begin
						en <= 0;
						count_m <= 0;
						state_m <= get_ack2;
					end
				end
				
				get_ack2: begin
					if(!sda) begin
						state_m <= complete;
					end
					else begin
						state_m <= get_ack2;
					end
				end
				
				complete: begin
					if (slave_done) begin
						done <= 1;
						state_m <= idle;
					end
					else begin
						state_m <= complete;
					end
				end
				
				default: begin
					state_m <= idle;
				end
			endcase
		end
	end
						
					
	
	//////////////////////// slave ///////////////////////////////////////////
	always @(posedge clk) begin
		if(rst) begin
			for(int i = 0; i < 16; i ++) begin
				mem[i] <= 0;
			end
			addr_s <= 0;
			data_s <= 0;
			slave_done <= 0;
			count_s <= 0;
		end
		
		else begin
			case(state_s)
				idle: begin
					addr_s <= 0;
					data_s <= 0;
					slave_done <= 0;
					data_s_rd <= 0;
					count_s <= 0;
					
					if (scl && sda_m) begin
						state_s <= start;
					end
					else begin
						state_s <= idle;
					end
				end
				
				start: begin
					if(scl && !sda_m) begin
						state_s <= get_addr;
					end
					else begin
						state_s <= start;
					end
				end
				
				get_addr: begin
					if(count_s <= 7) begin
						addr_s[count_s] <= sda_m;
						count_s <= count_s + 1;
					end
					else begin
						state_s <= send_ack1;
						count_s <= 0;
						if (addr_s[0] == 0) begin
							data_s_rd <= mem[addr_s[7:1]];
						end
					end
				end
				
				send_ack1: begin
					sda_s <= 0;
					
					if(addr_s[0] && state_m == send_data) begin
						state_s <= get_data;
					end
					else if(!addr_s[0] && state_m == read_data) begin
						state_s <= send_data;
					end
					else begin
						state_s <= send_ack1;
					end
				end
				
				get_data: begin
					if(count_s <= 7) begin
						data_s[count_s] <= sda_m;
						count_s <= count_s + 1;
					end
					else begin
						mem[addr_s[7:1]] <= data_s;
						count_s <= 0;
						state_s <= send_ack2;
					end
				end
				
				send_ack2: begin
					sda_s <= 0;
					state_s <= complete;
				end
				
				send_data: begin
					if(count_s <= 7) begin
						sda_s <= data_s_rd[count_s];
						count_s <= count_s + 1;
					end
					else begin
						state_s <= complete;
						count_s <= 0;
					end
				end
				
				complete: begin
					slave_done <= 1;
					state_s <= idle;
				end
				
				default: begin
					state_s <= idle;
				end
			endcase
		end
	end
					
	
	
endmodule



interface i2c_i;
	logic clk, rst, wr, start_m;
	logic [6:0] addr;
	logic [7:0] din;
	logic [7:0] data_m_rd;
	logic done;
endinterface


















