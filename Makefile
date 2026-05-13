VERILOG_SOURCES = rtl/sync_fifo.sv tb/tb_sync_fifo.sv
SIM ?= verilator

all: sim

sim:
	@if command -v $(SIM) >/dev/null 2>&1 ; then \
		if [ "$(SIM)" = "verilator" ]; then \
			verilator --binary --top-module tb_sync_fifo $(VERILOG_SOURCES) && ./obj_dir/Vtb_sync_fifo ; \
		else \
			$(SIM) -g2012 -o fifo_test $(VERILOG_SOURCES) && vvp fifo_test ; \
		fi \
	else \
		echo "No simulator found for $(SIM). Install verilator or iverilog, or update SIM in the Makefile." ; exit 1 ;\
	fi

clean:
	rm -f fifo_test *.vvp *.vcd obj_dir -rf

