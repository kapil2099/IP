# Makefile for UART testing with iverilog

DESIGN_FILES = uart_tx.v uart_rx.v
TB_FILE = uart_tb.v
TOP_MODULE = uart_tb

.PHONY: all compile simulate view clean

all: simulate

compile:
	iverilog -o uart_test $(DESIGN_FILES) $(TB_FILE)

simulate: compile
	vvp uart_test

view:
	gtkwave uart_tb.vcd

clean:
	rm -f uart_test uart_tb.vcd

help:
	@echo "Available targets:"
	@echo "  compile  - Compile the design and testbench"
	@echo "  simulate - Run the simulation"
	@echo "  view     - Open waveform viewer (requires gtkwave)"
	@echo "  clean    - Clean up generated files"
	@echo "  help     - Show this help message"

