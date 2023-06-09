#**************************************************************
# This .sdc file is created by Terasic Tool.
# Users are recommended to modify this file to match users logic.
#**************************************************************

#**************************************************************
# Create Clock
#**************************************************************
create_clock -period "50.0 MHz" [get_ports FPGA_CLK1_50]
create_clock -period "50.0 MHz" [get_ports FPGA_CLK2_50]
create_clock -period "50.0 MHz" [get_ports FPGA_CLK3_50]
create_clock -period "200.0 MHz" [get_ports HPS_USB_CLKOUT]
create_clock -period "100.0 MHz" [get_ports HPS_I2C0_SCLK]
create_clock -period "100.0 MHz" [get_ports HPS_I2C1_SCLK]

# for enhancing USB BlasterII to be reliable, 25MHz
create_clock -name {altera_reserved_tck} -period 40 {altera_reserved_tck}
set_input_delay -clock altera_reserved_tck -clock_fall 3 [get_ports altera_reserved_tdi]
set_input_delay -clock altera_reserved_tck -clock_fall 3 [get_ports altera_reserved_tms]
set_output_delay -clock altera_reserved_tck 3 [get_ports altera_reserved_tdo]

#**************************************************************
# Create Generated Clock
#**************************************************************
derive_pll_clocks



#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************
derive_clock_uncertainty



#**************************************************************
# Set Input Delay
#**************************************************************



#**************************************************************
# Set Output Delay
#**************************************************************



#**************************************************************
# Set Clock Groups
#**************************************************************



#**************************************************************
# Set False Path
#**************************************************************
set_false_path -from [get_ports {KEY*}] -to *
set_false_path -from [get_ports {SW*} ] -to *
set_false_path -from * -to [get_ports {LED*}]
set_false_path -from [get_keepers {sRegAddrSyn*}] -to [get_keepers {sRegContentInt*}]
set_false_path -from [get_keepers {*sFpgaReg*}] -to [get_keepers {sRegContentInt*}]
set_false_path -from [get_keepers {*sHpsReg*}] -to [get_keepers {sRegContentInt*}]
set_false_path -from [get_keepers {*data_out*}] -to [get_keepers {sRegAddrInt*}]


#**************************************************************
# Set Multicycle Path
#**************************************************************



#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************



#**************************************************************
# Set Load
#**************************************************************
