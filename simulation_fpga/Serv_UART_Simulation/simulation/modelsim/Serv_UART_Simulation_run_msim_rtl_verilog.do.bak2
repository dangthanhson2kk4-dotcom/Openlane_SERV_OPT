transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -vlog01compat -work work +incdir+C:/Users/admin/Desktop/Serv_UART_Simulation {C:/Users/admin/Desktop/Serv_UART_Simulation/simpleuart.v}
vlog -vlog01compat -work work +incdir+C:/Users/admin/Desktop/Serv_UART_Simulation {C:/Users/admin/Desktop/Serv_UART_Simulation/serv_top.v}
vlog -vlog01compat -work work +incdir+C:/Users/admin/Desktop/Serv_UART_Simulation {C:/Users/admin/Desktop/Serv_UART_Simulation/serv_state.v}
vlog -vlog01compat -work work +incdir+C:/Users/admin/Desktop/Serv_UART_Simulation {C:/Users/admin/Desktop/Serv_UART_Simulation/serv_rf_top.v}
vlog -vlog01compat -work work +incdir+C:/Users/admin/Desktop/Serv_UART_Simulation {C:/Users/admin/Desktop/Serv_UART_Simulation/serv_rf_ram_if.v}
vlog -vlog01compat -work work +incdir+C:/Users/admin/Desktop/Serv_UART_Simulation {C:/Users/admin/Desktop/Serv_UART_Simulation/serv_rf_ram.v}
vlog -vlog01compat -work work +incdir+C:/Users/admin/Desktop/Serv_UART_Simulation {C:/Users/admin/Desktop/Serv_UART_Simulation/serv_rf_if.v}
vlog -vlog01compat -work work +incdir+C:/Users/admin/Desktop/Serv_UART_Simulation {C:/Users/admin/Desktop/Serv_UART_Simulation/serv_mem_if.v}
vlog -vlog01compat -work work +incdir+C:/Users/admin/Desktop/Serv_UART_Simulation {C:/Users/admin/Desktop/Serv_UART_Simulation/serv_immdec.v}
vlog -vlog01compat -work work +incdir+C:/Users/admin/Desktop/Serv_UART_Simulation {C:/Users/admin/Desktop/Serv_UART_Simulation/serv_decode.v}
vlog -vlog01compat -work work +incdir+C:/Users/admin/Desktop/Serv_UART_Simulation {C:/Users/admin/Desktop/Serv_UART_Simulation/serv_ctrl.v}
vlog -vlog01compat -work work +incdir+C:/Users/admin/Desktop/Serv_UART_Simulation {C:/Users/admin/Desktop/Serv_UART_Simulation/serv_csr.v}
vlog -vlog01compat -work work +incdir+C:/Users/admin/Desktop/Serv_UART_Simulation {C:/Users/admin/Desktop/Serv_UART_Simulation/serv_bufreg2.v}
vlog -vlog01compat -work work +incdir+C:/Users/admin/Desktop/Serv_UART_Simulation {C:/Users/admin/Desktop/Serv_UART_Simulation/serv_bufreg.v}
vlog -vlog01compat -work work +incdir+C:/Users/admin/Desktop/Serv_UART_Simulation {C:/Users/admin/Desktop/Serv_UART_Simulation/serv_alu.v}
vlog -vlog01compat -work work +incdir+C:/Users/admin/Desktop/Serv_UART_Simulation {C:/Users/admin/Desktop/Serv_UART_Simulation/system_top.v}

vlog -vlog01compat -work work +incdir+C:/Users/admin/Desktop/Serv_UART_Simulation {C:/Users/admin/Desktop/Serv_UART_Simulation/tb_system_top.v}

vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cyclonev_ver -L cyclonev_hssi_ver -L cyclonev_pcie_hip_ver -L rtl_work -L work -voptargs="+acc"  tb_system_top

add wave *
view structure
view signals
run -all
