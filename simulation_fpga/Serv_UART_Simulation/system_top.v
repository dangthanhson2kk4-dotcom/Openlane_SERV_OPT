`default_nettype none

// ============================================================================
// system_top.v
// Tang Nano 9K + SERV RISC-V + simple UART + LED MMIO
//
// Chuc nang project:
//   - FPGA gui menu/thong tin len laptop qua UART 115200 baud.
//   - Laptop gui ky tu '1' -> bat LED.
//   - Laptop gui ky tu '2' -> tat LED.
//   - Laptop gui ky tu '3' -> LED nhay theo firmware.
//
// Clock mac dinh Tang Nano 9K: 27 MHz
// UART baudrate: 115200, divider xap xi 27000000 / 115200 = 234.375
//
// Ban v4:
//   - Tach Instruction ROM va Data RAM thanh 2 kho rieng.
//   - Ly do: Gowin P&R tren Tang Nano 9K khong ho tro DPB WRITE_MODE0=2'b10
//     khi infer chung 1 RAM cho ca ibus va dbus.
//   - IMEM chi doc cho instruction fetch.
//   - DMEM doc/ghi cho load/store, duoc init cung firmware de data/string van doc duoc.
// ============================================================================

module system_top (
    input  wire       clk,       // 27 MHz
    input  wire       rst_n,     // reset active-low
    output wire       uart_tx,
    input  wire       uart_rx,
    output wire [5:0] leds       // LED tren Tang Nano thuong active-low
);

    // =========================================================================
    // 1. Reset
    // =========================================================================
    wire rst = !rst_n;

    // =========================================================================
    // 2. SERV CPU bus signals
    // =========================================================================
    wire [31:0] ibus_adr;
    reg  [31:0] ibus_rdt;
    wire        ibus_cyc;
    reg         ibus_ack;

    wire [31:0] dbus_adr;
    wire [31:0] dbus_dat;
    wire [3:0]  dbus_sel;
    wire        dbus_we;
    wire        dbus_cyc;
    wire [31:0] dbus_rdt;
    reg         dbus_ack;

    serv_rf_top #(
        .RESET_PC(32'h0000_0000),
        .W(1)
    ) cpu (
        .clk(clk),
        .i_rst(rst),
        .i_timer_irq(1'b0),

        .o_ibus_adr(ibus_adr),
        .o_ibus_cyc(ibus_cyc),
        .i_ibus_rdt(ibus_rdt),
        .i_ibus_ack(ibus_ack),

        .o_dbus_adr(dbus_adr),
        .o_dbus_dat(dbus_dat),
        .o_dbus_sel(dbus_sel),
        .o_dbus_we(dbus_we),
        .o_dbus_cyc(dbus_cyc),
        .i_dbus_rdt(dbus_rdt),
        .i_dbus_ack(dbus_ack),

        // External extension/MDU khong dung trong project nay
        .o_ext_rs1(),
        .o_ext_rs2(),
        .o_ext_funct3(),
        .i_ext_rd(32'b0),
        .i_ext_ready(1'b0),
        .o_mdu_valid()
    );

    // =========================================================================
    // 3. Memory map
    // =========================================================================
    // 0x0000_0000 - 0x0000_3FFF : RAM/ROM 16KB, chua firmware
    // 0x4000_0000                : UART DATA register
    // 0x5000_0000                : LED register, bit[5:0]
    // =========================================================================
    wire ram_sel  = (dbus_adr[31:28] == 4'h0);
    wire uart_sel = (dbus_adr[31:28] == 4'h4);
    wire led_sel  = (dbus_adr[31:28] == 4'h5);

    wire [11:0] ibus_word_addr = ibus_adr[13:2];
    wire [11:0] dbus_word_addr = dbus_adr[13:2];

    // =========================================================================
    // 4. Instruction ROM 16KB, chia 4 byte-bank
    // =========================================================================
    (* rom_style = "block" *) reg [7:0] imem0 [0:4095];
    (* rom_style = "block" *) reg [7:0] imem1 [0:4095];
    (* rom_style = "block" *) reg [7:0] imem2 [0:4095];
    (* rom_style = "block" *) reg [7:0] imem3 [0:4095];

    // =========================================================================
    // 5. Data RAM 16KB, chia 4 byte-bank
    // =========================================================================
    (* ram_style = "block" *) reg [7:0] dmem0 [0:4095];
    (* ram_style = "block" *) reg [7:0] dmem1 [0:4095];
    (* ram_style = "block" *) reg [7:0] dmem2 [0:4095];
    (* ram_style = "block" *) reg [7:0] dmem3 [0:4095];

    initial begin
        // Dat 4 file nay cung thu muc voi system_top.v trong Gowin project:
        //   firmware_bank0.hex, firmware_bank1.hex, firmware_bank2.hex, firmware_bank3.hex
        // Init ca IMEM va DMEM de CPU co the fetch code tu IMEM va load hang/string tu DMEM.
        $readmemh("firmware_bank0.hex", imem0);
        $readmemh("firmware_bank1.hex", imem1);
        $readmemh("firmware_bank2.hex", imem2);
        $readmemh("firmware_bank3.hex", imem3);

        $readmemh("firmware_bank0.hex", dmem0);
        $readmemh("firmware_bank1.hex", dmem1);
        $readmemh("firmware_bank2.hex", dmem2);
        $readmemh("firmware_bank3.hex", dmem3);
    end

    // Instruction bus: chi doc tu IMEM, 1-cycle acknowledge
    always @(posedge clk) begin
        if (rst) begin
            ibus_ack <= 1'b0;
            ibus_rdt <= 32'b0;
        end else begin
            ibus_rdt <= {
                imem3[ibus_word_addr],
                imem2[ibus_word_addr],
                imem1[ibus_word_addr],
                imem0[ibus_word_addr]
            };
            ibus_ack <= ibus_cyc && !ibus_ack;
        end
    end

    // Data bus: chi doc/ghi DMEM, khong dung chung array voi instruction fetch.
    // Cach nay tranh Gowin infer DPB WRITE_MODE0=2'b10.
    reg [31:0] dbus_rdt_ram;

    always @(posedge clk) begin
        if (rst) begin
            dbus_rdt_ram <= 32'b0;
        end else if (dbus_cyc && ram_sel) begin
            dbus_rdt_ram <= {
                dmem3[dbus_word_addr],
                dmem2[dbus_word_addr],
                dmem1[dbus_word_addr],
                dmem0[dbus_word_addr]
            };

            if (dbus_we) begin
                if (dbus_sel[0]) dmem0[dbus_word_addr] <= dbus_dat[7:0];
                if (dbus_sel[1]) dmem1[dbus_word_addr] <= dbus_dat[15:8];
                if (dbus_sel[2]) dmem2[dbus_word_addr] <= dbus_dat[23:16];
                if (dbus_sel[3]) dmem3[dbus_word_addr] <= dbus_dat[31:24];
            end
        end
    end

    // =========================================================================
    // 6. LED MMIO
    // =========================================================================
    reg [5:0] led_reg;

    always @(posedge clk) begin
        if (rst)
            led_reg <= 6'b000000;
        else if (led_sel && dbus_we && dbus_cyc)
            led_reg <= dbus_dat[5:0];
    end

    // Tang Nano LED thuong active-low: led_reg=1 thi LED sang.
    // Cho firmware dieu khien du ca 6 LED.
    assign leds = ~led_reg;

    // =========================================================================
    // 7. UART MMIO
    // =========================================================================
    wire [31:0] uart_rd_data;
    wire        uart_wait;
    wire        cpu_uart_tx;

    simpleuart #(
        .DEFAULT_DIV(16'd234)
    ) uart_inst (
        .clk(clk),
        .resetn(!rst),
        .ser_tx(cpu_uart_tx),
        .ser_rx(uart_rx),

        .reg_div_we(4'b0000),
        .reg_div_di(32'b0),
        .reg_div_do(),

        .reg_dat_we(uart_sel && dbus_we && dbus_cyc),
        .reg_dat_re(uart_sel && !dbus_we && dbus_cyc && dbus_ack),
        .reg_dat_di(dbus_dat),
        .reg_dat_do(uart_rd_data),
        .reg_dat_wait(uart_wait)
    );

    assign uart_tx = cpu_uart_tx;

    // Data read mux
    assign dbus_rdt = ram_sel  ? dbus_rdt_ram :
                      uart_sel ? uart_rd_data :
                                 32'b0;

    // Data bus acknowledge
    // - RAM/LED ack ngay 1 chu ky.
    // - UART write chi ack khi transmitter san sang.
    // - UART read ack ngay; neu chua co ky tu simpleuart tra ve 0xFFFF_FFFF.
    always @(posedge clk) begin
        if (rst)
            dbus_ack <= 1'b0;
        else
            dbus_ack <= dbus_cyc && !dbus_ack && (uart_sel ? !uart_wait : 1'b1);
    end

endmodule

`default_nettype wire
