set_property PACKAGE_PIN AL8 [get_ports clk_p]
set_property PACKAGE_PIN AL7 [get_ports clk_n]

# C?u hình chu?n I/O là DIFF_SSTL12 (B?t bu?c theo tài li?u bo m?ch)
set_property IOSTANDARD DIFF_SSTL12 [get_ports clk_p]
set_property IOSTANDARD DIFF_SSTL12 [get_ports clk_n]

# T?o clock constraint cho Vivado bi?t t?n s? 300MHz (Chu k? = 3.333ns)
create_clock -period 3.105 -name sys_clk_pin [get_ports clk_p]

set_property PACKAGE_PIN AG15 [get_ports rst_in]
set_property IOSTANDARD LVCMOS33 [get_ports rst_in]

# ----------------------------------------------------------------------------
# Start Signal: S? d?ng DIP Switch 0 (GPIO_DIP_SW0)
# ----------------------------------------------------------------------------
set_property PACKAGE_PIN AE14 [get_ports start]
set_property IOSTANDARD LVCMOS33 [get_ports start]

# ----------------------------------------------------------------------------
# Algo Select [2:0]: S? d?ng DIP Switch 1, 2, 3
# ----------------------------------------------------------------------------
set_property PACKAGE_PIN AN14 [get_ports {algo_sel[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {algo_sel[0]}]

set_property PACKAGE_PIN AP14 [get_ports {algo_sel[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {algo_sel[1]}]

#status
set_property PACKAGE_PIN AM14 [get_ports {server_en[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {server_en[0]}]

set_property PACKAGE_PIN AN13 [get_ports {server_en[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {server_en[1]}]

set_property PACKAGE_PIN AN12 [get_ports {server_en[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {server_en[2]}]

set_property PACKAGE_PIN AP12 [get_ports {server_en[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {server_en[3]}]

set_property PACKAGE_PIN AL13 [get_ports {server_en[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {server_en[4]}]

set_property PACKAGE_PIN AK13 [get_ports {server_en[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {server_en[5]}]

# Done LED (DS37)
set_property PACKAGE_PIN AG14 [get_ports done]
set_property IOSTANDARD LVCMOS33 [get_ports done]

create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list clk_core_BUFG]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 20 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {u_shm_top/hb_pkt_cnt[0]} {u_shm_top/hb_pkt_cnt[1]} {u_shm_top/hb_pkt_cnt[2]} {u_shm_top/hb_pkt_cnt[3]} {u_shm_top/hb_pkt_cnt[4]} {u_shm_top/hb_pkt_cnt[5]} {u_shm_top/hb_pkt_cnt[6]} {u_shm_top/hb_pkt_cnt[7]} {u_shm_top/hb_pkt_cnt[8]} {u_shm_top/hb_pkt_cnt[9]} {u_shm_top/hb_pkt_cnt[10]} {u_shm_top/hb_pkt_cnt[11]} {u_shm_top/hb_pkt_cnt[12]} {u_shm_top/hb_pkt_cnt[13]} {u_shm_top/hb_pkt_cnt[14]} {u_shm_top/hb_pkt_cnt[15]} {u_shm_top/hb_pkt_cnt[16]} {u_shm_top/hb_pkt_cnt[17]} {u_shm_top/hb_pkt_cnt[18]} {u_shm_top/hb_pkt_cnt[19]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 15 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {dbg_cnt_hb_req_rx[15][0]} {dbg_cnt_hb_req_rx[15][1]} {dbg_cnt_hb_req_rx[15][2]} {dbg_cnt_hb_req_rx[15][3]} {dbg_cnt_hb_req_rx[15][4]} {dbg_cnt_hb_req_rx[15][5]} {dbg_cnt_hb_req_rx[15][6]} {dbg_cnt_hb_req_rx[15][7]} {dbg_cnt_hb_req_rx[15][8]} {dbg_cnt_hb_req_rx[15][9]} {dbg_cnt_hb_req_rx[15][10]} {dbg_cnt_hb_req_rx[15][11]} {dbg_cnt_hb_req_rx[15][12]} {dbg_cnt_hb_req_rx[15][13]} {dbg_cnt_hb_req_rx[15][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 15 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {dbg_cnt_hb_req_rx[16][0]} {dbg_cnt_hb_req_rx[16][1]} {dbg_cnt_hb_req_rx[16][2]} {dbg_cnt_hb_req_rx[16][3]} {dbg_cnt_hb_req_rx[16][4]} {dbg_cnt_hb_req_rx[16][5]} {dbg_cnt_hb_req_rx[16][6]} {dbg_cnt_hb_req_rx[16][7]} {dbg_cnt_hb_req_rx[16][8]} {dbg_cnt_hb_req_rx[16][9]} {dbg_cnt_hb_req_rx[16][10]} {dbg_cnt_hb_req_rx[16][11]} {dbg_cnt_hb_req_rx[16][12]} {dbg_cnt_hb_req_rx[16][13]} {dbg_cnt_hb_req_rx[16][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 15 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {dbg_cnt_hb_req_rx[17][0]} {dbg_cnt_hb_req_rx[17][1]} {dbg_cnt_hb_req_rx[17][2]} {dbg_cnt_hb_req_rx[17][3]} {dbg_cnt_hb_req_rx[17][4]} {dbg_cnt_hb_req_rx[17][5]} {dbg_cnt_hb_req_rx[17][6]} {dbg_cnt_hb_req_rx[17][7]} {dbg_cnt_hb_req_rx[17][8]} {dbg_cnt_hb_req_rx[17][9]} {dbg_cnt_hb_req_rx[17][10]} {dbg_cnt_hb_req_rx[17][11]} {dbg_cnt_hb_req_rx[17][12]} {dbg_cnt_hb_req_rx[17][13]} {dbg_cnt_hb_req_rx[17][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 15 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {dbg_cnt_hb_req_rx[22][0]} {dbg_cnt_hb_req_rx[22][1]} {dbg_cnt_hb_req_rx[22][2]} {dbg_cnt_hb_req_rx[22][3]} {dbg_cnt_hb_req_rx[22][4]} {dbg_cnt_hb_req_rx[22][5]} {dbg_cnt_hb_req_rx[22][6]} {dbg_cnt_hb_req_rx[22][7]} {dbg_cnt_hb_req_rx[22][8]} {dbg_cnt_hb_req_rx[22][9]} {dbg_cnt_hb_req_rx[22][10]} {dbg_cnt_hb_req_rx[22][11]} {dbg_cnt_hb_req_rx[22][12]} {dbg_cnt_hb_req_rx[22][13]} {dbg_cnt_hb_req_rx[22][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 15 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {dbg_cnt_hb_req_rx[23][0]} {dbg_cnt_hb_req_rx[23][1]} {dbg_cnt_hb_req_rx[23][2]} {dbg_cnt_hb_req_rx[23][3]} {dbg_cnt_hb_req_rx[23][4]} {dbg_cnt_hb_req_rx[23][5]} {dbg_cnt_hb_req_rx[23][6]} {dbg_cnt_hb_req_rx[23][7]} {dbg_cnt_hb_req_rx[23][8]} {dbg_cnt_hb_req_rx[23][9]} {dbg_cnt_hb_req_rx[23][10]} {dbg_cnt_hb_req_rx[23][11]} {dbg_cnt_hb_req_rx[23][12]} {dbg_cnt_hb_req_rx[23][13]} {dbg_cnt_hb_req_rx[23][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 32 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {cycle_cnt[0]} {cycle_cnt[1]} {cycle_cnt[2]} {cycle_cnt[3]} {cycle_cnt[4]} {cycle_cnt[5]} {cycle_cnt[6]} {cycle_cnt[7]} {cycle_cnt[8]} {cycle_cnt[9]} {cycle_cnt[10]} {cycle_cnt[11]} {cycle_cnt[12]} {cycle_cnt[13]} {cycle_cnt[14]} {cycle_cnt[15]} {cycle_cnt[16]} {cycle_cnt[17]} {cycle_cnt[18]} {cycle_cnt[19]} {cycle_cnt[20]} {cycle_cnt[21]} {cycle_cnt[22]} {cycle_cnt[23]} {cycle_cnt[24]} {cycle_cnt[25]} {cycle_cnt[26]} {cycle_cnt[27]} {cycle_cnt[28]} {cycle_cnt[29]} {cycle_cnt[30]} {cycle_cnt[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 15 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {dbg_cnt_hb_req_rx[25][0]} {dbg_cnt_hb_req_rx[25][1]} {dbg_cnt_hb_req_rx[25][2]} {dbg_cnt_hb_req_rx[25][3]} {dbg_cnt_hb_req_rx[25][4]} {dbg_cnt_hb_req_rx[25][5]} {dbg_cnt_hb_req_rx[25][6]} {dbg_cnt_hb_req_rx[25][7]} {dbg_cnt_hb_req_rx[25][8]} {dbg_cnt_hb_req_rx[25][9]} {dbg_cnt_hb_req_rx[25][10]} {dbg_cnt_hb_req_rx[25][11]} {dbg_cnt_hb_req_rx[25][12]} {dbg_cnt_hb_req_rx[25][13]} {dbg_cnt_hb_req_rx[25][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 15 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list {dbg_cnt_hb_req_rx[27][0]} {dbg_cnt_hb_req_rx[27][1]} {dbg_cnt_hb_req_rx[27][2]} {dbg_cnt_hb_req_rx[27][3]} {dbg_cnt_hb_req_rx[27][4]} {dbg_cnt_hb_req_rx[27][5]} {dbg_cnt_hb_req_rx[27][6]} {dbg_cnt_hb_req_rx[27][7]} {dbg_cnt_hb_req_rx[27][8]} {dbg_cnt_hb_req_rx[27][9]} {dbg_cnt_hb_req_rx[27][10]} {dbg_cnt_hb_req_rx[27][11]} {dbg_cnt_hb_req_rx[27][12]} {dbg_cnt_hb_req_rx[27][13]} {dbg_cnt_hb_req_rx[27][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 15 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list {dbg_cnt_hb_req_rx[28][0]} {dbg_cnt_hb_req_rx[28][1]} {dbg_cnt_hb_req_rx[28][2]} {dbg_cnt_hb_req_rx[28][3]} {dbg_cnt_hb_req_rx[28][4]} {dbg_cnt_hb_req_rx[28][5]} {dbg_cnt_hb_req_rx[28][6]} {dbg_cnt_hb_req_rx[28][7]} {dbg_cnt_hb_req_rx[28][8]} {dbg_cnt_hb_req_rx[28][9]} {dbg_cnt_hb_req_rx[28][10]} {dbg_cnt_hb_req_rx[28][11]} {dbg_cnt_hb_req_rx[28][12]} {dbg_cnt_hb_req_rx[28][13]} {dbg_cnt_hb_req_rx[28][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
set_property port_width 15 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list {dbg_cnt_hb_req_rx[29][0]} {dbg_cnt_hb_req_rx[29][1]} {dbg_cnt_hb_req_rx[29][2]} {dbg_cnt_hb_req_rx[29][3]} {dbg_cnt_hb_req_rx[29][4]} {dbg_cnt_hb_req_rx[29][5]} {dbg_cnt_hb_req_rx[29][6]} {dbg_cnt_hb_req_rx[29][7]} {dbg_cnt_hb_req_rx[29][8]} {dbg_cnt_hb_req_rx[29][9]} {dbg_cnt_hb_req_rx[29][10]} {dbg_cnt_hb_req_rx[29][11]} {dbg_cnt_hb_req_rx[29][12]} {dbg_cnt_hb_req_rx[29][13]} {dbg_cnt_hb_req_rx[29][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
set_property port_width 15 [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list {dbg_cnt_hb_req_rx[2][0]} {dbg_cnt_hb_req_rx[2][1]} {dbg_cnt_hb_req_rx[2][2]} {dbg_cnt_hb_req_rx[2][3]} {dbg_cnt_hb_req_rx[2][4]} {dbg_cnt_hb_req_rx[2][5]} {dbg_cnt_hb_req_rx[2][6]} {dbg_cnt_hb_req_rx[2][7]} {dbg_cnt_hb_req_rx[2][8]} {dbg_cnt_hb_req_rx[2][9]} {dbg_cnt_hb_req_rx[2][10]} {dbg_cnt_hb_req_rx[2][11]} {dbg_cnt_hb_req_rx[2][12]} {dbg_cnt_hb_req_rx[2][13]} {dbg_cnt_hb_req_rx[2][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
set_property port_width 15 [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list {dbg_cnt_hb_req_rx[30][0]} {dbg_cnt_hb_req_rx[30][1]} {dbg_cnt_hb_req_rx[30][2]} {dbg_cnt_hb_req_rx[30][3]} {dbg_cnt_hb_req_rx[30][4]} {dbg_cnt_hb_req_rx[30][5]} {dbg_cnt_hb_req_rx[30][6]} {dbg_cnt_hb_req_rx[30][7]} {dbg_cnt_hb_req_rx[30][8]} {dbg_cnt_hb_req_rx[30][9]} {dbg_cnt_hb_req_rx[30][10]} {dbg_cnt_hb_req_rx[30][11]} {dbg_cnt_hb_req_rx[30][12]} {dbg_cnt_hb_req_rx[30][13]} {dbg_cnt_hb_req_rx[30][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
set_property port_width 15 [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list {dbg_cnt_hb_req_rx[0][0]} {dbg_cnt_hb_req_rx[0][1]} {dbg_cnt_hb_req_rx[0][2]} {dbg_cnt_hb_req_rx[0][3]} {dbg_cnt_hb_req_rx[0][4]} {dbg_cnt_hb_req_rx[0][5]} {dbg_cnt_hb_req_rx[0][6]} {dbg_cnt_hb_req_rx[0][7]} {dbg_cnt_hb_req_rx[0][8]} {dbg_cnt_hb_req_rx[0][9]} {dbg_cnt_hb_req_rx[0][10]} {dbg_cnt_hb_req_rx[0][11]} {dbg_cnt_hb_req_rx[0][12]} {dbg_cnt_hb_req_rx[0][13]} {dbg_cnt_hb_req_rx[0][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
set_property port_width 15 [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list {dbg_cnt_hb_req_rx[10][0]} {dbg_cnt_hb_req_rx[10][1]} {dbg_cnt_hb_req_rx[10][2]} {dbg_cnt_hb_req_rx[10][3]} {dbg_cnt_hb_req_rx[10][4]} {dbg_cnt_hb_req_rx[10][5]} {dbg_cnt_hb_req_rx[10][6]} {dbg_cnt_hb_req_rx[10][7]} {dbg_cnt_hb_req_rx[10][8]} {dbg_cnt_hb_req_rx[10][9]} {dbg_cnt_hb_req_rx[10][10]} {dbg_cnt_hb_req_rx[10][11]} {dbg_cnt_hb_req_rx[10][12]} {dbg_cnt_hb_req_rx[10][13]} {dbg_cnt_hb_req_rx[10][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
set_property port_width 15 [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list {dbg_cnt_hb_req_rx[18][0]} {dbg_cnt_hb_req_rx[18][1]} {dbg_cnt_hb_req_rx[18][2]} {dbg_cnt_hb_req_rx[18][3]} {dbg_cnt_hb_req_rx[18][4]} {dbg_cnt_hb_req_rx[18][5]} {dbg_cnt_hb_req_rx[18][6]} {dbg_cnt_hb_req_rx[18][7]} {dbg_cnt_hb_req_rx[18][8]} {dbg_cnt_hb_req_rx[18][9]} {dbg_cnt_hb_req_rx[18][10]} {dbg_cnt_hb_req_rx[18][11]} {dbg_cnt_hb_req_rx[18][12]} {dbg_cnt_hb_req_rx[18][13]} {dbg_cnt_hb_req_rx[18][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe16]
set_property port_width 15 [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list {dbg_cnt_hb_req_rx[31][0]} {dbg_cnt_hb_req_rx[31][1]} {dbg_cnt_hb_req_rx[31][2]} {dbg_cnt_hb_req_rx[31][3]} {dbg_cnt_hb_req_rx[31][4]} {dbg_cnt_hb_req_rx[31][5]} {dbg_cnt_hb_req_rx[31][6]} {dbg_cnt_hb_req_rx[31][7]} {dbg_cnt_hb_req_rx[31][8]} {dbg_cnt_hb_req_rx[31][9]} {dbg_cnt_hb_req_rx[31][10]} {dbg_cnt_hb_req_rx[31][11]} {dbg_cnt_hb_req_rx[31][12]} {dbg_cnt_hb_req_rx[31][13]} {dbg_cnt_hb_req_rx[31][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe17]
set_property port_width 15 [get_debug_ports u_ila_0/probe17]
connect_debug_port u_ila_0/probe17 [get_nets [list {dbg_cnt_hb_req_rx[3][0]} {dbg_cnt_hb_req_rx[3][1]} {dbg_cnt_hb_req_rx[3][2]} {dbg_cnt_hb_req_rx[3][3]} {dbg_cnt_hb_req_rx[3][4]} {dbg_cnt_hb_req_rx[3][5]} {dbg_cnt_hb_req_rx[3][6]} {dbg_cnt_hb_req_rx[3][7]} {dbg_cnt_hb_req_rx[3][8]} {dbg_cnt_hb_req_rx[3][9]} {dbg_cnt_hb_req_rx[3][10]} {dbg_cnt_hb_req_rx[3][11]} {dbg_cnt_hb_req_rx[3][12]} {dbg_cnt_hb_req_rx[3][13]} {dbg_cnt_hb_req_rx[3][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe18]
set_property port_width 15 [get_debug_ports u_ila_0/probe18]
connect_debug_port u_ila_0/probe18 [get_nets [list {dbg_cnt_hb_req_rx[13][0]} {dbg_cnt_hb_req_rx[13][1]} {dbg_cnt_hb_req_rx[13][2]} {dbg_cnt_hb_req_rx[13][3]} {dbg_cnt_hb_req_rx[13][4]} {dbg_cnt_hb_req_rx[13][5]} {dbg_cnt_hb_req_rx[13][6]} {dbg_cnt_hb_req_rx[13][7]} {dbg_cnt_hb_req_rx[13][8]} {dbg_cnt_hb_req_rx[13][9]} {dbg_cnt_hb_req_rx[13][10]} {dbg_cnt_hb_req_rx[13][11]} {dbg_cnt_hb_req_rx[13][12]} {dbg_cnt_hb_req_rx[13][13]} {dbg_cnt_hb_req_rx[13][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe19]
set_property port_width 15 [get_debug_ports u_ila_0/probe19]
connect_debug_port u_ila_0/probe19 [get_nets [list {dbg_cnt_hb_req_rx[24][0]} {dbg_cnt_hb_req_rx[24][1]} {dbg_cnt_hb_req_rx[24][2]} {dbg_cnt_hb_req_rx[24][3]} {dbg_cnt_hb_req_rx[24][4]} {dbg_cnt_hb_req_rx[24][5]} {dbg_cnt_hb_req_rx[24][6]} {dbg_cnt_hb_req_rx[24][7]} {dbg_cnt_hb_req_rx[24][8]} {dbg_cnt_hb_req_rx[24][9]} {dbg_cnt_hb_req_rx[24][10]} {dbg_cnt_hb_req_rx[24][11]} {dbg_cnt_hb_req_rx[24][12]} {dbg_cnt_hb_req_rx[24][13]} {dbg_cnt_hb_req_rx[24][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe20]
set_property port_width 15 [get_debug_ports u_ila_0/probe20]
connect_debug_port u_ila_0/probe20 [get_nets [list {dbg_cnt_hb_req_rx[26][0]} {dbg_cnt_hb_req_rx[26][1]} {dbg_cnt_hb_req_rx[26][2]} {dbg_cnt_hb_req_rx[26][3]} {dbg_cnt_hb_req_rx[26][4]} {dbg_cnt_hb_req_rx[26][5]} {dbg_cnt_hb_req_rx[26][6]} {dbg_cnt_hb_req_rx[26][7]} {dbg_cnt_hb_req_rx[26][8]} {dbg_cnt_hb_req_rx[26][9]} {dbg_cnt_hb_req_rx[26][10]} {dbg_cnt_hb_req_rx[26][11]} {dbg_cnt_hb_req_rx[26][12]} {dbg_cnt_hb_req_rx[26][13]} {dbg_cnt_hb_req_rx[26][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe21]
set_property port_width 15 [get_debug_ports u_ila_0/probe21]
connect_debug_port u_ila_0/probe21 [get_nets [list {dbg_cnt_hb_req_rx[4][0]} {dbg_cnt_hb_req_rx[4][1]} {dbg_cnt_hb_req_rx[4][2]} {dbg_cnt_hb_req_rx[4][3]} {dbg_cnt_hb_req_rx[4][4]} {dbg_cnt_hb_req_rx[4][5]} {dbg_cnt_hb_req_rx[4][6]} {dbg_cnt_hb_req_rx[4][7]} {dbg_cnt_hb_req_rx[4][8]} {dbg_cnt_hb_req_rx[4][9]} {dbg_cnt_hb_req_rx[4][10]} {dbg_cnt_hb_req_rx[4][11]} {dbg_cnt_hb_req_rx[4][12]} {dbg_cnt_hb_req_rx[4][13]} {dbg_cnt_hb_req_rx[4][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe22]
set_property port_width 2 [get_debug_ports u_ila_0/probe22]
connect_debug_port u_ila_0/probe22 [get_nets [list {algo_sel_dbg[0]} {algo_sel_dbg[1]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe23]
set_property port_width 15 [get_debug_ports u_ila_0/probe23]
connect_debug_port u_ila_0/probe23 [get_nets [list {dbg_cnt_hb_req_rx[11][0]} {dbg_cnt_hb_req_rx[11][1]} {dbg_cnt_hb_req_rx[11][2]} {dbg_cnt_hb_req_rx[11][3]} {dbg_cnt_hb_req_rx[11][4]} {dbg_cnt_hb_req_rx[11][5]} {dbg_cnt_hb_req_rx[11][6]} {dbg_cnt_hb_req_rx[11][7]} {dbg_cnt_hb_req_rx[11][8]} {dbg_cnt_hb_req_rx[11][9]} {dbg_cnt_hb_req_rx[11][10]} {dbg_cnt_hb_req_rx[11][11]} {dbg_cnt_hb_req_rx[11][12]} {dbg_cnt_hb_req_rx[11][13]} {dbg_cnt_hb_req_rx[11][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe24]
set_property port_width 15 [get_debug_ports u_ila_0/probe24]
connect_debug_port u_ila_0/probe24 [get_nets [list {dbg_cnt_hb_req_rx[19][0]} {dbg_cnt_hb_req_rx[19][1]} {dbg_cnt_hb_req_rx[19][2]} {dbg_cnt_hb_req_rx[19][3]} {dbg_cnt_hb_req_rx[19][4]} {dbg_cnt_hb_req_rx[19][5]} {dbg_cnt_hb_req_rx[19][6]} {dbg_cnt_hb_req_rx[19][7]} {dbg_cnt_hb_req_rx[19][8]} {dbg_cnt_hb_req_rx[19][9]} {dbg_cnt_hb_req_rx[19][10]} {dbg_cnt_hb_req_rx[19][11]} {dbg_cnt_hb_req_rx[19][12]} {dbg_cnt_hb_req_rx[19][13]} {dbg_cnt_hb_req_rx[19][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe25]
set_property port_width 32 [get_debug_ports u_ila_0/probe25]
connect_debug_port u_ila_0/probe25 [get_nets [list {beat_cnt[0]} {beat_cnt[1]} {beat_cnt[2]} {beat_cnt[3]} {beat_cnt[4]} {beat_cnt[5]} {beat_cnt[6]} {beat_cnt[7]} {beat_cnt[8]} {beat_cnt[9]} {beat_cnt[10]} {beat_cnt[11]} {beat_cnt[12]} {beat_cnt[13]} {beat_cnt[14]} {beat_cnt[15]} {beat_cnt[16]} {beat_cnt[17]} {beat_cnt[18]} {beat_cnt[19]} {beat_cnt[20]} {beat_cnt[21]} {beat_cnt[22]} {beat_cnt[23]} {beat_cnt[24]} {beat_cnt[25]} {beat_cnt[26]} {beat_cnt[27]} {beat_cnt[28]} {beat_cnt[29]} {beat_cnt[30]} {beat_cnt[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe26]
set_property port_width 15 [get_debug_ports u_ila_0/probe26]
connect_debug_port u_ila_0/probe26 [get_nets [list {dbg_cnt_hb_req_rx[1][0]} {dbg_cnt_hb_req_rx[1][1]} {dbg_cnt_hb_req_rx[1][2]} {dbg_cnt_hb_req_rx[1][3]} {dbg_cnt_hb_req_rx[1][4]} {dbg_cnt_hb_req_rx[1][5]} {dbg_cnt_hb_req_rx[1][6]} {dbg_cnt_hb_req_rx[1][7]} {dbg_cnt_hb_req_rx[1][8]} {dbg_cnt_hb_req_rx[1][9]} {dbg_cnt_hb_req_rx[1][10]} {dbg_cnt_hb_req_rx[1][11]} {dbg_cnt_hb_req_rx[1][12]} {dbg_cnt_hb_req_rx[1][13]} {dbg_cnt_hb_req_rx[1][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe27]
set_property port_width 15 [get_debug_ports u_ila_0/probe27]
connect_debug_port u_ila_0/probe27 [get_nets [list {dbg_cnt_hb_req_rx[20][0]} {dbg_cnt_hb_req_rx[20][1]} {dbg_cnt_hb_req_rx[20][2]} {dbg_cnt_hb_req_rx[20][3]} {dbg_cnt_hb_req_rx[20][4]} {dbg_cnt_hb_req_rx[20][5]} {dbg_cnt_hb_req_rx[20][6]} {dbg_cnt_hb_req_rx[20][7]} {dbg_cnt_hb_req_rx[20][8]} {dbg_cnt_hb_req_rx[20][9]} {dbg_cnt_hb_req_rx[20][10]} {dbg_cnt_hb_req_rx[20][11]} {dbg_cnt_hb_req_rx[20][12]} {dbg_cnt_hb_req_rx[20][13]} {dbg_cnt_hb_req_rx[20][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe28]
set_property port_width 15 [get_debug_ports u_ila_0/probe28]
connect_debug_port u_ila_0/probe28 [get_nets [list {dbg_cnt_hb_req_rx[21][0]} {dbg_cnt_hb_req_rx[21][1]} {dbg_cnt_hb_req_rx[21][2]} {dbg_cnt_hb_req_rx[21][3]} {dbg_cnt_hb_req_rx[21][4]} {dbg_cnt_hb_req_rx[21][5]} {dbg_cnt_hb_req_rx[21][6]} {dbg_cnt_hb_req_rx[21][7]} {dbg_cnt_hb_req_rx[21][8]} {dbg_cnt_hb_req_rx[21][9]} {dbg_cnt_hb_req_rx[21][10]} {dbg_cnt_hb_req_rx[21][11]} {dbg_cnt_hb_req_rx[21][12]} {dbg_cnt_hb_req_rx[21][13]} {dbg_cnt_hb_req_rx[21][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe29]
set_property port_width 2 [get_debug_ports u_ila_0/probe29]
connect_debug_port u_ila_0/probe29 [get_nets [list {algo_sel_IBUF[0]} {algo_sel_IBUF[1]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe30]
set_property port_width 15 [get_debug_ports u_ila_0/probe30]
connect_debug_port u_ila_0/probe30 [get_nets [list {dbg_cnt_hb_req_rx[12][0]} {dbg_cnt_hb_req_rx[12][1]} {dbg_cnt_hb_req_rx[12][2]} {dbg_cnt_hb_req_rx[12][3]} {dbg_cnt_hb_req_rx[12][4]} {dbg_cnt_hb_req_rx[12][5]} {dbg_cnt_hb_req_rx[12][6]} {dbg_cnt_hb_req_rx[12][7]} {dbg_cnt_hb_req_rx[12][8]} {dbg_cnt_hb_req_rx[12][9]} {dbg_cnt_hb_req_rx[12][10]} {dbg_cnt_hb_req_rx[12][11]} {dbg_cnt_hb_req_rx[12][12]} {dbg_cnt_hb_req_rx[12][13]} {dbg_cnt_hb_req_rx[12][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe31]
set_property port_width 15 [get_debug_ports u_ila_0/probe31]
connect_debug_port u_ila_0/probe31 [get_nets [list {dbg_cnt_hb_req_rx[14][0]} {dbg_cnt_hb_req_rx[14][1]} {dbg_cnt_hb_req_rx[14][2]} {dbg_cnt_hb_req_rx[14][3]} {dbg_cnt_hb_req_rx[14][4]} {dbg_cnt_hb_req_rx[14][5]} {dbg_cnt_hb_req_rx[14][6]} {dbg_cnt_hb_req_rx[14][7]} {dbg_cnt_hb_req_rx[14][8]} {dbg_cnt_hb_req_rx[14][9]} {dbg_cnt_hb_req_rx[14][10]} {dbg_cnt_hb_req_rx[14][11]} {dbg_cnt_hb_req_rx[14][12]} {dbg_cnt_hb_req_rx[14][13]} {dbg_cnt_hb_req_rx[14][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe32]
set_property port_width 15 [get_debug_ports u_ila_0/probe32]
connect_debug_port u_ila_0/probe32 [get_nets [list {dbg_cnt_user_req_rx[12][0]} {dbg_cnt_user_req_rx[12][1]} {dbg_cnt_user_req_rx[12][2]} {dbg_cnt_user_req_rx[12][3]} {dbg_cnt_user_req_rx[12][4]} {dbg_cnt_user_req_rx[12][5]} {dbg_cnt_user_req_rx[12][6]} {dbg_cnt_user_req_rx[12][7]} {dbg_cnt_user_req_rx[12][8]} {dbg_cnt_user_req_rx[12][9]} {dbg_cnt_user_req_rx[12][10]} {dbg_cnt_user_req_rx[12][11]} {dbg_cnt_user_req_rx[12][12]} {dbg_cnt_user_req_rx[12][13]} {dbg_cnt_user_req_rx[12][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe33]
set_property port_width 15 [get_debug_ports u_ila_0/probe33]
connect_debug_port u_ila_0/probe33 [get_nets [list {dbg_cnt_hb_req_rx[7][0]} {dbg_cnt_hb_req_rx[7][1]} {dbg_cnt_hb_req_rx[7][2]} {dbg_cnt_hb_req_rx[7][3]} {dbg_cnt_hb_req_rx[7][4]} {dbg_cnt_hb_req_rx[7][5]} {dbg_cnt_hb_req_rx[7][6]} {dbg_cnt_hb_req_rx[7][7]} {dbg_cnt_hb_req_rx[7][8]} {dbg_cnt_hb_req_rx[7][9]} {dbg_cnt_hb_req_rx[7][10]} {dbg_cnt_hb_req_rx[7][11]} {dbg_cnt_hb_req_rx[7][12]} {dbg_cnt_hb_req_rx[7][13]} {dbg_cnt_hb_req_rx[7][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe34]
set_property port_width 15 [get_debug_ports u_ila_0/probe34]
connect_debug_port u_ila_0/probe34 [get_nets [list {dbg_cnt_user_reply_tx[10][0]} {dbg_cnt_user_reply_tx[10][1]} {dbg_cnt_user_reply_tx[10][2]} {dbg_cnt_user_reply_tx[10][3]} {dbg_cnt_user_reply_tx[10][4]} {dbg_cnt_user_reply_tx[10][5]} {dbg_cnt_user_reply_tx[10][6]} {dbg_cnt_user_reply_tx[10][7]} {dbg_cnt_user_reply_tx[10][8]} {dbg_cnt_user_reply_tx[10][9]} {dbg_cnt_user_reply_tx[10][10]} {dbg_cnt_user_reply_tx[10][11]} {dbg_cnt_user_reply_tx[10][12]} {dbg_cnt_user_reply_tx[10][13]} {dbg_cnt_user_reply_tx[10][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe35]
set_property port_width 15 [get_debug_ports u_ila_0/probe35]
connect_debug_port u_ila_0/probe35 [get_nets [list {dbg_cnt_user_reply_tx[12][0]} {dbg_cnt_user_reply_tx[12][1]} {dbg_cnt_user_reply_tx[12][2]} {dbg_cnt_user_reply_tx[12][3]} {dbg_cnt_user_reply_tx[12][4]} {dbg_cnt_user_reply_tx[12][5]} {dbg_cnt_user_reply_tx[12][6]} {dbg_cnt_user_reply_tx[12][7]} {dbg_cnt_user_reply_tx[12][8]} {dbg_cnt_user_reply_tx[12][9]} {dbg_cnt_user_reply_tx[12][10]} {dbg_cnt_user_reply_tx[12][11]} {dbg_cnt_user_reply_tx[12][12]} {dbg_cnt_user_reply_tx[12][13]} {dbg_cnt_user_reply_tx[12][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe36]
set_property port_width 15 [get_debug_ports u_ila_0/probe36]
connect_debug_port u_ila_0/probe36 [get_nets [list {dbg_cnt_user_reply_tx[20][0]} {dbg_cnt_user_reply_tx[20][1]} {dbg_cnt_user_reply_tx[20][2]} {dbg_cnt_user_reply_tx[20][3]} {dbg_cnt_user_reply_tx[20][4]} {dbg_cnt_user_reply_tx[20][5]} {dbg_cnt_user_reply_tx[20][6]} {dbg_cnt_user_reply_tx[20][7]} {dbg_cnt_user_reply_tx[20][8]} {dbg_cnt_user_reply_tx[20][9]} {dbg_cnt_user_reply_tx[20][10]} {dbg_cnt_user_reply_tx[20][11]} {dbg_cnt_user_reply_tx[20][12]} {dbg_cnt_user_reply_tx[20][13]} {dbg_cnt_user_reply_tx[20][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe37]
set_property port_width 15 [get_debug_ports u_ila_0/probe37]
connect_debug_port u_ila_0/probe37 [get_nets [list {dbg_cnt_user_reply_tx[16][0]} {dbg_cnt_user_reply_tx[16][1]} {dbg_cnt_user_reply_tx[16][2]} {dbg_cnt_user_reply_tx[16][3]} {dbg_cnt_user_reply_tx[16][4]} {dbg_cnt_user_reply_tx[16][5]} {dbg_cnt_user_reply_tx[16][6]} {dbg_cnt_user_reply_tx[16][7]} {dbg_cnt_user_reply_tx[16][8]} {dbg_cnt_user_reply_tx[16][9]} {dbg_cnt_user_reply_tx[16][10]} {dbg_cnt_user_reply_tx[16][11]} {dbg_cnt_user_reply_tx[16][12]} {dbg_cnt_user_reply_tx[16][13]} {dbg_cnt_user_reply_tx[16][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe38]
set_property port_width 15 [get_debug_ports u_ila_0/probe38]
connect_debug_port u_ila_0/probe38 [get_nets [list {dbg_cnt_user_reply_tx[6][0]} {dbg_cnt_user_reply_tx[6][1]} {dbg_cnt_user_reply_tx[6][2]} {dbg_cnt_user_reply_tx[6][3]} {dbg_cnt_user_reply_tx[6][4]} {dbg_cnt_user_reply_tx[6][5]} {dbg_cnt_user_reply_tx[6][6]} {dbg_cnt_user_reply_tx[6][7]} {dbg_cnt_user_reply_tx[6][8]} {dbg_cnt_user_reply_tx[6][9]} {dbg_cnt_user_reply_tx[6][10]} {dbg_cnt_user_reply_tx[6][11]} {dbg_cnt_user_reply_tx[6][12]} {dbg_cnt_user_reply_tx[6][13]} {dbg_cnt_user_reply_tx[6][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe39]
set_property port_width 15 [get_debug_ports u_ila_0/probe39]
connect_debug_port u_ila_0/probe39 [get_nets [list {dbg_cnt_user_reply_tx[9][0]} {dbg_cnt_user_reply_tx[9][1]} {dbg_cnt_user_reply_tx[9][2]} {dbg_cnt_user_reply_tx[9][3]} {dbg_cnt_user_reply_tx[9][4]} {dbg_cnt_user_reply_tx[9][5]} {dbg_cnt_user_reply_tx[9][6]} {dbg_cnt_user_reply_tx[9][7]} {dbg_cnt_user_reply_tx[9][8]} {dbg_cnt_user_reply_tx[9][9]} {dbg_cnt_user_reply_tx[9][10]} {dbg_cnt_user_reply_tx[9][11]} {dbg_cnt_user_reply_tx[9][12]} {dbg_cnt_user_reply_tx[9][13]} {dbg_cnt_user_reply_tx[9][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe40]
set_property port_width 15 [get_debug_ports u_ila_0/probe40]
connect_debug_port u_ila_0/probe40 [get_nets [list {dbg_cnt_user_req_rx[18][0]} {dbg_cnt_user_req_rx[18][1]} {dbg_cnt_user_req_rx[18][2]} {dbg_cnt_user_req_rx[18][3]} {dbg_cnt_user_req_rx[18][4]} {dbg_cnt_user_req_rx[18][5]} {dbg_cnt_user_req_rx[18][6]} {dbg_cnt_user_req_rx[18][7]} {dbg_cnt_user_req_rx[18][8]} {dbg_cnt_user_req_rx[18][9]} {dbg_cnt_user_req_rx[18][10]} {dbg_cnt_user_req_rx[18][11]} {dbg_cnt_user_req_rx[18][12]} {dbg_cnt_user_req_rx[18][13]} {dbg_cnt_user_req_rx[18][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe41]
set_property port_width 15 [get_debug_ports u_ila_0/probe41]
connect_debug_port u_ila_0/probe41 [get_nets [list {dbg_cnt_user_req_rx[1][0]} {dbg_cnt_user_req_rx[1][1]} {dbg_cnt_user_req_rx[1][2]} {dbg_cnt_user_req_rx[1][3]} {dbg_cnt_user_req_rx[1][4]} {dbg_cnt_user_req_rx[1][5]} {dbg_cnt_user_req_rx[1][6]} {dbg_cnt_user_req_rx[1][7]} {dbg_cnt_user_req_rx[1][8]} {dbg_cnt_user_req_rx[1][9]} {dbg_cnt_user_req_rx[1][10]} {dbg_cnt_user_req_rx[1][11]} {dbg_cnt_user_req_rx[1][12]} {dbg_cnt_user_req_rx[1][13]} {dbg_cnt_user_req_rx[1][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe42]
set_property port_width 15 [get_debug_ports u_ila_0/probe42]
connect_debug_port u_ila_0/probe42 [get_nets [list {dbg_cnt_user_reply_tx[23][0]} {dbg_cnt_user_reply_tx[23][1]} {dbg_cnt_user_reply_tx[23][2]} {dbg_cnt_user_reply_tx[23][3]} {dbg_cnt_user_reply_tx[23][4]} {dbg_cnt_user_reply_tx[23][5]} {dbg_cnt_user_reply_tx[23][6]} {dbg_cnt_user_reply_tx[23][7]} {dbg_cnt_user_reply_tx[23][8]} {dbg_cnt_user_reply_tx[23][9]} {dbg_cnt_user_reply_tx[23][10]} {dbg_cnt_user_reply_tx[23][11]} {dbg_cnt_user_reply_tx[23][12]} {dbg_cnt_user_reply_tx[23][13]} {dbg_cnt_user_reply_tx[23][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe43]
set_property port_width 15 [get_debug_ports u_ila_0/probe43]
connect_debug_port u_ila_0/probe43 [get_nets [list {dbg_cnt_user_reply_tx[21][0]} {dbg_cnt_user_reply_tx[21][1]} {dbg_cnt_user_reply_tx[21][2]} {dbg_cnt_user_reply_tx[21][3]} {dbg_cnt_user_reply_tx[21][4]} {dbg_cnt_user_reply_tx[21][5]} {dbg_cnt_user_reply_tx[21][6]} {dbg_cnt_user_reply_tx[21][7]} {dbg_cnt_user_reply_tx[21][8]} {dbg_cnt_user_reply_tx[21][9]} {dbg_cnt_user_reply_tx[21][10]} {dbg_cnt_user_reply_tx[21][11]} {dbg_cnt_user_reply_tx[21][12]} {dbg_cnt_user_reply_tx[21][13]} {dbg_cnt_user_reply_tx[21][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe44]
set_property port_width 15 [get_debug_ports u_ila_0/probe44]
connect_debug_port u_ila_0/probe44 [get_nets [list {dbg_cnt_user_req_rx[21][0]} {dbg_cnt_user_req_rx[21][1]} {dbg_cnt_user_req_rx[21][2]} {dbg_cnt_user_req_rx[21][3]} {dbg_cnt_user_req_rx[21][4]} {dbg_cnt_user_req_rx[21][5]} {dbg_cnt_user_req_rx[21][6]} {dbg_cnt_user_req_rx[21][7]} {dbg_cnt_user_req_rx[21][8]} {dbg_cnt_user_req_rx[21][9]} {dbg_cnt_user_req_rx[21][10]} {dbg_cnt_user_req_rx[21][11]} {dbg_cnt_user_req_rx[21][12]} {dbg_cnt_user_req_rx[21][13]} {dbg_cnt_user_req_rx[21][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe45]
set_property port_width 15 [get_debug_ports u_ila_0/probe45]
connect_debug_port u_ila_0/probe45 [get_nets [list {dbg_cnt_user_reply_tx[11][0]} {dbg_cnt_user_reply_tx[11][1]} {dbg_cnt_user_reply_tx[11][2]} {dbg_cnt_user_reply_tx[11][3]} {dbg_cnt_user_reply_tx[11][4]} {dbg_cnt_user_reply_tx[11][5]} {dbg_cnt_user_reply_tx[11][6]} {dbg_cnt_user_reply_tx[11][7]} {dbg_cnt_user_reply_tx[11][8]} {dbg_cnt_user_reply_tx[11][9]} {dbg_cnt_user_reply_tx[11][10]} {dbg_cnt_user_reply_tx[11][11]} {dbg_cnt_user_reply_tx[11][12]} {dbg_cnt_user_reply_tx[11][13]} {dbg_cnt_user_reply_tx[11][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe46]
set_property port_width 15 [get_debug_ports u_ila_0/probe46]
connect_debug_port u_ila_0/probe46 [get_nets [list {dbg_cnt_user_reply_tx[15][0]} {dbg_cnt_user_reply_tx[15][1]} {dbg_cnt_user_reply_tx[15][2]} {dbg_cnt_user_reply_tx[15][3]} {dbg_cnt_user_reply_tx[15][4]} {dbg_cnt_user_reply_tx[15][5]} {dbg_cnt_user_reply_tx[15][6]} {dbg_cnt_user_reply_tx[15][7]} {dbg_cnt_user_reply_tx[15][8]} {dbg_cnt_user_reply_tx[15][9]} {dbg_cnt_user_reply_tx[15][10]} {dbg_cnt_user_reply_tx[15][11]} {dbg_cnt_user_reply_tx[15][12]} {dbg_cnt_user_reply_tx[15][13]} {dbg_cnt_user_reply_tx[15][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe47]
set_property port_width 15 [get_debug_ports u_ila_0/probe47]
connect_debug_port u_ila_0/probe47 [get_nets [list {dbg_cnt_user_reply_tx[18][0]} {dbg_cnt_user_reply_tx[18][1]} {dbg_cnt_user_reply_tx[18][2]} {dbg_cnt_user_reply_tx[18][3]} {dbg_cnt_user_reply_tx[18][4]} {dbg_cnt_user_reply_tx[18][5]} {dbg_cnt_user_reply_tx[18][6]} {dbg_cnt_user_reply_tx[18][7]} {dbg_cnt_user_reply_tx[18][8]} {dbg_cnt_user_reply_tx[18][9]} {dbg_cnt_user_reply_tx[18][10]} {dbg_cnt_user_reply_tx[18][11]} {dbg_cnt_user_reply_tx[18][12]} {dbg_cnt_user_reply_tx[18][13]} {dbg_cnt_user_reply_tx[18][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe48]
set_property port_width 15 [get_debug_ports u_ila_0/probe48]
connect_debug_port u_ila_0/probe48 [get_nets [list {dbg_cnt_user_reply_tx[3][0]} {dbg_cnt_user_reply_tx[3][1]} {dbg_cnt_user_reply_tx[3][2]} {dbg_cnt_user_reply_tx[3][3]} {dbg_cnt_user_reply_tx[3][4]} {dbg_cnt_user_reply_tx[3][5]} {dbg_cnt_user_reply_tx[3][6]} {dbg_cnt_user_reply_tx[3][7]} {dbg_cnt_user_reply_tx[3][8]} {dbg_cnt_user_reply_tx[3][9]} {dbg_cnt_user_reply_tx[3][10]} {dbg_cnt_user_reply_tx[3][11]} {dbg_cnt_user_reply_tx[3][12]} {dbg_cnt_user_reply_tx[3][13]} {dbg_cnt_user_reply_tx[3][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe49]
set_property port_width 15 [get_debug_ports u_ila_0/probe49]
connect_debug_port u_ila_0/probe49 [get_nets [list {dbg_cnt_user_reply_tx[29][0]} {dbg_cnt_user_reply_tx[29][1]} {dbg_cnt_user_reply_tx[29][2]} {dbg_cnt_user_reply_tx[29][3]} {dbg_cnt_user_reply_tx[29][4]} {dbg_cnt_user_reply_tx[29][5]} {dbg_cnt_user_reply_tx[29][6]} {dbg_cnt_user_reply_tx[29][7]} {dbg_cnt_user_reply_tx[29][8]} {dbg_cnt_user_reply_tx[29][9]} {dbg_cnt_user_reply_tx[29][10]} {dbg_cnt_user_reply_tx[29][11]} {dbg_cnt_user_reply_tx[29][12]} {dbg_cnt_user_reply_tx[29][13]} {dbg_cnt_user_reply_tx[29][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe50]
set_property port_width 15 [get_debug_ports u_ila_0/probe50]
connect_debug_port u_ila_0/probe50 [get_nets [list {dbg_cnt_user_reply_tx[30][0]} {dbg_cnt_user_reply_tx[30][1]} {dbg_cnt_user_reply_tx[30][2]} {dbg_cnt_user_reply_tx[30][3]} {dbg_cnt_user_reply_tx[30][4]} {dbg_cnt_user_reply_tx[30][5]} {dbg_cnt_user_reply_tx[30][6]} {dbg_cnt_user_reply_tx[30][7]} {dbg_cnt_user_reply_tx[30][8]} {dbg_cnt_user_reply_tx[30][9]} {dbg_cnt_user_reply_tx[30][10]} {dbg_cnt_user_reply_tx[30][11]} {dbg_cnt_user_reply_tx[30][12]} {dbg_cnt_user_reply_tx[30][13]} {dbg_cnt_user_reply_tx[30][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe51]
set_property port_width 15 [get_debug_ports u_ila_0/probe51]
connect_debug_port u_ila_0/probe51 [get_nets [list {dbg_cnt_hb_req_rx[5][0]} {dbg_cnt_hb_req_rx[5][1]} {dbg_cnt_hb_req_rx[5][2]} {dbg_cnt_hb_req_rx[5][3]} {dbg_cnt_hb_req_rx[5][4]} {dbg_cnt_hb_req_rx[5][5]} {dbg_cnt_hb_req_rx[5][6]} {dbg_cnt_hb_req_rx[5][7]} {dbg_cnt_hb_req_rx[5][8]} {dbg_cnt_hb_req_rx[5][9]} {dbg_cnt_hb_req_rx[5][10]} {dbg_cnt_hb_req_rx[5][11]} {dbg_cnt_hb_req_rx[5][12]} {dbg_cnt_hb_req_rx[5][13]} {dbg_cnt_hb_req_rx[5][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe52]
set_property port_width 15 [get_debug_ports u_ila_0/probe52]
connect_debug_port u_ila_0/probe52 [get_nets [list {dbg_cnt_hb_req_rx[9][0]} {dbg_cnt_hb_req_rx[9][1]} {dbg_cnt_hb_req_rx[9][2]} {dbg_cnt_hb_req_rx[9][3]} {dbg_cnt_hb_req_rx[9][4]} {dbg_cnt_hb_req_rx[9][5]} {dbg_cnt_hb_req_rx[9][6]} {dbg_cnt_hb_req_rx[9][7]} {dbg_cnt_hb_req_rx[9][8]} {dbg_cnt_hb_req_rx[9][9]} {dbg_cnt_hb_req_rx[9][10]} {dbg_cnt_hb_req_rx[9][11]} {dbg_cnt_hb_req_rx[9][12]} {dbg_cnt_hb_req_rx[9][13]} {dbg_cnt_hb_req_rx[9][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe53]
set_property port_width 15 [get_debug_ports u_ila_0/probe53]
connect_debug_port u_ila_0/probe53 [get_nets [list {dbg_cnt_user_reply_tx[4][0]} {dbg_cnt_user_reply_tx[4][1]} {dbg_cnt_user_reply_tx[4][2]} {dbg_cnt_user_reply_tx[4][3]} {dbg_cnt_user_reply_tx[4][4]} {dbg_cnt_user_reply_tx[4][5]} {dbg_cnt_user_reply_tx[4][6]} {dbg_cnt_user_reply_tx[4][7]} {dbg_cnt_user_reply_tx[4][8]} {dbg_cnt_user_reply_tx[4][9]} {dbg_cnt_user_reply_tx[4][10]} {dbg_cnt_user_reply_tx[4][11]} {dbg_cnt_user_reply_tx[4][12]} {dbg_cnt_user_reply_tx[4][13]} {dbg_cnt_user_reply_tx[4][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe54]
set_property port_width 15 [get_debug_ports u_ila_0/probe54]
connect_debug_port u_ila_0/probe54 [get_nets [list {dbg_cnt_user_reply_tx[31][0]} {dbg_cnt_user_reply_tx[31][1]} {dbg_cnt_user_reply_tx[31][2]} {dbg_cnt_user_reply_tx[31][3]} {dbg_cnt_user_reply_tx[31][4]} {dbg_cnt_user_reply_tx[31][5]} {dbg_cnt_user_reply_tx[31][6]} {dbg_cnt_user_reply_tx[31][7]} {dbg_cnt_user_reply_tx[31][8]} {dbg_cnt_user_reply_tx[31][9]} {dbg_cnt_user_reply_tx[31][10]} {dbg_cnt_user_reply_tx[31][11]} {dbg_cnt_user_reply_tx[31][12]} {dbg_cnt_user_reply_tx[31][13]} {dbg_cnt_user_reply_tx[31][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe55]
set_property port_width 15 [get_debug_ports u_ila_0/probe55]
connect_debug_port u_ila_0/probe55 [get_nets [list {dbg_cnt_user_reply_tx[27][0]} {dbg_cnt_user_reply_tx[27][1]} {dbg_cnt_user_reply_tx[27][2]} {dbg_cnt_user_reply_tx[27][3]} {dbg_cnt_user_reply_tx[27][4]} {dbg_cnt_user_reply_tx[27][5]} {dbg_cnt_user_reply_tx[27][6]} {dbg_cnt_user_reply_tx[27][7]} {dbg_cnt_user_reply_tx[27][8]} {dbg_cnt_user_reply_tx[27][9]} {dbg_cnt_user_reply_tx[27][10]} {dbg_cnt_user_reply_tx[27][11]} {dbg_cnt_user_reply_tx[27][12]} {dbg_cnt_user_reply_tx[27][13]} {dbg_cnt_user_reply_tx[27][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe56]
set_property port_width 15 [get_debug_ports u_ila_0/probe56]
connect_debug_port u_ila_0/probe56 [get_nets [list {dbg_cnt_user_req_rx[11][0]} {dbg_cnt_user_req_rx[11][1]} {dbg_cnt_user_req_rx[11][2]} {dbg_cnt_user_req_rx[11][3]} {dbg_cnt_user_req_rx[11][4]} {dbg_cnt_user_req_rx[11][5]} {dbg_cnt_user_req_rx[11][6]} {dbg_cnt_user_req_rx[11][7]} {dbg_cnt_user_req_rx[11][8]} {dbg_cnt_user_req_rx[11][9]} {dbg_cnt_user_req_rx[11][10]} {dbg_cnt_user_req_rx[11][11]} {dbg_cnt_user_req_rx[11][12]} {dbg_cnt_user_req_rx[11][13]} {dbg_cnt_user_req_rx[11][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe57]
set_property port_width 15 [get_debug_ports u_ila_0/probe57]
connect_debug_port u_ila_0/probe57 [get_nets [list {dbg_cnt_user_req_rx[14][0]} {dbg_cnt_user_req_rx[14][1]} {dbg_cnt_user_req_rx[14][2]} {dbg_cnt_user_req_rx[14][3]} {dbg_cnt_user_req_rx[14][4]} {dbg_cnt_user_req_rx[14][5]} {dbg_cnt_user_req_rx[14][6]} {dbg_cnt_user_req_rx[14][7]} {dbg_cnt_user_req_rx[14][8]} {dbg_cnt_user_req_rx[14][9]} {dbg_cnt_user_req_rx[14][10]} {dbg_cnt_user_req_rx[14][11]} {dbg_cnt_user_req_rx[14][12]} {dbg_cnt_user_req_rx[14][13]} {dbg_cnt_user_req_rx[14][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe58]
set_property port_width 15 [get_debug_ports u_ila_0/probe58]
connect_debug_port u_ila_0/probe58 [get_nets [list {dbg_cnt_user_req_rx[19][0]} {dbg_cnt_user_req_rx[19][1]} {dbg_cnt_user_req_rx[19][2]} {dbg_cnt_user_req_rx[19][3]} {dbg_cnt_user_req_rx[19][4]} {dbg_cnt_user_req_rx[19][5]} {dbg_cnt_user_req_rx[19][6]} {dbg_cnt_user_req_rx[19][7]} {dbg_cnt_user_req_rx[19][8]} {dbg_cnt_user_req_rx[19][9]} {dbg_cnt_user_req_rx[19][10]} {dbg_cnt_user_req_rx[19][11]} {dbg_cnt_user_req_rx[19][12]} {dbg_cnt_user_req_rx[19][13]} {dbg_cnt_user_req_rx[19][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe59]
set_property port_width 15 [get_debug_ports u_ila_0/probe59]
connect_debug_port u_ila_0/probe59 [get_nets [list {dbg_cnt_user_req_rx[20][0]} {dbg_cnt_user_req_rx[20][1]} {dbg_cnt_user_req_rx[20][2]} {dbg_cnt_user_req_rx[20][3]} {dbg_cnt_user_req_rx[20][4]} {dbg_cnt_user_req_rx[20][5]} {dbg_cnt_user_req_rx[20][6]} {dbg_cnt_user_req_rx[20][7]} {dbg_cnt_user_req_rx[20][8]} {dbg_cnt_user_req_rx[20][9]} {dbg_cnt_user_req_rx[20][10]} {dbg_cnt_user_req_rx[20][11]} {dbg_cnt_user_req_rx[20][12]} {dbg_cnt_user_req_rx[20][13]} {dbg_cnt_user_req_rx[20][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe60]
set_property port_width 15 [get_debug_ports u_ila_0/probe60]
connect_debug_port u_ila_0/probe60 [get_nets [list {dbg_cnt_user_req_rx[22][0]} {dbg_cnt_user_req_rx[22][1]} {dbg_cnt_user_req_rx[22][2]} {dbg_cnt_user_req_rx[22][3]} {dbg_cnt_user_req_rx[22][4]} {dbg_cnt_user_req_rx[22][5]} {dbg_cnt_user_req_rx[22][6]} {dbg_cnt_user_req_rx[22][7]} {dbg_cnt_user_req_rx[22][8]} {dbg_cnt_user_req_rx[22][9]} {dbg_cnt_user_req_rx[22][10]} {dbg_cnt_user_req_rx[22][11]} {dbg_cnt_user_req_rx[22][12]} {dbg_cnt_user_req_rx[22][13]} {dbg_cnt_user_req_rx[22][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe61]
set_property port_width 15 [get_debug_ports u_ila_0/probe61]
connect_debug_port u_ila_0/probe61 [get_nets [list {dbg_cnt_user_reply_tx[5][0]} {dbg_cnt_user_reply_tx[5][1]} {dbg_cnt_user_reply_tx[5][2]} {dbg_cnt_user_reply_tx[5][3]} {dbg_cnt_user_reply_tx[5][4]} {dbg_cnt_user_reply_tx[5][5]} {dbg_cnt_user_reply_tx[5][6]} {dbg_cnt_user_reply_tx[5][7]} {dbg_cnt_user_reply_tx[5][8]} {dbg_cnt_user_reply_tx[5][9]} {dbg_cnt_user_reply_tx[5][10]} {dbg_cnt_user_reply_tx[5][11]} {dbg_cnt_user_reply_tx[5][12]} {dbg_cnt_user_reply_tx[5][13]} {dbg_cnt_user_reply_tx[5][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe62]
set_property port_width 15 [get_debug_ports u_ila_0/probe62]
connect_debug_port u_ila_0/probe62 [get_nets [list {dbg_cnt_user_req_rx[23][0]} {dbg_cnt_user_req_rx[23][1]} {dbg_cnt_user_req_rx[23][2]} {dbg_cnt_user_req_rx[23][3]} {dbg_cnt_user_req_rx[23][4]} {dbg_cnt_user_req_rx[23][5]} {dbg_cnt_user_req_rx[23][6]} {dbg_cnt_user_req_rx[23][7]} {dbg_cnt_user_req_rx[23][8]} {dbg_cnt_user_req_rx[23][9]} {dbg_cnt_user_req_rx[23][10]} {dbg_cnt_user_req_rx[23][11]} {dbg_cnt_user_req_rx[23][12]} {dbg_cnt_user_req_rx[23][13]} {dbg_cnt_user_req_rx[23][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe63]
set_property port_width 15 [get_debug_ports u_ila_0/probe63]
connect_debug_port u_ila_0/probe63 [get_nets [list {dbg_cnt_user_reply_tx[24][0]} {dbg_cnt_user_reply_tx[24][1]} {dbg_cnt_user_reply_tx[24][2]} {dbg_cnt_user_reply_tx[24][3]} {dbg_cnt_user_reply_tx[24][4]} {dbg_cnt_user_reply_tx[24][5]} {dbg_cnt_user_reply_tx[24][6]} {dbg_cnt_user_reply_tx[24][7]} {dbg_cnt_user_reply_tx[24][8]} {dbg_cnt_user_reply_tx[24][9]} {dbg_cnt_user_reply_tx[24][10]} {dbg_cnt_user_reply_tx[24][11]} {dbg_cnt_user_reply_tx[24][12]} {dbg_cnt_user_reply_tx[24][13]} {dbg_cnt_user_reply_tx[24][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe64]
set_property port_width 15 [get_debug_ports u_ila_0/probe64]
connect_debug_port u_ila_0/probe64 [get_nets [list {dbg_cnt_user_reply_tx[13][0]} {dbg_cnt_user_reply_tx[13][1]} {dbg_cnt_user_reply_tx[13][2]} {dbg_cnt_user_reply_tx[13][3]} {dbg_cnt_user_reply_tx[13][4]} {dbg_cnt_user_reply_tx[13][5]} {dbg_cnt_user_reply_tx[13][6]} {dbg_cnt_user_reply_tx[13][7]} {dbg_cnt_user_reply_tx[13][8]} {dbg_cnt_user_reply_tx[13][9]} {dbg_cnt_user_reply_tx[13][10]} {dbg_cnt_user_reply_tx[13][11]} {dbg_cnt_user_reply_tx[13][12]} {dbg_cnt_user_reply_tx[13][13]} {dbg_cnt_user_reply_tx[13][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe65]
set_property port_width 15 [get_debug_ports u_ila_0/probe65]
connect_debug_port u_ila_0/probe65 [get_nets [list {dbg_cnt_user_req_rx[10][0]} {dbg_cnt_user_req_rx[10][1]} {dbg_cnt_user_req_rx[10][2]} {dbg_cnt_user_req_rx[10][3]} {dbg_cnt_user_req_rx[10][4]} {dbg_cnt_user_req_rx[10][5]} {dbg_cnt_user_req_rx[10][6]} {dbg_cnt_user_req_rx[10][7]} {dbg_cnt_user_req_rx[10][8]} {dbg_cnt_user_req_rx[10][9]} {dbg_cnt_user_req_rx[10][10]} {dbg_cnt_user_req_rx[10][11]} {dbg_cnt_user_req_rx[10][12]} {dbg_cnt_user_req_rx[10][13]} {dbg_cnt_user_req_rx[10][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe66]
set_property port_width 15 [get_debug_ports u_ila_0/probe66]
connect_debug_port u_ila_0/probe66 [get_nets [list {dbg_cnt_user_req_rx[17][0]} {dbg_cnt_user_req_rx[17][1]} {dbg_cnt_user_req_rx[17][2]} {dbg_cnt_user_req_rx[17][3]} {dbg_cnt_user_req_rx[17][4]} {dbg_cnt_user_req_rx[17][5]} {dbg_cnt_user_req_rx[17][6]} {dbg_cnt_user_req_rx[17][7]} {dbg_cnt_user_req_rx[17][8]} {dbg_cnt_user_req_rx[17][9]} {dbg_cnt_user_req_rx[17][10]} {dbg_cnt_user_req_rx[17][11]} {dbg_cnt_user_req_rx[17][12]} {dbg_cnt_user_req_rx[17][13]} {dbg_cnt_user_req_rx[17][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe67]
set_property port_width 15 [get_debug_ports u_ila_0/probe67]
connect_debug_port u_ila_0/probe67 [get_nets [list {dbg_cnt_user_reply_tx[17][0]} {dbg_cnt_user_reply_tx[17][1]} {dbg_cnt_user_reply_tx[17][2]} {dbg_cnt_user_reply_tx[17][3]} {dbg_cnt_user_reply_tx[17][4]} {dbg_cnt_user_reply_tx[17][5]} {dbg_cnt_user_reply_tx[17][6]} {dbg_cnt_user_reply_tx[17][7]} {dbg_cnt_user_reply_tx[17][8]} {dbg_cnt_user_reply_tx[17][9]} {dbg_cnt_user_reply_tx[17][10]} {dbg_cnt_user_reply_tx[17][11]} {dbg_cnt_user_reply_tx[17][12]} {dbg_cnt_user_reply_tx[17][13]} {dbg_cnt_user_reply_tx[17][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe68]
set_property port_width 15 [get_debug_ports u_ila_0/probe68]
connect_debug_port u_ila_0/probe68 [get_nets [list {dbg_cnt_user_req_rx[24][0]} {dbg_cnt_user_req_rx[24][1]} {dbg_cnt_user_req_rx[24][2]} {dbg_cnt_user_req_rx[24][3]} {dbg_cnt_user_req_rx[24][4]} {dbg_cnt_user_req_rx[24][5]} {dbg_cnt_user_req_rx[24][6]} {dbg_cnt_user_req_rx[24][7]} {dbg_cnt_user_req_rx[24][8]} {dbg_cnt_user_req_rx[24][9]} {dbg_cnt_user_req_rx[24][10]} {dbg_cnt_user_req_rx[24][11]} {dbg_cnt_user_req_rx[24][12]} {dbg_cnt_user_req_rx[24][13]} {dbg_cnt_user_req_rx[24][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe69]
set_property port_width 15 [get_debug_ports u_ila_0/probe69]
connect_debug_port u_ila_0/probe69 [get_nets [list {dbg_cnt_user_req_rx[25][0]} {dbg_cnt_user_req_rx[25][1]} {dbg_cnt_user_req_rx[25][2]} {dbg_cnt_user_req_rx[25][3]} {dbg_cnt_user_req_rx[25][4]} {dbg_cnt_user_req_rx[25][5]} {dbg_cnt_user_req_rx[25][6]} {dbg_cnt_user_req_rx[25][7]} {dbg_cnt_user_req_rx[25][8]} {dbg_cnt_user_req_rx[25][9]} {dbg_cnt_user_req_rx[25][10]} {dbg_cnt_user_req_rx[25][11]} {dbg_cnt_user_req_rx[25][12]} {dbg_cnt_user_req_rx[25][13]} {dbg_cnt_user_req_rx[25][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe70]
set_property port_width 15 [get_debug_ports u_ila_0/probe70]
connect_debug_port u_ila_0/probe70 [get_nets [list {dbg_cnt_user_req_rx[26][0]} {dbg_cnt_user_req_rx[26][1]} {dbg_cnt_user_req_rx[26][2]} {dbg_cnt_user_req_rx[26][3]} {dbg_cnt_user_req_rx[26][4]} {dbg_cnt_user_req_rx[26][5]} {dbg_cnt_user_req_rx[26][6]} {dbg_cnt_user_req_rx[26][7]} {dbg_cnt_user_req_rx[26][8]} {dbg_cnt_user_req_rx[26][9]} {dbg_cnt_user_req_rx[26][10]} {dbg_cnt_user_req_rx[26][11]} {dbg_cnt_user_req_rx[26][12]} {dbg_cnt_user_req_rx[26][13]} {dbg_cnt_user_req_rx[26][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe71]
set_property port_width 15 [get_debug_ports u_ila_0/probe71]
connect_debug_port u_ila_0/probe71 [get_nets [list {dbg_cnt_user_reply_tx[19][0]} {dbg_cnt_user_reply_tx[19][1]} {dbg_cnt_user_reply_tx[19][2]} {dbg_cnt_user_reply_tx[19][3]} {dbg_cnt_user_reply_tx[19][4]} {dbg_cnt_user_reply_tx[19][5]} {dbg_cnt_user_reply_tx[19][6]} {dbg_cnt_user_reply_tx[19][7]} {dbg_cnt_user_reply_tx[19][8]} {dbg_cnt_user_reply_tx[19][9]} {dbg_cnt_user_reply_tx[19][10]} {dbg_cnt_user_reply_tx[19][11]} {dbg_cnt_user_reply_tx[19][12]} {dbg_cnt_user_reply_tx[19][13]} {dbg_cnt_user_reply_tx[19][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe72]
set_property port_width 15 [get_debug_ports u_ila_0/probe72]
connect_debug_port u_ila_0/probe72 [get_nets [list {dbg_cnt_user_reply_tx[14][0]} {dbg_cnt_user_reply_tx[14][1]} {dbg_cnt_user_reply_tx[14][2]} {dbg_cnt_user_reply_tx[14][3]} {dbg_cnt_user_reply_tx[14][4]} {dbg_cnt_user_reply_tx[14][5]} {dbg_cnt_user_reply_tx[14][6]} {dbg_cnt_user_reply_tx[14][7]} {dbg_cnt_user_reply_tx[14][8]} {dbg_cnt_user_reply_tx[14][9]} {dbg_cnt_user_reply_tx[14][10]} {dbg_cnt_user_reply_tx[14][11]} {dbg_cnt_user_reply_tx[14][12]} {dbg_cnt_user_reply_tx[14][13]} {dbg_cnt_user_reply_tx[14][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe73]
set_property port_width 15 [get_debug_ports u_ila_0/probe73]
connect_debug_port u_ila_0/probe73 [get_nets [list {dbg_cnt_user_reply_tx[22][0]} {dbg_cnt_user_reply_tx[22][1]} {dbg_cnt_user_reply_tx[22][2]} {dbg_cnt_user_reply_tx[22][3]} {dbg_cnt_user_reply_tx[22][4]} {dbg_cnt_user_reply_tx[22][5]} {dbg_cnt_user_reply_tx[22][6]} {dbg_cnt_user_reply_tx[22][7]} {dbg_cnt_user_reply_tx[22][8]} {dbg_cnt_user_reply_tx[22][9]} {dbg_cnt_user_reply_tx[22][10]} {dbg_cnt_user_reply_tx[22][11]} {dbg_cnt_user_reply_tx[22][12]} {dbg_cnt_user_reply_tx[22][13]} {dbg_cnt_user_reply_tx[22][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe74]
set_property port_width 15 [get_debug_ports u_ila_0/probe74]
connect_debug_port u_ila_0/probe74 [get_nets [list {dbg_cnt_user_req_rx[15][0]} {dbg_cnt_user_req_rx[15][1]} {dbg_cnt_user_req_rx[15][2]} {dbg_cnt_user_req_rx[15][3]} {dbg_cnt_user_req_rx[15][4]} {dbg_cnt_user_req_rx[15][5]} {dbg_cnt_user_req_rx[15][6]} {dbg_cnt_user_req_rx[15][7]} {dbg_cnt_user_req_rx[15][8]} {dbg_cnt_user_req_rx[15][9]} {dbg_cnt_user_req_rx[15][10]} {dbg_cnt_user_req_rx[15][11]} {dbg_cnt_user_req_rx[15][12]} {dbg_cnt_user_req_rx[15][13]} {dbg_cnt_user_req_rx[15][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe75]
set_property port_width 15 [get_debug_ports u_ila_0/probe75]
connect_debug_port u_ila_0/probe75 [get_nets [list {dbg_cnt_user_req_rx[27][0]} {dbg_cnt_user_req_rx[27][1]} {dbg_cnt_user_req_rx[27][2]} {dbg_cnt_user_req_rx[27][3]} {dbg_cnt_user_req_rx[27][4]} {dbg_cnt_user_req_rx[27][5]} {dbg_cnt_user_req_rx[27][6]} {dbg_cnt_user_req_rx[27][7]} {dbg_cnt_user_req_rx[27][8]} {dbg_cnt_user_req_rx[27][9]} {dbg_cnt_user_req_rx[27][10]} {dbg_cnt_user_req_rx[27][11]} {dbg_cnt_user_req_rx[27][12]} {dbg_cnt_user_req_rx[27][13]} {dbg_cnt_user_req_rx[27][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe76]
set_property port_width 15 [get_debug_ports u_ila_0/probe76]
connect_debug_port u_ila_0/probe76 [get_nets [list {dbg_cnt_user_req_rx[28][0]} {dbg_cnt_user_req_rx[28][1]} {dbg_cnt_user_req_rx[28][2]} {dbg_cnt_user_req_rx[28][3]} {dbg_cnt_user_req_rx[28][4]} {dbg_cnt_user_req_rx[28][5]} {dbg_cnt_user_req_rx[28][6]} {dbg_cnt_user_req_rx[28][7]} {dbg_cnt_user_req_rx[28][8]} {dbg_cnt_user_req_rx[28][9]} {dbg_cnt_user_req_rx[28][10]} {dbg_cnt_user_req_rx[28][11]} {dbg_cnt_user_req_rx[28][12]} {dbg_cnt_user_req_rx[28][13]} {dbg_cnt_user_req_rx[28][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe77]
set_property port_width 15 [get_debug_ports u_ila_0/probe77]
connect_debug_port u_ila_0/probe77 [get_nets [list {dbg_cnt_user_req_rx[29][0]} {dbg_cnt_user_req_rx[29][1]} {dbg_cnt_user_req_rx[29][2]} {dbg_cnt_user_req_rx[29][3]} {dbg_cnt_user_req_rx[29][4]} {dbg_cnt_user_req_rx[29][5]} {dbg_cnt_user_req_rx[29][6]} {dbg_cnt_user_req_rx[29][7]} {dbg_cnt_user_req_rx[29][8]} {dbg_cnt_user_req_rx[29][9]} {dbg_cnt_user_req_rx[29][10]} {dbg_cnt_user_req_rx[29][11]} {dbg_cnt_user_req_rx[29][12]} {dbg_cnt_user_req_rx[29][13]} {dbg_cnt_user_req_rx[29][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe78]
set_property port_width 15 [get_debug_ports u_ila_0/probe78]
connect_debug_port u_ila_0/probe78 [get_nets [list {dbg_cnt_hb_req_rx[8][0]} {dbg_cnt_hb_req_rx[8][1]} {dbg_cnt_hb_req_rx[8][2]} {dbg_cnt_hb_req_rx[8][3]} {dbg_cnt_hb_req_rx[8][4]} {dbg_cnt_hb_req_rx[8][5]} {dbg_cnt_hb_req_rx[8][6]} {dbg_cnt_hb_req_rx[8][7]} {dbg_cnt_hb_req_rx[8][8]} {dbg_cnt_hb_req_rx[8][9]} {dbg_cnt_hb_req_rx[8][10]} {dbg_cnt_hb_req_rx[8][11]} {dbg_cnt_hb_req_rx[8][12]} {dbg_cnt_hb_req_rx[8][13]} {dbg_cnt_hb_req_rx[8][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe79]
set_property port_width 15 [get_debug_ports u_ila_0/probe79]
connect_debug_port u_ila_0/probe79 [get_nets [list {dbg_cnt_user_req_rx[2][0]} {dbg_cnt_user_req_rx[2][1]} {dbg_cnt_user_req_rx[2][2]} {dbg_cnt_user_req_rx[2][3]} {dbg_cnt_user_req_rx[2][4]} {dbg_cnt_user_req_rx[2][5]} {dbg_cnt_user_req_rx[2][6]} {dbg_cnt_user_req_rx[2][7]} {dbg_cnt_user_req_rx[2][8]} {dbg_cnt_user_req_rx[2][9]} {dbg_cnt_user_req_rx[2][10]} {dbg_cnt_user_req_rx[2][11]} {dbg_cnt_user_req_rx[2][12]} {dbg_cnt_user_req_rx[2][13]} {dbg_cnt_user_req_rx[2][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe80]
set_property port_width 15 [get_debug_ports u_ila_0/probe80]
connect_debug_port u_ila_0/probe80 [get_nets [list {dbg_cnt_user_reply_tx[26][0]} {dbg_cnt_user_reply_tx[26][1]} {dbg_cnt_user_reply_tx[26][2]} {dbg_cnt_user_reply_tx[26][3]} {dbg_cnt_user_reply_tx[26][4]} {dbg_cnt_user_reply_tx[26][5]} {dbg_cnt_user_reply_tx[26][6]} {dbg_cnt_user_reply_tx[26][7]} {dbg_cnt_user_reply_tx[26][8]} {dbg_cnt_user_reply_tx[26][9]} {dbg_cnt_user_reply_tx[26][10]} {dbg_cnt_user_reply_tx[26][11]} {dbg_cnt_user_reply_tx[26][12]} {dbg_cnt_user_reply_tx[26][13]} {dbg_cnt_user_reply_tx[26][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe81]
set_property port_width 15 [get_debug_ports u_ila_0/probe81]
connect_debug_port u_ila_0/probe81 [get_nets [list {dbg_cnt_user_reply_tx[28][0]} {dbg_cnt_user_reply_tx[28][1]} {dbg_cnt_user_reply_tx[28][2]} {dbg_cnt_user_reply_tx[28][3]} {dbg_cnt_user_reply_tx[28][4]} {dbg_cnt_user_reply_tx[28][5]} {dbg_cnt_user_reply_tx[28][6]} {dbg_cnt_user_reply_tx[28][7]} {dbg_cnt_user_reply_tx[28][8]} {dbg_cnt_user_reply_tx[28][9]} {dbg_cnt_user_reply_tx[28][10]} {dbg_cnt_user_reply_tx[28][11]} {dbg_cnt_user_reply_tx[28][12]} {dbg_cnt_user_reply_tx[28][13]} {dbg_cnt_user_reply_tx[28][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe82]
set_property port_width 15 [get_debug_ports u_ila_0/probe82]
connect_debug_port u_ila_0/probe82 [get_nets [list {dbg_cnt_user_req_rx[13][0]} {dbg_cnt_user_req_rx[13][1]} {dbg_cnt_user_req_rx[13][2]} {dbg_cnt_user_req_rx[13][3]} {dbg_cnt_user_req_rx[13][4]} {dbg_cnt_user_req_rx[13][5]} {dbg_cnt_user_req_rx[13][6]} {dbg_cnt_user_req_rx[13][7]} {dbg_cnt_user_req_rx[13][8]} {dbg_cnt_user_req_rx[13][9]} {dbg_cnt_user_req_rx[13][10]} {dbg_cnt_user_req_rx[13][11]} {dbg_cnt_user_req_rx[13][12]} {dbg_cnt_user_req_rx[13][13]} {dbg_cnt_user_req_rx[13][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe83]
set_property port_width 15 [get_debug_ports u_ila_0/probe83]
connect_debug_port u_ila_0/probe83 [get_nets [list {dbg_cnt_user_req_rx[30][0]} {dbg_cnt_user_req_rx[30][1]} {dbg_cnt_user_req_rx[30][2]} {dbg_cnt_user_req_rx[30][3]} {dbg_cnt_user_req_rx[30][4]} {dbg_cnt_user_req_rx[30][5]} {dbg_cnt_user_req_rx[30][6]} {dbg_cnt_user_req_rx[30][7]} {dbg_cnt_user_req_rx[30][8]} {dbg_cnt_user_req_rx[30][9]} {dbg_cnt_user_req_rx[30][10]} {dbg_cnt_user_req_rx[30][11]} {dbg_cnt_user_req_rx[30][12]} {dbg_cnt_user_req_rx[30][13]} {dbg_cnt_user_req_rx[30][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe84]
set_property port_width 15 [get_debug_ports u_ila_0/probe84]
connect_debug_port u_ila_0/probe84 [get_nets [list {dbg_cnt_user_reply_tx[8][0]} {dbg_cnt_user_reply_tx[8][1]} {dbg_cnt_user_reply_tx[8][2]} {dbg_cnt_user_reply_tx[8][3]} {dbg_cnt_user_reply_tx[8][4]} {dbg_cnt_user_reply_tx[8][5]} {dbg_cnt_user_reply_tx[8][6]} {dbg_cnt_user_reply_tx[8][7]} {dbg_cnt_user_reply_tx[8][8]} {dbg_cnt_user_reply_tx[8][9]} {dbg_cnt_user_reply_tx[8][10]} {dbg_cnt_user_reply_tx[8][11]} {dbg_cnt_user_reply_tx[8][12]} {dbg_cnt_user_reply_tx[8][13]} {dbg_cnt_user_reply_tx[8][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe85]
set_property port_width 15 [get_debug_ports u_ila_0/probe85]
connect_debug_port u_ila_0/probe85 [get_nets [list {dbg_cnt_user_req_rx[31][0]} {dbg_cnt_user_req_rx[31][1]} {dbg_cnt_user_req_rx[31][2]} {dbg_cnt_user_req_rx[31][3]} {dbg_cnt_user_req_rx[31][4]} {dbg_cnt_user_req_rx[31][5]} {dbg_cnt_user_req_rx[31][6]} {dbg_cnt_user_req_rx[31][7]} {dbg_cnt_user_req_rx[31][8]} {dbg_cnt_user_req_rx[31][9]} {dbg_cnt_user_req_rx[31][10]} {dbg_cnt_user_req_rx[31][11]} {dbg_cnt_user_req_rx[31][12]} {dbg_cnt_user_req_rx[31][13]} {dbg_cnt_user_req_rx[31][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe86]
set_property port_width 15 [get_debug_ports u_ila_0/probe86]
connect_debug_port u_ila_0/probe86 [get_nets [list {dbg_cnt_user_req_rx[3][0]} {dbg_cnt_user_req_rx[3][1]} {dbg_cnt_user_req_rx[3][2]} {dbg_cnt_user_req_rx[3][3]} {dbg_cnt_user_req_rx[3][4]} {dbg_cnt_user_req_rx[3][5]} {dbg_cnt_user_req_rx[3][6]} {dbg_cnt_user_req_rx[3][7]} {dbg_cnt_user_req_rx[3][8]} {dbg_cnt_user_req_rx[3][9]} {dbg_cnt_user_req_rx[3][10]} {dbg_cnt_user_req_rx[3][11]} {dbg_cnt_user_req_rx[3][12]} {dbg_cnt_user_req_rx[3][13]} {dbg_cnt_user_req_rx[3][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe87]
set_property port_width 15 [get_debug_ports u_ila_0/probe87]
connect_debug_port u_ila_0/probe87 [get_nets [list {dbg_cnt_user_req_rx[4][0]} {dbg_cnt_user_req_rx[4][1]} {dbg_cnt_user_req_rx[4][2]} {dbg_cnt_user_req_rx[4][3]} {dbg_cnt_user_req_rx[4][4]} {dbg_cnt_user_req_rx[4][5]} {dbg_cnt_user_req_rx[4][6]} {dbg_cnt_user_req_rx[4][7]} {dbg_cnt_user_req_rx[4][8]} {dbg_cnt_user_req_rx[4][9]} {dbg_cnt_user_req_rx[4][10]} {dbg_cnt_user_req_rx[4][11]} {dbg_cnt_user_req_rx[4][12]} {dbg_cnt_user_req_rx[4][13]} {dbg_cnt_user_req_rx[4][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe88]
set_property port_width 15 [get_debug_ports u_ila_0/probe88]
connect_debug_port u_ila_0/probe88 [get_nets [list {dbg_cnt_user_reply_tx[0][0]} {dbg_cnt_user_reply_tx[0][1]} {dbg_cnt_user_reply_tx[0][2]} {dbg_cnt_user_reply_tx[0][3]} {dbg_cnt_user_reply_tx[0][4]} {dbg_cnt_user_reply_tx[0][5]} {dbg_cnt_user_reply_tx[0][6]} {dbg_cnt_user_reply_tx[0][7]} {dbg_cnt_user_reply_tx[0][8]} {dbg_cnt_user_reply_tx[0][9]} {dbg_cnt_user_reply_tx[0][10]} {dbg_cnt_user_reply_tx[0][11]} {dbg_cnt_user_reply_tx[0][12]} {dbg_cnt_user_reply_tx[0][13]} {dbg_cnt_user_reply_tx[0][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe89]
set_property port_width 15 [get_debug_ports u_ila_0/probe89]
connect_debug_port u_ila_0/probe89 [get_nets [list {dbg_cnt_user_reply_tx[25][0]} {dbg_cnt_user_reply_tx[25][1]} {dbg_cnt_user_reply_tx[25][2]} {dbg_cnt_user_reply_tx[25][3]} {dbg_cnt_user_reply_tx[25][4]} {dbg_cnt_user_reply_tx[25][5]} {dbg_cnt_user_reply_tx[25][6]} {dbg_cnt_user_reply_tx[25][7]} {dbg_cnt_user_reply_tx[25][8]} {dbg_cnt_user_reply_tx[25][9]} {dbg_cnt_user_reply_tx[25][10]} {dbg_cnt_user_reply_tx[25][11]} {dbg_cnt_user_reply_tx[25][12]} {dbg_cnt_user_reply_tx[25][13]} {dbg_cnt_user_reply_tx[25][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe90]
set_property port_width 15 [get_debug_ports u_ila_0/probe90]
connect_debug_port u_ila_0/probe90 [get_nets [list {dbg_cnt_user_reply_tx[1][0]} {dbg_cnt_user_reply_tx[1][1]} {dbg_cnt_user_reply_tx[1][2]} {dbg_cnt_user_reply_tx[1][3]} {dbg_cnt_user_reply_tx[1][4]} {dbg_cnt_user_reply_tx[1][5]} {dbg_cnt_user_reply_tx[1][6]} {dbg_cnt_user_reply_tx[1][7]} {dbg_cnt_user_reply_tx[1][8]} {dbg_cnt_user_reply_tx[1][9]} {dbg_cnt_user_reply_tx[1][10]} {dbg_cnt_user_reply_tx[1][11]} {dbg_cnt_user_reply_tx[1][12]} {dbg_cnt_user_reply_tx[1][13]} {dbg_cnt_user_reply_tx[1][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe91]
set_property port_width 15 [get_debug_ports u_ila_0/probe91]
connect_debug_port u_ila_0/probe91 [get_nets [list {dbg_cnt_user_reply_tx[2][0]} {dbg_cnt_user_reply_tx[2][1]} {dbg_cnt_user_reply_tx[2][2]} {dbg_cnt_user_reply_tx[2][3]} {dbg_cnt_user_reply_tx[2][4]} {dbg_cnt_user_reply_tx[2][5]} {dbg_cnt_user_reply_tx[2][6]} {dbg_cnt_user_reply_tx[2][7]} {dbg_cnt_user_reply_tx[2][8]} {dbg_cnt_user_reply_tx[2][9]} {dbg_cnt_user_reply_tx[2][10]} {dbg_cnt_user_reply_tx[2][11]} {dbg_cnt_user_reply_tx[2][12]} {dbg_cnt_user_reply_tx[2][13]} {dbg_cnt_user_reply_tx[2][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe92]
set_property port_width 15 [get_debug_ports u_ila_0/probe92]
connect_debug_port u_ila_0/probe92 [get_nets [list {dbg_cnt_user_req_rx[0][0]} {dbg_cnt_user_req_rx[0][1]} {dbg_cnt_user_req_rx[0][2]} {dbg_cnt_user_req_rx[0][3]} {dbg_cnt_user_req_rx[0][4]} {dbg_cnt_user_req_rx[0][5]} {dbg_cnt_user_req_rx[0][6]} {dbg_cnt_user_req_rx[0][7]} {dbg_cnt_user_req_rx[0][8]} {dbg_cnt_user_req_rx[0][9]} {dbg_cnt_user_req_rx[0][10]} {dbg_cnt_user_req_rx[0][11]} {dbg_cnt_user_req_rx[0][12]} {dbg_cnt_user_req_rx[0][13]} {dbg_cnt_user_req_rx[0][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe93]
set_property port_width 15 [get_debug_ports u_ila_0/probe93]
connect_debug_port u_ila_0/probe93 [get_nets [list {dbg_cnt_hb_req_rx[6][0]} {dbg_cnt_hb_req_rx[6][1]} {dbg_cnt_hb_req_rx[6][2]} {dbg_cnt_hb_req_rx[6][3]} {dbg_cnt_hb_req_rx[6][4]} {dbg_cnt_hb_req_rx[6][5]} {dbg_cnt_hb_req_rx[6][6]} {dbg_cnt_hb_req_rx[6][7]} {dbg_cnt_hb_req_rx[6][8]} {dbg_cnt_hb_req_rx[6][9]} {dbg_cnt_hb_req_rx[6][10]} {dbg_cnt_hb_req_rx[6][11]} {dbg_cnt_hb_req_rx[6][12]} {dbg_cnt_hb_req_rx[6][13]} {dbg_cnt_hb_req_rx[6][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe94]
set_property port_width 15 [get_debug_ports u_ila_0/probe94]
connect_debug_port u_ila_0/probe94 [get_nets [list {dbg_cnt_user_req_rx[16][0]} {dbg_cnt_user_req_rx[16][1]} {dbg_cnt_user_req_rx[16][2]} {dbg_cnt_user_req_rx[16][3]} {dbg_cnt_user_req_rx[16][4]} {dbg_cnt_user_req_rx[16][5]} {dbg_cnt_user_req_rx[16][6]} {dbg_cnt_user_req_rx[16][7]} {dbg_cnt_user_req_rx[16][8]} {dbg_cnt_user_req_rx[16][9]} {dbg_cnt_user_req_rx[16][10]} {dbg_cnt_user_req_rx[16][11]} {dbg_cnt_user_req_rx[16][12]} {dbg_cnt_user_req_rx[16][13]} {dbg_cnt_user_req_rx[16][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe95]
set_property port_width 15 [get_debug_ports u_ila_0/probe95]
connect_debug_port u_ila_0/probe95 [get_nets [list {dbg_cnt_user_reply_tx[7][0]} {dbg_cnt_user_reply_tx[7][1]} {dbg_cnt_user_reply_tx[7][2]} {dbg_cnt_user_reply_tx[7][3]} {dbg_cnt_user_reply_tx[7][4]} {dbg_cnt_user_reply_tx[7][5]} {dbg_cnt_user_reply_tx[7][6]} {dbg_cnt_user_reply_tx[7][7]} {dbg_cnt_user_reply_tx[7][8]} {dbg_cnt_user_reply_tx[7][9]} {dbg_cnt_user_reply_tx[7][10]} {dbg_cnt_user_reply_tx[7][11]} {dbg_cnt_user_reply_tx[7][12]} {dbg_cnt_user_reply_tx[7][13]} {dbg_cnt_user_reply_tx[7][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe96]
set_property port_width 15 [get_debug_ports u_ila_0/probe96]
connect_debug_port u_ila_0/probe96 [get_nets [list {dbg_cnt_user_req_rx[7][0]} {dbg_cnt_user_req_rx[7][1]} {dbg_cnt_user_req_rx[7][2]} {dbg_cnt_user_req_rx[7][3]} {dbg_cnt_user_req_rx[7][4]} {dbg_cnt_user_req_rx[7][5]} {dbg_cnt_user_req_rx[7][6]} {dbg_cnt_user_req_rx[7][7]} {dbg_cnt_user_req_rx[7][8]} {dbg_cnt_user_req_rx[7][9]} {dbg_cnt_user_req_rx[7][10]} {dbg_cnt_user_req_rx[7][11]} {dbg_cnt_user_req_rx[7][12]} {dbg_cnt_user_req_rx[7][13]} {dbg_cnt_user_req_rx[7][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe97]
set_property port_width 15 [get_debug_ports u_ila_0/probe97]
connect_debug_port u_ila_0/probe97 [get_nets [list {dbg_cnt_user_req_rx[6][0]} {dbg_cnt_user_req_rx[6][1]} {dbg_cnt_user_req_rx[6][2]} {dbg_cnt_user_req_rx[6][3]} {dbg_cnt_user_req_rx[6][4]} {dbg_cnt_user_req_rx[6][5]} {dbg_cnt_user_req_rx[6][6]} {dbg_cnt_user_req_rx[6][7]} {dbg_cnt_user_req_rx[6][8]} {dbg_cnt_user_req_rx[6][9]} {dbg_cnt_user_req_rx[6][10]} {dbg_cnt_user_req_rx[6][11]} {dbg_cnt_user_req_rx[6][12]} {dbg_cnt_user_req_rx[6][13]} {dbg_cnt_user_req_rx[6][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe98]
set_property port_width 64 [get_debug_ports u_ila_0/probe98]
connect_debug_port u_ila_0/probe98 [get_nets [list {rx_backend_keep[0]} {rx_backend_keep[1]} {rx_backend_keep[2]} {rx_backend_keep[3]} {rx_backend_keep[4]} {rx_backend_keep[5]} {rx_backend_keep[6]} {rx_backend_keep[7]} {rx_backend_keep[8]} {rx_backend_keep[9]} {rx_backend_keep[10]} {rx_backend_keep[11]} {rx_backend_keep[12]} {rx_backend_keep[13]} {rx_backend_keep[14]} {rx_backend_keep[15]} {rx_backend_keep[16]} {rx_backend_keep[17]} {rx_backend_keep[18]} {rx_backend_keep[19]} {rx_backend_keep[20]} {rx_backend_keep[21]} {rx_backend_keep[22]} {rx_backend_keep[23]} {rx_backend_keep[24]} {rx_backend_keep[25]} {rx_backend_keep[26]} {rx_backend_keep[27]} {rx_backend_keep[28]} {rx_backend_keep[29]} {rx_backend_keep[30]} {rx_backend_keep[31]} {rx_backend_keep[32]} {rx_backend_keep[33]} {rx_backend_keep[34]} {rx_backend_keep[35]} {rx_backend_keep[36]} {rx_backend_keep[37]} {rx_backend_keep[38]} {rx_backend_keep[39]} {rx_backend_keep[40]} {rx_backend_keep[41]} {rx_backend_keep[42]} {rx_backend_keep[43]} {rx_backend_keep[44]} {rx_backend_keep[45]} {rx_backend_keep[46]} {rx_backend_keep[47]} {rx_backend_keep[48]} {rx_backend_keep[49]} {rx_backend_keep[50]} {rx_backend_keep[51]} {rx_backend_keep[52]} {rx_backend_keep[53]} {rx_backend_keep[54]} {rx_backend_keep[55]} {rx_backend_keep[56]} {rx_backend_keep[57]} {rx_backend_keep[58]} {rx_backend_keep[59]} {rx_backend_keep[60]} {rx_backend_keep[61]} {rx_backend_keep[62]} {rx_backend_keep[63]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe99]
set_property port_width 4 [get_debug_ports u_ila_0/probe99]
connect_debug_port u_ila_0/probe99 [get_nets [list {first_server_cycle[0]} {first_server_cycle[1]} {first_server_cycle[2]} {first_server_cycle[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe100]
set_property port_width 6 [get_debug_ports u_ila_0/probe100]
connect_debug_port u_ila_0/probe100 [get_nets [list {server_en_dbg[0]} {server_en_dbg[1]} {server_en_dbg[2]} {server_en_dbg[3]} {server_en_dbg[4]} {server_en_dbg[5]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe101]
set_property port_width 20 [get_debug_ports u_ila_0/probe101]
connect_debug_port u_ila_0/probe101 [get_nets [list {filtered_pkt_cnt[0]} {filtered_pkt_cnt[1]} {filtered_pkt_cnt[2]} {filtered_pkt_cnt[3]} {filtered_pkt_cnt[4]} {filtered_pkt_cnt[5]} {filtered_pkt_cnt[6]} {filtered_pkt_cnt[7]} {filtered_pkt_cnt[8]} {filtered_pkt_cnt[9]} {filtered_pkt_cnt[10]} {filtered_pkt_cnt[11]} {filtered_pkt_cnt[12]} {filtered_pkt_cnt[13]} {filtered_pkt_cnt[14]} {filtered_pkt_cnt[15]} {filtered_pkt_cnt[16]} {filtered_pkt_cnt[17]} {filtered_pkt_cnt[18]} {filtered_pkt_cnt[19]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe102]
set_property port_width 20 [get_debug_ports u_ila_0/probe102]
connect_debug_port u_ila_0/probe102 [get_nets [list {gen_pkt_cnt[0]} {gen_pkt_cnt[1]} {gen_pkt_cnt[2]} {gen_pkt_cnt[3]} {gen_pkt_cnt[4]} {gen_pkt_cnt[5]} {gen_pkt_cnt[6]} {gen_pkt_cnt[7]} {gen_pkt_cnt[8]} {gen_pkt_cnt[9]} {gen_pkt_cnt[10]} {gen_pkt_cnt[11]} {gen_pkt_cnt[12]} {gen_pkt_cnt[13]} {gen_pkt_cnt[14]} {gen_pkt_cnt[15]} {gen_pkt_cnt[16]} {gen_pkt_cnt[17]} {gen_pkt_cnt[18]} {gen_pkt_cnt[19]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe103]
set_property port_width 15 [get_debug_ports u_ila_0/probe103]
connect_debug_port u_ila_0/probe103 [get_nets [list {dbg_cnt_user_req_rx[5][0]} {dbg_cnt_user_req_rx[5][1]} {dbg_cnt_user_req_rx[5][2]} {dbg_cnt_user_req_rx[5][3]} {dbg_cnt_user_req_rx[5][4]} {dbg_cnt_user_req_rx[5][5]} {dbg_cnt_user_req_rx[5][6]} {dbg_cnt_user_req_rx[5][7]} {dbg_cnt_user_req_rx[5][8]} {dbg_cnt_user_req_rx[5][9]} {dbg_cnt_user_req_rx[5][10]} {dbg_cnt_user_req_rx[5][11]} {dbg_cnt_user_req_rx[5][12]} {dbg_cnt_user_req_rx[5][13]} {dbg_cnt_user_req_rx[5][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe104]
set_property port_width 64 [get_debug_ports u_ila_0/probe104]
connect_debug_port u_ila_0/probe104 [get_nets [list {gen_tkeep[0]} {gen_tkeep[1]} {gen_tkeep[2]} {gen_tkeep[3]} {gen_tkeep[4]} {gen_tkeep[5]} {gen_tkeep[6]} {gen_tkeep[7]} {gen_tkeep[8]} {gen_tkeep[9]} {gen_tkeep[10]} {gen_tkeep[11]} {gen_tkeep[12]} {gen_tkeep[13]} {gen_tkeep[14]} {gen_tkeep[15]} {gen_tkeep[16]} {gen_tkeep[17]} {gen_tkeep[18]} {gen_tkeep[19]} {gen_tkeep[20]} {gen_tkeep[21]} {gen_tkeep[22]} {gen_tkeep[23]} {gen_tkeep[24]} {gen_tkeep[25]} {gen_tkeep[26]} {gen_tkeep[27]} {gen_tkeep[28]} {gen_tkeep[29]} {gen_tkeep[30]} {gen_tkeep[31]} {gen_tkeep[32]} {gen_tkeep[33]} {gen_tkeep[34]} {gen_tkeep[35]} {gen_tkeep[36]} {gen_tkeep[37]} {gen_tkeep[38]} {gen_tkeep[39]} {gen_tkeep[40]} {gen_tkeep[41]} {gen_tkeep[42]} {gen_tkeep[43]} {gen_tkeep[44]} {gen_tkeep[45]} {gen_tkeep[46]} {gen_tkeep[47]} {gen_tkeep[48]} {gen_tkeep[49]} {gen_tkeep[50]} {gen_tkeep[51]} {gen_tkeep[52]} {gen_tkeep[53]} {gen_tkeep[54]} {gen_tkeep[55]} {gen_tkeep[56]} {gen_tkeep[57]} {gen_tkeep[58]} {gen_tkeep[59]} {gen_tkeep[60]} {gen_tkeep[61]} {gen_tkeep[62]} {gen_tkeep[63]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe105]
set_property port_width 15 [get_debug_ports u_ila_0/probe105]
connect_debug_port u_ila_0/probe105 [get_nets [list {dbg_cnt_user_req_rx[9][0]} {dbg_cnt_user_req_rx[9][1]} {dbg_cnt_user_req_rx[9][2]} {dbg_cnt_user_req_rx[9][3]} {dbg_cnt_user_req_rx[9][4]} {dbg_cnt_user_req_rx[9][5]} {dbg_cnt_user_req_rx[9][6]} {dbg_cnt_user_req_rx[9][7]} {dbg_cnt_user_req_rx[9][8]} {dbg_cnt_user_req_rx[9][9]} {dbg_cnt_user_req_rx[9][10]} {dbg_cnt_user_req_rx[9][11]} {dbg_cnt_user_req_rx[9][12]} {dbg_cnt_user_req_rx[9][13]} {dbg_cnt_user_req_rx[9][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe106]
set_property port_width 20 [get_debug_ports u_ila_0/probe106]
connect_debug_port u_ila_0/probe106 [get_nets [list {lb_pkt_cnt[0]} {lb_pkt_cnt[1]} {lb_pkt_cnt[2]} {lb_pkt_cnt[3]} {lb_pkt_cnt[4]} {lb_pkt_cnt[5]} {lb_pkt_cnt[6]} {lb_pkt_cnt[7]} {lb_pkt_cnt[8]} {lb_pkt_cnt[9]} {lb_pkt_cnt[10]} {lb_pkt_cnt[11]} {lb_pkt_cnt[12]} {lb_pkt_cnt[13]} {lb_pkt_cnt[14]} {lb_pkt_cnt[15]} {lb_pkt_cnt[16]} {lb_pkt_cnt[17]} {lb_pkt_cnt[18]} {lb_pkt_cnt[19]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe107]
set_property port_width 15 [get_debug_ports u_ila_0/probe107]
connect_debug_port u_ila_0/probe107 [get_nets [list {dbg_cnt_user_req_rx[8][0]} {dbg_cnt_user_req_rx[8][1]} {dbg_cnt_user_req_rx[8][2]} {dbg_cnt_user_req_rx[8][3]} {dbg_cnt_user_req_rx[8][4]} {dbg_cnt_user_req_rx[8][5]} {dbg_cnt_user_req_rx[8][6]} {dbg_cnt_user_req_rx[8][7]} {dbg_cnt_user_req_rx[8][8]} {dbg_cnt_user_req_rx[8][9]} {dbg_cnt_user_req_rx[8][10]} {dbg_cnt_user_req_rx[8][11]} {dbg_cnt_user_req_rx[8][12]} {dbg_cnt_user_req_rx[8][13]} {dbg_cnt_user_req_rx[8][14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe108]
set_property port_width 64 [get_debug_ports u_ila_0/probe108]
connect_debug_port u_ila_0/probe108 [get_nets [list {tx_backend_keep[0]} {tx_backend_keep[1]} {tx_backend_keep[2]} {tx_backend_keep[3]} {tx_backend_keep[4]} {tx_backend_keep[5]} {tx_backend_keep[6]} {tx_backend_keep[7]} {tx_backend_keep[8]} {tx_backend_keep[9]} {tx_backend_keep[10]} {tx_backend_keep[11]} {tx_backend_keep[12]} {tx_backend_keep[13]} {tx_backend_keep[14]} {tx_backend_keep[15]} {tx_backend_keep[16]} {tx_backend_keep[17]} {tx_backend_keep[18]} {tx_backend_keep[19]} {tx_backend_keep[20]} {tx_backend_keep[21]} {tx_backend_keep[22]} {tx_backend_keep[23]} {tx_backend_keep[24]} {tx_backend_keep[25]} {tx_backend_keep[26]} {tx_backend_keep[27]} {tx_backend_keep[28]} {tx_backend_keep[29]} {tx_backend_keep[30]} {tx_backend_keep[31]} {tx_backend_keep[32]} {tx_backend_keep[33]} {tx_backend_keep[34]} {tx_backend_keep[35]} {tx_backend_keep[36]} {tx_backend_keep[37]} {tx_backend_keep[38]} {tx_backend_keep[39]} {tx_backend_keep[40]} {tx_backend_keep[41]} {tx_backend_keep[42]} {tx_backend_keep[43]} {tx_backend_keep[44]} {tx_backend_keep[45]} {tx_backend_keep[46]} {tx_backend_keep[47]} {tx_backend_keep[48]} {tx_backend_keep[49]} {tx_backend_keep[50]} {tx_backend_keep[51]} {tx_backend_keep[52]} {tx_backend_keep[53]} {tx_backend_keep[54]} {tx_backend_keep[55]} {tx_backend_keep[56]} {tx_backend_keep[57]} {tx_backend_keep[58]} {tx_backend_keep[59]} {tx_backend_keep[60]} {tx_backend_keep[61]} {tx_backend_keep[62]} {tx_backend_keep[63]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe109]
set_property port_width 4 [get_debug_ports u_ila_0/probe109]
connect_debug_port u_ila_0/probe109 [get_nets [list {first_gen_cycle[0]} {first_gen_cycle[1]} {first_gen_cycle[2]} {first_gen_cycle[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe110]
set_property port_width 1 [get_debug_ports u_ila_0/probe110]
connect_debug_port u_ila_0/probe110 [get_nets [list done_OBUF]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe111]
set_property port_width 1 [get_debug_ports u_ila_0/probe111]
connect_debug_port u_ila_0/probe111 [get_nets [list gen_tlast]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe112]
set_property port_width 1 [get_debug_ports u_ila_0/probe112]
connect_debug_port u_ila_0/probe112 [get_nets [list gen_tready]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe113]
set_property port_width 1 [get_debug_ports u_ila_0/probe113]
connect_debug_port u_ila_0/probe113 [get_nets [list gen_tvalid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe114]
set_property port_width 1 [get_debug_ports u_ila_0/probe114]
connect_debug_port u_ila_0/probe114 [get_nets [list rx_backend_last]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe115]
set_property port_width 1 [get_debug_ports u_ila_0/probe115]
connect_debug_port u_ila_0/probe115 [get_nets [list rx_backend_ready]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe116]
set_property port_width 1 [get_debug_ports u_ila_0/probe116]
connect_debug_port u_ila_0/probe116 [get_nets [list rx_backend_valid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe117]
set_property port_width 1 [get_debug_ports u_ila_0/probe117]
connect_debug_port u_ila_0/probe117 [get_nets [list start_IBUF]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe118]
set_property port_width 1 [get_debug_ports u_ila_0/probe118]
connect_debug_port u_ila_0/probe118 [get_nets [list tx_backend_last]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe119]
set_property port_width 1 [get_debug_ports u_ila_0/probe119]
connect_debug_port u_ila_0/probe119 [get_nets [list tx_backend_ready]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe120]
set_property port_width 1 [get_debug_ports u_ila_0/probe120]
connect_debug_port u_ila_0/probe120 [get_nets [list tx_backend_valid]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk_core_BUFG]
