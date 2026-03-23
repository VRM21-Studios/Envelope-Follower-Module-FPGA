################################################################
# Block Design Script (Reference)
#
# Design Name : PEAK
# Target      : Kria KV260 (Zynq UltraScale+ MPSoC)
# Vivado      : 2024.1
#
# Purpose:
# - Documents how rms_peak_axis was integrated into a full system
# - Shows AXI topology, DMA usage, and address mapping
#
# NOTE:
# This script is NOT intended as a portable or generic build system.
################################################################

# --------------------------------------------------------------
# Project & Board
# --------------------------------------------------------------
create_project peak_ref ./peak_ref -part xck26-sfvc784-2LV-c
set_property BOARD_PART xilinx.com:kv260_som:part0:1.4 [current_project]

# --------------------------------------------------------------
# Create Block Design
# --------------------------------------------------------------
set design_name PEAK
create_bd_design $design_name
current_bd_design $design_name

# --------------------------------------------------------------
# Processing System
# --------------------------------------------------------------
set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.5 ps]
# NOTE: PS configuration omitted (auto-generated, board-specific)

# --------------------------------------------------------------
# Custom RTL Module
# --------------------------------------------------------------
# rms_peak_axis must be added to project sources beforehand
set rms [create_bd_cell -type module -reference rms_peak_axis rms_peak_axis_0]

# --------------------------------------------------------------
# AXI DMA (Streaming I/O)
# --------------------------------------------------------------
set dma [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_0]
set_property -dict [list CONFIG.c_include_sg {0}] $dma

# --------------------------------------------------------------
# AXI Interconnect / SmartConnect
# --------------------------------------------------------------
set axi_lite_ic [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_lite_ic]
set_property CONFIG.NUM_MI {2} $axi_lite_ic

set smc_mm2s [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smc_mm2s]
set smc_s2mm [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smc_s2mm]

# --------------------------------------------------------------
# Reset Logic
# --------------------------------------------------------------
set rst [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps]

# --------------------------------------------------------------
# AXI-Stream Connections
# --------------------------------------------------------------
connect_bd_intf_net [get_bd_intf_pins dma/M_AXIS_MM2S] \
                    [get_bd_intf_pins rms/s_axis]

connect_bd_intf_net [get_bd_intf_pins rms/m_axis] \
                    [get_bd_intf_pins dma/S_AXIS_S2MM]

# --------------------------------------------------------------
# AXI-Lite Control Path
# --------------------------------------------------------------
connect_bd_intf_net [get_bd_intf_pins ps/M_AXI_HPM0_FPD] \
                    [get_bd_intf_pins axi_lite_ic/S00_AXI]

connect_bd_intf_net [get_bd_intf_pins axi_lite_ic/M00_AXI] \
                    [get_bd_intf_pins dma/S_AXI_LITE]

connect_bd_intf_net [get_bd_intf_pins axi_lite_ic/M01_AXI] \
                    [get_bd_intf_pins rms/s_axi]

# --------------------------------------------------------------
# High-Performance Memory Paths
# --------------------------------------------------------------
connect_bd_intf_net [get_bd_intf_pins dma/M_AXI_MM2S] \
                    [get_bd_intf_pins smc_mm2s/S00_AXI]

connect_bd_intf_net [get_bd_intf_pins smc_mm2s/M00_AXI] \
                    [get_bd_intf_pins ps/S_AXI_HP0_FPD]

connect_bd_intf_net [get_bd_intf_pins dma/M_AXI_S2MM] \
                    [get_bd_intf_pins smc_s2mm/S00_AXI]

connect_bd_intf_net [get_bd_intf_pins smc_s2mm/M00_AXI] \
                    [get_bd_intf_pins ps/S_AXI_HP1_FPD]

# --------------------------------------------------------------
# Clock & Reset
# --------------------------------------------------------------
connect_bd_net [get_bd_pins ps/pl_clk0] \
               [get_bd_pins dma/m_axi_mm2s_aclk] \
               [get_bd_pins dma/m_axi_s2mm_aclk] \
               [get_bd_pins dma/s_axi_lite_aclk] \
               [get_bd_pins rms/aclk] \
               [get_bd_pins axi_lite_ic/ACLK]

connect_bd_net [get_bd_pins ps/pl_resetn0] \
               [get_bd_pins rst/ext_reset_in]

connect_bd_net [get_bd_pins rst/peripheral_aresetn] \
               [get_bd_pins rms/aresetn] \
               [get_bd_pins dma/axi_resetn]

# --------------------------------------------------------------
# Address Map (Reference)
# --------------------------------------------------------------
assign_bd_address -offset 0xA0000000 -range 0x00010000 \
    [get_bd_addr_segs dma/S_AXI_LITE/Reg]

assign_bd_address -offset 0xA0010000 -range 0x00001000 \
    [get_bd_addr_segs rms/s_axi/reg0]

# --------------------------------------------------------------
# Finalize
# --------------------------------------------------------------
validate_bd_design
save_bd_design
