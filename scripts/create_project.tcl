# ==============================================================================
# Vivado Project Creation Script: ENVELOPE_FOLLOWER (V2 Linear Ramp)
# Target Board: AMD Kria KV260
# ==============================================================================

set proj_name "ENVELOPE_FOLLOWER"
set origin_dir "."

# ==============================================================================
# 1. CREATE PROJECT & SET BOARD
# ==============================================================================
create_project $proj_name ./$proj_name -part xck26-sfvc784-2LV-c -force
set_property board_part xilinx.com:kv260_som:part0:1.4 [current_project]

# ==============================================================================
# 2. ADD SOURCE & SIMULATION FILES
# Note: Sesuaikan path ini jika kamu menaruh file .v di dalam folder khusus (misal ./src)
# ==============================================================================
add_files -fileset sources_1 [list \
    "$origin_dir/envelope_follower_core.v" \
    "$origin_dir/envelope_follower_axis.v" \
]

add_files -fileset sim_1 [list \
    "$origin_dir/tb_envelope_follower_core.v" \
    "$origin_dir/tb_envelope_follower_axis.v" \
]
set_property top tb_envelope_follower_axis [get_filesets sim_1]

# ==============================================================================
# 3. CREATE BLOCK DESIGN (Minified)
# ==============================================================================
create_bd_design $proj_name
current_bd_design $proj_name

# Add Custom RTL
create_bd_cell -type module -reference envelope_follower_axis envelope_follower_ax_0

# Add Zynq PS and auto-configure for Kria KV260
create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.5 zynq_ultra_ps_e_0
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1" } [get_bd_cells zynq_ultra_ps_e_0]
set_property -dict [list CONFIG.PSU__USE__M_AXI_GP0 {1} CONFIG.PSU__USE__S_AXI_GP2 {1} CONFIG.PSU__USE__S_AXI_GP3 {1} CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {100}] [get_bd_cells zynq_ultra_ps_e_0]

# Add DMA & Infrastructure
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_0
set_property -dict [list CONFIG.c_include_sg {0} CONFIG.c_sg_length_width {26}] [get_bd_cells axi_dma_0]
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps8_0_99M
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 ps8_0_axi_periph
set_property CONFIG.NUM_MI {2} [get_bd_cells ps8_0_axi_periph]
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_smc
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_smc_1

# Connect Data Path (AXI-Stream)
connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXIS_MM2S] [get_bd_intf_pins envelope_follower_ax_0/s_axis]
connect_bd_intf_net [get_bd_intf_pins envelope_follower_ax_0/m_axis] [get_bd_intf_pins axi_dma_0/S_AXIS_S2MM]

# Connect Memory Path (AXI DMA to PS)
connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXI_MM2S] [get_bd_intf_pins axi_smc/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_smc/M00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HP0_FPD]
connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXI_S2MM] [get_bd_intf_pins axi_smc_1/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_smc_1/M00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HP1_FPD]

# Connect Control Path (AXI-Lite)
connect_bd_intf_net [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_FPD] [get_bd_intf_pins ps8_0_axi_periph/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins ps8_0_axi_periph/M00_AXI] [get_bd_intf_pins axi_dma_0/S_AXI_LITE]
connect_bd_intf_net [get_bd_intf_pins ps8_0_axi_periph/M01_AXI] [get_bd_intf_pins envelope_follower_ax_0/s_axi]

# Connect Clocks & Resets (Auto-routed for simplicity)
apply_bd_automation -rule xilinx.com:bd_rule:clkrst -config { Clk {/zynq_ultra_ps_e_0/pl_clk0 (100 MHz)} Freq {100} Ref_Clk0 {} Ref_Clk1 {} }  [get_bd_pins axi_dma_0/s_axi_lite_aclk]
apply_bd_automation -rule xilinx.com:bd_rule:clkrst -config { Clk {/zynq_ultra_ps_e_0/pl_clk0 (100 MHz)} Freq {100} Ref_Clk0 {} Ref_Clk1 {} }  [get_bd_pins envelope_follower_ax_0/aclk]

# Address Map (Crucial for PYNQ Python script)
assign_bd_address -offset 0xA0000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_dma_0/S_AXI_LITE/Reg] -force
assign_bd_address -offset 0xA0010000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs envelope_follower_ax_0/s_axi/reg0] -force
assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces axi_dma_0/Data_MM2S] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_DDR_LOW] -force
assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces axi_dma_0/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP3/HP1_DDR_LOW] -force

save_bd_design

# ==============================================================================
# 4. GENERATE HDL WRAPPER & FINISH
# ==============================================================================
set wrapper_path [make_wrapper -fileset sources_1 -files [get_files $proj_name.bd] -top]
add_files -norecurse -fileset sources_1 $wrapper_path
set_property top ${proj_name}_wrapper [get_filesets sources_1]
update_compile_order -fileset sources_1

puts "========================================================="
puts "Project $proj_name successfully created and configured!"
puts "========================================================="
