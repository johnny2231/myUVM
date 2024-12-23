`include "uvm_macros.svh"
import uvm_pkg::*;

////////////////////////////////////////////////////////////////////////

typedef enum bit [1:0] {readd = 0, writed = 1, rstdut = 2} oper_mode;

////////////////////////////////////////////////////////////////////////

class transaction extends uvm_sequence_item;
	`uvm_object_utils(transaction)
	
	oper_mode op;
	logic wr, start_m;
	randc logic [6:0] addr;
	rand logic [7:0] din;
	logic [7:0] data_m_rd;
	logic done;
	
	constraint addr_c {addr <= 10;}
	
	function new(string name = "transaction");
		super.new(name);
	endfunction
endclass

////////////////////////////////////////////////////////////////////////

class write_data extends uvm_sequence#(transaction);
	`uvm_object_utils(write_data)
	
	transaction tr;
	
	function new(string name = "write_data");
		super.new(name);
	endfunction
	
	virtual task body();
		repeat(15) begin
			tr = transaction::type_id::create("tr");
			start_item(tr);
			assert(tr.randomize);
			tr.op = writed;
			`uvm_info("SEQ write data", $sformatf("MODE: WRITE - DIN: %d, ADDR: %d", tr.din, tr.addr), UVM_NONE);
			finish_item(tr);
		end
	endtask
endclass

////////////////////////////////////////////////////////////////////////

class read_data extends uvm_sequence#(transaction);
	`uvm_object_utils(read_data)
	
	transaction tr;
	
	function new(string name = "read_data");
		super.new(name);
	endfunction

	virtual task body();
		repeat(15) begin
			tr = transaction::type_id::create("tr");
			start_item(tr);
			assert(tr.randomize);
			tr.op = readd;
			`uvm_info("SEQ read data", $sformatf("MODE: READ - ADDR: %d", tr.addr), UVM_NONE);
			finish_item(tr);
		end
	endtask
endclass

////////////////////////////////////////////////////////////////////////

class reset_dut extends uvm_sequence#(transaction);
	`uvm_object_utils(reset_dut)
	
	transaction tr;
	
	function new(string name = "reset_dut");
		super.new(name);
	endfunction

	virtual task body();
		repeat(3) begin
			tr = transaction::type_id::create("tr");
			start_item(tr);
			assert(tr.randomize);
			tr.op = rstdut;
			`uvm_info("SEQ reset", $sformatf("MODE: RESET"), UVM_NONE);
			finish_item(tr);
		end
	endtask
endclass

////////////////////////////////////////////////////////////////////////

