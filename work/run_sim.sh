ghdl -a ../rtl/lcd_write.vhd ../rtl/lcd_controller.vhd ../rtl/lcd_controller_wrapper.vhd ../tb/lcd_controller_wrapper_tb.vhd
ghdl -s ../rtl/lcd_write.vhd ../rtl/lcd_controller.vhd ../rtl/lcd_controller_wrapper.vhd ../tb/lcd_controller_wrapper_tb.vhd
ghdl -e lcd_controller_wrapper_tb
ghdl -r lcd_controller_wrapper_tb --vcd=lcd_controller_wrapper_tb.vcd --stop-time=60000000ns