`timescale 1ns / 1ps

// uart_core.v
// UART RX Core와 UART TX Core를 하나로 묶는 순수 UART 송수신 Core임.
// AXI4-Lite 확장을 고려하여 보드 버튼, LED, BRAM Line Buffer는 포함하지 않음.
// CLK_FREQ와 BAUD_RATE를 parameter로 두어 내부 Clock Count 하드코딩을 줄임.

module uart_core #(
    // 상위 Top 또는 AXI Wrapper에서 지정하는 시스템 Clock 주파수임.
    parameter CLK_FREQ = 100_000_000,

    // 상위 Top 또는 AXI Wrapper에서 지정하는 UART Baud Rate임.
    parameter BAUD_RATE = 9600,

    // RX 16x Oversampling 배율임.
    parameter RX_OVERSAMPLE = 16,

    // RX 16x Oversampling Tick 생성용 Clock 수임.
    parameter CLKS_PER_SAMPLE = CLK_FREQ / (BAUD_RATE * RX_OVERSAMPLE),

    // TX 1 Bit 시간 생성용 Clock 수임.
    parameter CLKS_PER_BIT = CLK_FREQ / BAUD_RATE
)(
    // 상위 Top 또는 AXI Wrapper에서 넘겨받는 시스템 Clock임.
    input  wire       clk,

    // 상위 Top 또는 AXI Wrapper에서 넘겨받는 Active-high 동기 Reset임.
    input  wire       reset,

    // PC 또는 외부장치에서 FPGA 방향으로 들어오는 UART RX 직렬 신호임.
    input  wire       rx_serial,

    // FPGA에서 PC 또는 외부장치 방향으로 나가는 UART TX 직렬 신호임.
    output wire       tx_serial,

    // =========================================================
    // RX 데이터 인터페이스
    // =========================================================

    // uart_rx_core가 외부 후단 회로로 넘기는 수신 Byte임.
    output wire [7:0] rx_data,

    // uart_rx_core 내부 RX FIFO에 읽을 데이터가 있음을 알리는 신호임.
    output wire       rx_valid,

    // 외부 후단 회로가 uart_rx_core 내부 RX FIFO에 넘기는 Read 요청임.
    input  wire       rx_ready,

    // uart_rx_core 내부 RX FIFO Empty 상태임.
    output wire       rx_empty,

    // uart_rx_core 내부 RX FIFO Full 상태임.
    output wire       rx_full,

    // 외부 제어 회로가 uart_rx_core 내부 RX FIFO를 Clear할 때 사용하는 신호임.
    input  wire       rx_fifo_clear,

    // UART Stop Bit 오류 상태임.
    output wire       frame_error,

    // RX FIFO Overrun 오류 상태임.
    output wire       overrun_error,

    // =========================================================
    // TX 데이터 인터페이스
    // =========================================================

    // 외부 앞단 회로가 uart_tx_core 내부 TX FIFO에 데이터를 저장할 때 사용하는 Write 요청임.
    input  wire       tx_wr_en,

    // 외부 앞단 회로가 uart_tx_core 내부 TX FIFO에 저장할 송신 Byte임.
    input  wire [7:0] tx_wr_data,

    // uart_tx_core 내부 TX FIFO Full 상태임.
    output wire       tx_full,

    // uart_tx_core 내부 TX FIFO Empty 상태임.
    output wire       tx_empty,

    // uart_tx_core 내부 TX FIFO 저장 데이터 개수임.
    output wire [4:0] tx_count,

    // uart_tx_core 내부 TX FSM 송신 중 상태임.
    output wire       tx_busy,

    // uart_tx_core 내부 TX FSM 1Byte 송신 완료 Pulse임.
    output wire       tx_done
);

    // =========================================================
    // 1. UART RX Core
    // =========================================================

    // UART RX Core는 rx_serial을 1Byte 병렬 데이터로 복원함.
    // CLKS_PER_SAMPLE은 CLK_FREQ와 BAUD_RATE에서 계산된 값을 전달받음.
    uart_rx_core #(
        .CLKS_PER_SAMPLE(CLKS_PER_SAMPLE)
    ) u_uart_rx_core (
        .clk           (clk),
        .reset         (reset),
        .rx            (rx_serial),

        .fifo_clear    (rx_fifo_clear),

        .rx_data       (rx_data),
        .rx_valid      (rx_valid),
        .rx_ready      (rx_ready),

        .rx_empty      (rx_empty),
        .rx_full       (rx_full),

        .frame_error   (frame_error),
        .overrun_error (overrun_error)
    );

    // =========================================================
    // 2. UART TX Core
    // =========================================================

    // UART TX Core는 tx_wr_en / tx_wr_data로 받은 Byte를 TX FIFO에 저장함.
    // CLKS_PER_BIT는 CLK_FREQ와 BAUD_RATE에서 계산된 값을 전달받음.
    uart_tx_core #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) u_uart_tx_core (
        .clk        (clk),
        .reset      (reset),

        .tx_wr_en   (tx_wr_en),
        .tx_wr_data (tx_wr_data),

        .tx_full    (tx_full),
        .tx_empty   (tx_empty),
        .tx_count   (tx_count),

        .tx_busy    (tx_busy),
        .tx_done    (tx_done),

        .tx_serial  (tx_serial)
    );

endmodule
