# Assign GPIO to LD0 and LD1 on PYNQ-Z1
# PYNQ-Z1 uses the LVCMOS33 voltage standard

# LD0 (led[0])
set_property PACKAGE_PIN R14 [get_ports {gpio_rtl_1_tri_o[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_rtl_1_tri_o[0]}]

# LD1 (led[1])
set_property PACKAGE_PIN P14 [get_ports {gpio_rtl_2_tri_o[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_rtl_2_tri_o[0]}]
