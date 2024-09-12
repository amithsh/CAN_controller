# Makefile for QuestaSim Automation

# Define directories
RTL_DIR = RTL                # Verilog source directory
SIM_DIR = SIMULATION                # Simulation directory for outputs
WORK_DIR = $(SIM_DIR)/work   # Work directory for Questa compilation
LOG_DIR = $(SIM_DIR)/logs    # Directory for log files

# Define commands
VLIB = vlib                  # Command to create library
VMAP = vmap                  # Command to map library
VLOG = vlog -work $(WORK_DIR) # Command to compile Verilog files
VSIM = vsim -l $(LOG_DIR)/simulation.log # Command to run simulation

# Define the Verilog modules
MODULES = baud_rate_prescaler.v bit_timing_module.v

# Default target: compile and simulate
all: compile simulate

# Compile target: creates the library and compiles the Verilog files
compile:
	mkdir -p $(WORK_DIR) $(LOG_DIR)
	$(VLIB) $(WORK_DIR)
	$(VMAP) work $(WORK_DIR)
	$(VLOG) $(RTL_DIR)/$(MODULES)

# Simulate target: run the simulation with the specified testbench
simulate:
	$(VSIM) work.module_tb

# Clean target: remove compiled files and logs
clean:
	rm -rf $(WORK_DIR) $(LOG_DIR)

# Rebuild target: clean and recompile
rebuild: clean all
