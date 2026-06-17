`timescale 1ns / 1ps

// uart_rx_core.v
// UART RX 상위 Core임.
// 내부에 uart_rx_sync, uart_baud_tick_gen, uart_rx_fsm, uart_rx_fifo를 포함함.
// CLKS_PER_SAMPLE을 외부 parameter로 받아 Baud Rate 변경과 시뮬레이션 단축에 대응함.

module uart_rx_core #(
    // uart_core 또는 Top에서 넘겨받는 16x Oversampling Tick 생성용 Clock 수임.
    // 100 MHz / (9600 bps x 16) 기준 약 651임.
    parameter CLKS_PER_SAMPLE = 651
)(
    // Top 또는 uart_core에서 넘겨받는 100 MHz 시스템 Clock임.
    input        clk,

    // Top 또는 uart_core에서 넘겨받는 Active-high 동기 Reset임.
    input        reset,

    // PC 또는 외부장치에서 FPGA 방향으로 들어오는 UART RX 직렬 신호임.
    input        rx,

    // 외부 제어 회로가 RX FIFO를 Clear할 때 사용하는 신호임.
    input        fifo_clear,

    // RX FIFO에서 외부 후단 회로로 넘기는 수신 Byte임.
    output [7:0] rx_data,

    // RX FIFO에 읽을 데이터가 있음을 외부 후단 회로로 알려주는 신호임.
    output       rx_valid,

    // 외부 후단 회로가 RX FIFO에 넘기는 Read 요청임.
    input        rx_ready,

    // RX FIFO Empty 상태임.
    output       rx_empty,

    // RX FIFO Full 상태임.
    output       rx_full,

    // UART Stop Bit 오류 상태임.
    output       frame_error,

    // RX FIFO Overrun 오류 상태임.
    output       overrun_error
);

    // uart_rx_sync가 uart_rx_fsm으로 넘기는 동기화된 RX 신호임.
    wire rx_sync;

    // uart_baud_tick_gen이 uart_rx_fsm으로 넘기는 16x Oversampling Tick임.
    wire sample_tick;

    // uart_rx_fsm이 uart_rx_fifo로 넘기는 수신 Byte임.
    wire [7:0] fsm_rx_data;

    // uart_rx_fsm이 uart_rx_fifo로 넘기는 1Byte 수신 완료 Pulse임.
    wire fsm_rx_done;

    // uart_rx_fsm이 생성하는 Stop Bit 오류 Pulse임.
    wire fsm_frame_error;

    // 외부 RX 입력을 Clock 도메인으로 동기화함.
    uart_rx_sync u_uart_rx_sync (
        .clk      (clk),
        .reset    (reset),
        .rx_async (rx),
        .rx_sync  (rx_sync)
    );

    // RX 16x Oversampling Tick을 생성함.
    // CLKS_PER_SAMPLE은 uart_core 또는 상위 Top에서 전달받음.
    uart_baud_tick_gen #(
        .CLKS_PER_SAMPLE(CLKS_PER_SAMPLE)
    ) u_uart_baud_tick_gen (
        .clk   (clk),
        .reset (reset),
        .tick  (sample_tick)
    );

    // 동기화된 RX 신호를 UART 8N1 규칙에 따라 1Byte로 복원함.
    uart_rx_fsm u_uart_rx_fsm (
        .clk         (clk),
        .reset       (reset),
        .tick        (sample_tick),
        .rx_sync     (rx_sync),
        .rx_data     (fsm_rx_data),
        .rx_done     (fsm_rx_done),
        .frame_error (fsm_frame_error)
    );

    // 수신 완료된 Byte를 RX FIFO에 저장함.
    uart_rx_fifo u_uart_rx_fifo (
        .clk           (clk),
        .reset         (reset),
        .clear         (fifo_clear),
        .wr_en         (fsm_rx_done),
        .wr_data       (fsm_rx_data),
        .rd_en         (rx_ready),
        .rd_data       (rx_data),
        .empty         (rx_empty),
        .full          (rx_full),
        .valid         (rx_valid),
        .overrun_error (overrun_error)
    );

    // 외부로 공개하는 frame_error는 RX FSM의 Stop Bit 오류와 동일함.
    assign frame_error = fsm_frame_error;

endmodule