class drv extends uvm_driver#(transaction);
	`uvm_component_utils(drv)
	
	transaction tr;
	virtual i2c_i vif;

	function new(input string path = "drv", uvm_component parent = null);
		super.new(path,parent);
	endfunction
	
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		tr = transaction::type_id::create("tr");
		
		if(!uvm_config_db#(virtual i2c_i)::get(this,"","vif", vif))
			`uvm_error("DRV", "Unable to access interface");
	endfunction
	
	////////////////////reset task
	task reset_dut();
		begin
			`uvm_info("DRV", "System Reset", UVM_NONE);
			vif.rst <= 1;
			vif.addr <= 0;
			vif.din <= 0;
			vif.wr <= 0;
			vif.start_m <= 0;
			@(posedge vif.clk);
		end
	endtask
	
	
	////////////////////write
	task write_d();
		`uvm_info("DRV", $sformatf("MODE: WRITE - DIN: %d, ADDR: %d", tr.din, tr.addr), UVM_NONE);
		vif.rst <= 0;
		vif.addr <= tr.addr;
		vif.din <= tr.din;
		vif.wr <= 1;
		
		vif.start_m <= 1;
		
		@(posedge vif.done);
		vif.start_m <= 0;
	endtask
	
	////////////////////read
	task read_d();
		`uvm_info("DRV", $sformatf("MODE: READ - ADDR: %d", tr.addr), UVM_NONE);
		vif.rst <= 0;
		vif.addr <= tr.addr;
		vif.din <= tr.din;
		vif.wr <= 0;
		
		vif.start_m <= 1;
		
		@(posedge vif.done);
		vif.start_m <= 0;
	endtask
	
	virtual task run_phase(uvm_phase phase);
		forever begin
			seq_item_port.get_next_item(tr);
			
			if(tr.op == rstdut) begin
				reset_dut();
			end
			
			else if (tr.op == writed) begin
				write_d();
			end
			
			else if (tr.op == readd) begin
				read_d();
			end
			
			seq_item_port.item_done();
		end
	endtask
endclass

////////////////////////////////////////////////////////////////////////

class mon extends uvm_monitor;
	`uvm_component_utils(mon)
	
	uvm_analysis_port#(transaction) send;
	
	transaction tr;
	
	virtual i2c_i vif;
	logic [15:0]din;
	logic [7:0] dout;
	
	function new(input string path = "mon", uvm_component parent = null);
		super.new(path,parent);
	endfunction
	
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		tr = transaction::type_id::create("tr");
		send = new("send", this);
		
		if(!uvm_config_db#(virtual i2c_i)::get(this,"","vif", vif))
			`uvm_error("MON", "Unable to access interface");
	endfunction
	
	virtual task run_phase(uvm_phase phase);
		forever begin
			@(posedge vif.clk);
			
			if(vif.rst) begin
				tr.op = rstdut;
				`uvm_info("MON", "SYSTEM RESET DETECTED", UVM_NONE);
				send.write(tr);
			end
			
			else begin
				if(vif.wr) begin
					tr.op = writed;
					tr.addr = vif.addr;
					tr.din = vif.din;
					tr.wr = 1;
					
					tr.start_m = 1;
					
					@(posedge vif.done);
					tr.start_m = 0;
					`uvm_info("MON", $sformatf("DATA WRITE - DIN: %d, ADDR: %d", tr.din, tr.addr), UVM_NONE);
					send.write(tr);
				end
				
				else if(!vif.wr) begin
					tr.op = readd;
					tr.addr = vif.addr;
					tr.din = vif.din;
					tr.wr = 0;
					
					tr.start_m = 1;
					
					@(posedge vif.done);
					tr.start_m = 0;
					tr.data_m_rd = vif.data_m_rd;
					`uvm_info("MON", $sformatf("DATA READ - ADDR: %d", tr.addr), UVM_NONE);
					send.write(tr);
				end
			end
		end
	endtask
endclass

////////////////////////////////////////////////////////////////////////

class sco extends uvm_scoreboard;
	`uvm_component_utils(sco)
	
	uvm_analysis_imp#(transaction,sco) recv;
	bit [7:0] arr[16] = '{default:0};
	bit [7:0] data_rd = 0;
	
	
	function new(input string path = "sco", uvm_component parent = null);
		super.new(path,parent);
	endfunction
	
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		recv = new("sco", this);
	endfunction
	
	virtual function void write(transaction tr);
		if(tr.op == rstdut) begin
			`uvm_info("SCO", "SYSTEM RESET DETECTED", UVM_NONE);
		end
		
		else if (tr.op == writed) begin
			arr[tr.addr] = tr.din;
			`uvm_info("SCO", $sformatf("DATA WRITE - DIN: %d, ADDR: %d, arr_wr: %d", tr.din, tr.addr, arr[tr.addr]), UVM_NONE);
		end
		
		else if (tr.op == readd) begin
			data_rd = arr[tr.addr];
			if (data_rd == tr.data_m_rd) begin
				`uvm_info("SCO", $sformatf("DATA MATCHED - ADDR: %d, rdata: %d", tr.addr, tr.data_m_rd), UVM_NONE);
			end
			else begin
				`uvm_info("SCO", $sformatf("TEST FAILED - ADDR: %d, rdata: %d, arr_data: %d", tr.addr, tr.data_m_rd, arr[tr.addr]), UVM_NONE);
			end
		end
		$display("----------------------------------------------------------------");
	endfunction
endclass

////////////////////////////////////////////////////////////////////////

class agent extends uvm_agent;
	`uvm_component_utils(agent)
	
	drv d;
	uvm_sequencer#(transaction) seqr;
	mon m;
	
	function new(input string path = "agent", uvm_component parent = null);
		super.new(path,parent);
	endfunction
	
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		m = mon::type_id::create("m", this);
		d = drv::type_id::create("d", this);
		seqr = uvm_sequencer#(transaction)::type_id::create("seqr", this);
	endfunction
	
	virtual function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		d.seq_item_port.connect(seqr.seq_item_export);
	endfunction
	
endclass

////////////////////////////////////////////////////////////////////////

class env extends uvm_env;
	`uvm_component_utils(env)
	
	sco s;
	agent a;
	
	function new(input string path = "env", uvm_component parent = null);
		super.new(path,parent);
	endfunction
	
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		s = sco::type_id::create("s", this);
		a = agent::type_id::create("a", this);
	endfunction
	
	virtual function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		a.m.send.connect(s.recv);
	endfunction
	
endclass

////////////////////////////////////////////////////////////////////////

class test extends uvm_test;
	`uvm_component_utils(test)
	
	env e;
	write_data wdata;
	read_data rdata;
	reset_dut rstdut;
	
	function new(input string path = "test", uvm_component parent = null);
		super.new(path,parent);
	endfunction
	
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		e = env::type_id::create("e", this);
		wdata = write_data::type_id::create("wdata",this);
		rdata = read_data::type_id::create("rdata",this);
		rstdut = reset_dut::type_id::create("rstdut",this);
	endfunction
	
	virtual task run_phase(uvm_phase phase);
		phase.raise_objection(this);
		
		rstdut.start(e.a.seqr);
		
		wdata.start(e.a.seqr);
		
		rdata.start(e.a.seqr);
		
		phase.drop_objection(this);
	endtask
endclass

////////////////////////////////////////////////////////////////////////

module tb();
	
	i2c_i vif();
	i2c_mem dut(.clk(vif.clk), .rst(vif.rst), .wr(vif.wr), .start_m(vif.start_m), .addr(vif.addr), .din(vif.din), .data_m_rd(vif.data_m_rd), .done(vif.done));
	
	initial begin
		vif.clk <= 0;
	end
	
	always #10 vif.clk <= ~vif.clk;
	
	initial begin
		uvm_config_db#(virtual i2c_i)::set(null, "*", "vif", vif);
		run_test("test");
	end
	
	initial begin
		$dumpfile("dump.vcd");
		$dumpvars;
	end
endmodule


