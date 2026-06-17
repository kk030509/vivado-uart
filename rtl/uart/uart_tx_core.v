`timescale 1ns / 1ps

// uart_tx_core.v
// UART TX 상위 Core임.
// 내부에 uart_tx_fifo, uart_tx_sender, uart_tx_fsm을 포함함.
// RX 쪽 uart_rx_core와 대응되는 TX 쪽 상위 Core 역할을 함.

module uart_tx_core #(
    // 100 MHz / 9600 bps 기준 1 Bit 시간 Clock 수임.
    parameter CLKS_PER_BIT = 10417
)(
    // Top 또는 상위 모듈에서 넘겨받는 100 MHz 시스템 Clock임.
    input  wire       clk,

    // Top 또는 상위 모듈에서 넘겨받는 Active-high 동기 Reset임.
    input  wire       reset,

    // 앞단 로직, Echo Controller, AXI Register 등에서 넘겨받는 TX FIFO Write 요청임.
    input  wire       tx_wr_en,

    // 앞단 로직, Echo Controller, AXI Register 등에서 넘겨받는 송신 데이터임.
    input  wire [7:0] tx_wr_data,

    // TX FIFO가 가득 찼음을 앞단에 알려주는 상태 신호임.
    output wire       tx_full,

    // TX FIFO가 비어 있음을 앞단 또는 Top에 알려주는 상태 신호임.
    output wire       tx_empty,

    // TX FIFO에 저장된 데이터 개수임.
    output wire [4:0] tx_count,

    // TX FSM이 송신 중이면 1임.
    output wire       tx_busy,

    // TX FSM이 1Byte 송신을 완료한 순간 1클럭 Pulse를 출력함.
    output wire       tx_done,

    // FPGA에서 PC 또는 외부장치 방향으로 나가는 UART TX 신호임.
    output wire       tx_serial
);

    // uart_tx_fifo가 uart_tx_sender로 넘기는 Read 데이터임.
    wire [7:0] fifo_rd_data;

    // uart_tx_fifo가 uart_tx_sender로 넘기는 Empty 상태임.
    wire       fifo_empty;

    // uart_tx_sender가 uart_tx_fifo로 넘기는 Read 요청임.
    wire       fifo_rd_en;

    // uart_tx_sender가 uart_tx_fsm으로 넘기는 송신 데이터임.
    wire [7:0] tx_data;

    // uart_tx_sender가 uart_tx_fsm으로 넘기는 송신 시작 Pulse임.
    wire       tx_start;

    // 송신 대기 데이터를 저장하는 TX FIFO임.
    uart_tx_fifo u_uart_tx_fifo (
        .clk     (clk),
        .reset   (reset),

        .wr_en   (tx_wr_en),
        .wr_data (tx_wr_data),

        .rd_en   (fifo_rd_en),
        .rd_data (fifo_rd_data),

        .full    (tx_full),
        .empty   (fifo_empty),
        .count   (tx_count)
    );

    // 외부로 공개하는 tx_empty는 내부 FIFO Empty 상태와 동일함.
    assign tx_empty = fifo_empty;

    // FIFO와 TX FSM 사이에서 송신 타이밍을 제어하는 Sender임.
    uart_tx_sender u_uart_tx_sender (
        .clk          (clk),
        .reset        (reset),

        .fifo_rd_data (fifo_rd_data),
        .fifo_empty   (fifo_empty),
        .fifo_rd_en   (fifo_rd_en),

        .tx_data      (tx_data),
        .tx_start     (tx_start),
        .tx_busy      (tx_busy)
    );

    // 실제 UART 8N1 직렬 송신을 수행하는 TX FSM임.
    uart_tx_fsm #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) u_uart_tx_fsm (
        .clk       (clk),
        .reset     (reset),

        .tx_start  (tx_start),
        .tx_data   (tx_data),

        .tx_serial (tx_serial),
        .tx_busy   (tx_busy),
        .tx_done   (tx_done)
    );

endmodule
