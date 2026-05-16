// Khai báo xung nhịp clk chạy với tần số 27MHz (Chu kỳ ~37.037 ns)
create_clock -name clk -period 37.037 -waveform {0 18.518} [get_ports {clk}]