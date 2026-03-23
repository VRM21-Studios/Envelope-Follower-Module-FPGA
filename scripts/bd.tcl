################################################################
# Block Design (BD) Tcl Script for Envelope Follower (V2)
# Target: AMD Kria KV260
################################################################

set design_name ENVELOPE_FOLLOWER

# 1. CREATE PROJECT (If not already opened)
set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project project_1 myproj -part xck26-sfvc784-2LV-c
   set_property BOARD_PART xilinx.com:kv260_som:part0:1.4 [current_project]
}

# 2. CREATE BLOCK DESIGN
if { [get_bd_designs -quiet $design_name] eq "" } {
    create_bd_design $design_name
}
current_bd_design $design_name

# 3. ADD CUSTOM RTL MODULE
# Make sure the source files are already added to the project before running this!
create_bd_cell -type module -reference envelope_follower_axis envelope_follower_ax_0

# 4. ADD IPs
# Zynq UltraScale+ PS
create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.5 zynq_ultra_ps_e_0
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1" }  [get_bd_cells zynq_ultra_ps_e_0]
set_property -dict [list \
    CONFIG.PSU__USE__M_AXI_GP0 {1} \
    CONFIG.PSU__USE__M_AXI_GP1 {0} \
    CONFIG.PSU__USE__S_AXI_GP2 {1} \
    CONFIG.PSU__USE__S_AXI_GP3 {1} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {100} \
] [get_bd_cells zynq_ultra_ps_e_0]

# AXI DMA (No Scatter-Gather, Max Burst 26)
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_0
set_property -dict [list CONFIG.c_include_sg {0} CONFIG.c_sg_length_width {26}] [get_bd_cells axi_dma_0]

# Processor System Reset
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps8_0_99M

# AXI Interconnect (PS to DMA & RTL Control)
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 ps8_0_axi_periph
set_property CONFIG.NUM_MI {2} [get_bd_cells ps8_0_axi_periph]

# SmartConnects (DMA to PS DDR)
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_smc
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_smc_1
set_property CONFIG.NUM_SI {1} [get_bd_cells axi_smc]
set_property CONFIG.NUM_SI {1} [get_bd_cells axi_smc_1]

# 5. MAKE DATA & CONTROL CONNECTIONS
# Data Path (AXI-Stream: DMA -> Envelope Follower -> DMA)
connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXIS_MM2S] [get_bd_intf_pins envelope_follower_ax_0/s_axis]
connect_bd_intf_net [get_bd_intf_pins envelope_follower_ax_0/m_axis] [get_bd_intf_pins axi_dma_0/S_AXIS_S2MM]

# Memory Path (DMA to PS DDR via SmartConnects)
connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXI_MM2S] [get_bd_intf_pins axi_smc/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_smc/M00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HP0_FPD]
connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXI_S2MM] [get_bd_intf_pins axi_smc_1/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_smc_1/M00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HP1_FPD]

# Control Path (PS to AXI-Lite Slaves)
connect_bd_intf_net [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_FPD] [get_bd_intf_pins ps8_0_axi_periph/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins ps8_0_axi_periph/M00_AXI] [get_bd_intf_pins axi_dma_0/S_AXI_LITE]
connect_bd_intf_net [get_bd_intf_pins ps8_0_axi_periph/M01_AXI] [get_bd_intf_pins envelope_follower_ax_0/s_axi]

# 6. MAKE CLOCK & RESET CONNECTIONS
# Clocks
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
    [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_fpd_aclk] \
    [get_bd_pins zynq_ultra_ps_e_0/saxihp0_fpd_aclk] \
    [get_bd_pins zynq_ultra_ps_e_0/saxihp1_fpd_aclk] \
    [get_bd_pins rst_ps8_0_99M/slowest_sync_clk] \
    [get_bd_pins axi_dma_0/s_axi_lite_aclk] \
    [get_bd_pins axi_dma_0/m_axi_mm2s_aclk] \
    [get_bd_pins axi_dma_0/m_axi_s2mm_aclk] \
    [get_bd_pins envelope_follower_ax_0/aclk] \
    [get_bd_pins ps8_0_axi_periph/ACLK] \
    [get_bd_pins ps8_0_axi_periph/S00_ACLK] \
    [get_bd_pins ps8_0_axi_periph/M00_ACLK] \
    [get_bd_pins ps8_0_axi_periph/M01_ACLK] \
    [get_bd_pins axi_smc/aclk] \
    [get_bd_pins axi_smc_1/aclk]

# Resets
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0] [get_bd_pins rst_ps8_0_99M/ext_reset_in]
connect_bd_net [get_bd_pins rst_ps8_0_99M/peripheral_aresetn] \
    [get_bd_pins axi_dma_0/axi_resetn] \
    [get_bd_pins envelope_follower_ax_0/aresetn] \
    [get_bd_pins ps8_0_axi_periph/ARESETN] \
    [get_bd_pins ps8_0_axi_periph/S00_ARESETN] \
    [get_bd_pins ps8_0_axi_periph/M00_ARESETN] \
    [get_bd_pins ps8_0_axi_periph/M01_ARESETN] \
    [get_bd_pins axi_smc/aresetn] \
    [get_bd_pins axi_smc_1/aresetn]

# 7. ADDRESS MAPPING (Vital for PYNQ / Python script)
assign_bd_address -offset 0xA0000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_dma_0/S_AXI_LITE/Reg] -force
assign_bd_address -offset 0xA0010000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs envelope_follower_ax_0/s_axi/reg0] -force

assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces axi_dma_0/Data_MM2S] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_DDR_LOW] -force
assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces axi_dma_0/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP3/HP1_DDR_LOW] -force

# 8. FINALIZE
validate_bd_design
save_bd_design
puts "Block Design <$design_name> created successfully!"
