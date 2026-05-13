VERILOG_SOURCES = rtl/sync_fifo.sv tb/tb_sync_fifo.sv
SIM ?= iverilog

all: sim

sim:
	@if command -v $(SIM) >/dev/null 2>&1 ; then \
		$(SIM) -g2012 -o fifo_test $(VERILOG_SOURCES) && vvp fifo_test ;\
	else \
		echo "No simulator found for $(SIM). Install iverilog or update SIM in the Makefile." ; exit 1 ;\
	fi

clean:
	rm -f fifo_test *.vvp *.vcd
