`timescale 1ns/1ps
`default_nettype none

// ============================================================================
// tb_system_top.v
// Testbench cho system_top.v: SERV RISC-V + UART + LED MMIO
// Muc tieu mo phong cac kich ban giong Hercules:
//   '1' -> Bat tat ca LED
//   '2' -> Tat tat ca LED
//   '3' -> LED chop nhay / bat xen ke
//
// Chay functional simulation tren ModelSim/Questa.
// Dat 4 file firmware_bank0.hex..firmware_bank3.hex trong thu muc simulation.
// ============================================================================

module tb_system_top;

    // Clock Tang Nano 9K: 27 MHz
    localparam integer CLK_HZ       = 27000000;
    localparam integer BAUD         = 115200;
    // simpleuart dung divider 234, moi bit xap xi 234 chu ky clock
    localparam integer CLKS_PER_BIT = 234;
    localparam real    CLK_PERIOD_NS = 1000000000.0 / CLK_HZ;

    reg clk;
    reg rst_n;
    reg uart_rx;
    wire uart_tx;
    wire [5:0] leds;

    // DUT
    system_top dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .uart_tx (uart_tx),
        .uart_rx (uart_rx),
        .leds    (leds)
    );

    // LED tren Tang Nano thuong active-low:
    // leds = 0 -> sang, leds = 1 -> tat
    wire [5:0] led_logic = ~leds;

    // Tao clock 27 MHz
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD_NS/2.0) clk = ~clk;
    end

    // Ghi log ra file de xem lai UART output
    integer uart_log;
    initial begin
        uart_log = $fopen("uart_output.log", "w");
        if (uart_log == 0) begin
            $display("ERROR: Khong mo duoc uart_output.log");
            $finish;
        end
    end

    // Dump waveform cho GTKWave/ModelSim neu can
    initial begin
        $dumpfile("tb_system_top.vcd");
        $dumpvars(0, tb_system_top);
    end

    // ------------------------------------------------------------------------
    // Task gui 1 byte UART vao chan uart_rx cua DUT, format 8N1
    // idle = 1, start = 0, 8 data bits LSB first, stop = 1
    // ------------------------------------------------------------------------
    task uart_send_byte;
        input [7:0] data;
        integer i;
        begin
            $display("[%0t ns] TB -> DUT UART RX: '%s' / 0x%02h", $time, data, data);

            // Start bit
            uart_rx = 1'b0;
            repeat (CLKS_PER_BIT) @(posedge clk);

            // Data bits, LSB first
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx = data[i];
                repeat (CLKS_PER_BIT) @(posedge clk);
            end

            // Stop bit
            uart_rx = 1'b1;
            repeat (CLKS_PER_BIT) @(posedge clk);

            // Idle giua 2 byte
            repeat (CLKS_PER_BIT) @(posedge clk);
        end
    endtask

    // ------------------------------------------------------------------------
    // Task doc 1 byte UART tu chan uart_tx cua DUT, format 8N1
    // Co timeout de tranh treo simulation.
    // ------------------------------------------------------------------------
    task uart_recv_byte;
        output [7:0] data;
        output       ok;
        integer i;
        integer timeout;
        begin
            data = 8'h00;
            ok = 1'b0;
            timeout = 0;

            // Cho start bit uart_tx keo xuong 0
            while (uart_tx !== 1'b0 && timeout < 2000000) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            if (timeout >= 2000000) begin
                ok = 1'b0;
            end else begin
                // Lay mau o giua bit start
                repeat (CLKS_PER_BIT/2) @(posedge clk);

                // Lay 8 data bits o giua tung bit
                for (i = 0; i < 8; i = i + 1) begin
                    repeat (CLKS_PER_BIT) @(posedge clk);
                    data[i] = uart_tx;
                end

                // Bo qua stop bit
                repeat (CLKS_PER_BIT) @(posedge clk);
                ok = 1'b1;
            end
        end
    endtask

    // ------------------------------------------------------------------------
    // Monitor UART TX: in ra console va ghi ra uart_output.log
    // ------------------------------------------------------------------------
    reg [7:0] rx_char;
    reg       rx_ok;
    initial begin
        // Cho reset xong moi monitor
        wait (rst_n == 1'b1);
        forever begin
            uart_recv_byte(rx_char, rx_ok);
            if (rx_ok) begin
                if (rx_char == 8'h0d) begin
                    $write("\\r");
                    $fwrite(uart_log, "\\r");
                end else if (rx_char == 8'h0a) begin
                    $write("\n");
                    $fwrite(uart_log, "\n");
                end else begin
                    $write("%c", rx_char);
                    $fwrite(uart_log, "%c", rx_char);
                end
            end else begin
                // Khong co byte moi trong timeout, lap lai de tiep tuc cho
                @(posedge clk);
            end
        end
    end

    // Monitor LED moi khi thay doi
    always @(led_logic) begin
        $display("[%0t ns] LED logic = %06b, chan leds active-low = %06b", $time, led_logic, leds);
    end

    // Watchdog bao ve: neu firmware khong phan hoi thi van tu dung mo phong
    initial begin
        repeat (15000000) @(posedge clk);
        $display("[%0t ns] ERROR: Watchdog timeout, dung simulation de tranh chay vo han", $time);
        $fclose(uart_log);
        $finish;
    end

    // ------------------------------------------------------------------------
    // Ham wait den khi LED logic dat gia tri mong muon
    // ------------------------------------------------------------------------
    task wait_led_value;
        input [5:0] expected;
        input integer max_cycles;
        integer cnt;
        begin
            cnt = 0;
            while (led_logic !== expected && cnt < max_cycles) begin
                @(posedge clk);
                cnt = cnt + 1;
            end

            if (led_logic === expected)
                $display("[%0t ns] PASS: LED logic = %06b", $time, expected);
            else
                $display("[%0t ns] WARNING: Qua timeout, LED logic = %06b, expected = %06b", $time, led_logic, expected);
        end
    endtask

    // ------------------------------------------------------------------------
    // Ham wait den khi LED vao trang thai xen ke
    // ------------------------------------------------------------------------
    task wait_led_alternating;
        input integer max_cycles;
        integer cnt;
        begin
            cnt = 0;
            while (!(led_logic === 6'b010101 || led_logic === 6'b101010) && cnt < max_cycles) begin
                @(posedge clk);
                cnt = cnt + 1;
            end

            if (led_logic === 6'b010101 || led_logic === 6'b101010)
                $display("[%0t ns] PASS: LED xen ke = %06b", $time, led_logic);
            else
                $display("[%0t ns] WARNING: Qua timeout TEST 3, LED logic = %06b, chua thay 010101/101010", $time, led_logic);
        end
    endtask

    // ------------------------------------------------------------------------
    // Kich ban chinh
    // ------------------------------------------------------------------------
    initial begin
        // Trang thai ban dau
        rst_n   = 1'b0;
        uart_rx = 1'b1; // UART idle

        $display("============================================================");
        $display("BAT DAU SIMULATION: system_top + firmware UART LED");
        $display("Clock = %0d Hz, Baud = %0d, CLKS_PER_BIT = %0d", CLK_HZ, BAUD, CLKS_PER_BIT);
        $display("============================================================");

        // Reset mot luc de CPU/UART on dinh
        repeat (50) @(posedge clk);
        rst_n = 1'b1;
        $display("[%0t ns] Release reset", $time);

        // Cho firmware khoi dong va in menu ra UART.
        // SERV la CPU bit-serial nen boot/menu co the mat nhieu chu ky.
        repeat (300000) @(posedge clk);

        // Kich ban 1: Hercules gui '1' -> Bat tat ca LED
        $display("\n==================== TEST 1: GUI '1' ====================");
        uart_send_byte("1");
        wait_led_value(6'b111111, 3000000);
        repeat (300000) @(posedge clk);

        // Kich ban 2: Hercules gui '2' -> Tat tat ca LED
        $display("\n==================== TEST 2: GUI '2' ====================");
        uart_send_byte("2");
        wait_led_value(6'b000000, 3000000);
        repeat (300000) @(posedge clk);

        // Kich ban 3: Hercules gui '3' -> LED xen ke / chop nhay
        $display("\n==================== TEST 3: GUI '3' ====================");
        uart_send_byte("3");

        // Cho firmware xu ly lenh '3'. Ket thuc test 3 khi thay pattern xen ke
        // hoac khi qua timeout, sau do dung mo phong ngay.
        wait_led_alternating(3000000);

        // Dung mo phong ngay sau test 3, khong chay vo han.
        $display("\n============================================================");
        $display("KET THUC SIMULATION SAU TEST 3");
        $display("Xem UART text trong file: uart_output.log");
        $display("Xem waveform: tb_system_top.vcd hoac add wave trong ModelSim");
        $display("============================================================");

        $fclose(uart_log);
        $finish;
    end

endmodule

`default_nettype wire
