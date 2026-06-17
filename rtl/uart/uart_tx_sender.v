`timescale 1ns / 1ps

// uart_tx_sender.v
// TX FIFO와 TX FSM 사이에 위치하는 송신 제어기임.
// FIFO에 데이터가 있고 TX FSM이 쉬고 있으면 FIFO에서 1Byte를 꺼냄.
// 꺼낸 데이터를 tx_data로 넘기고 tx_start를 1클럭 발생시킴.

module uart_tx_sender(
    // uart_tx_core에서 넘겨받는 100 MHz 시스템 Clock임.
    input  wire       clk,

    // uart_tx_core에서 넘겨받는 Active-high 동기 Reset임.
    input  wire       reset,

    // 앞단 uart_tx_fifo에서 넘겨받는 Read 데이터임.
    input  wire [7:0] fifo_rd_data,

    // 앞단 uart_tx_fifo에서 넘겨받는 Empty 상태임.
    input  wire       fifo_empty,

    // 이 모듈이 앞단 uart_tx_fifo로 넘기는 Read 요청임.
    output reg        fifo_rd_en,

    // 이 모듈이 뒤단 uart_tx_fsm으로 넘기는 송신 데이터임.
    output reg  [7:0] tx_data,

    // 이 모듈이 뒤단 uart_tx_fsm으로 넘기는 송신 시작 1클럭 Pulse임.
    output reg        tx_start,

    // 뒤단 uart_tx_fsm에서 넘겨받는 송신 중 상태임.
    input  wire       tx_busy
);

    // FIFO에 보낼 데이터가 있는지 확인하는 대기 상태임.
    localparam S_IDLE      = 2'b00;

    // tx_start를 받은 TX FSM이 tx_busy = 1로 바뀌기를 기다리는 상태임.
    localparam S_WAIT_BUSY = 2'b01;

    // TX FSM이 송신을 끝내고 tx_busy = 0으로 돌아오기를 기다리는 상태임.
    localparam S_WAIT_DONE = 2'b10;

    // Sender의 현재 상태임.
    reg [1:0] state_reg;

    always @(posedge clk) begin
        // Reset이면 Sender 상태와 출력 신호를 초기화함.
        if (reset) begin
            state_reg  <= S_IDLE;
            fifo_rd_en <= 1'b0;
            tx_data    <= 8'd0;
            tx_start   <= 1'b0;
        end

        // Reset이 아니면 FIFO 상태와 TX FSM 상태를 확인함.
        else begin
            // fifo_rd_en은 1클럭 Pulse로 사용하므로 기본값을 0으로 둠.
            fifo_rd_en <= 1'b0;

            // tx_start도 1클럭 Pulse로 사용하므로 기본값을 0으로 둠.
            tx_start <= 1'b0;

            case (state_reg)

                // FIFO에 데이터가 있는지 확인하고 송신 가능하면 1Byte를 꺼냄.
                S_IDLE: begin
                    // FIFO가 비어 있지 않고 TX FSM이 쉬고 있으면 송신을 시작함.
                    if (!fifo_empty && !tx_busy) begin
                        tx_data    <= fifo_rd_data;
                        tx_start   <= 1'b1;
                        fifo_rd_en <= 1'b1;
                        state_reg  <= S_WAIT_BUSY;
                    end

                    // FIFO가 비어 있거나 TX FSM이 바쁘면 대기함.
                    else begin
                        tx_data   <= tx_data;
                        state_reg <= S_IDLE;
                    end
                end

                // TX FSM이 tx_start를 인식하고 tx_busy를 1로 만들 때까지 기다림.
                S_WAIT_BUSY: begin
                    // tx_busy가 1이면 TX FSM이 송신을 시작한 것으로 판단함.
                    if (tx_busy) begin
                        state_reg <= S_WAIT_DONE;
                    end

                    // 아직 tx_busy가 1이 아니면 같은 상태에서 대기함.
                    else begin
                        state_reg <= S_WAIT_BUSY;
                    end
                end

                // TX FSM이 송신을 완료할 때까지 기다림.
                S_WAIT_DONE: begin
                    // tx_busy가 0으로 돌아오면 다음 Byte 송신을 준비함.
                    if (!tx_busy) begin
                        state_reg <= S_IDLE;
                    end

                    // 아직 송신 중이면 대기함.
                    else begin
                        state_reg <= S_WAIT_DONE;
                    end
                end

                // 정의되지 않은 상태이면 안전하게 대기 상태로 복귀함.
                default: begin
                    state_reg <= S_IDLE;
                end
            endcase
        end
    end

endmodule
