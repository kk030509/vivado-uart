`timescale 1ns / 1ps

// uart_tx_fsm.v
// 실제 UART TX 8N1 직렬 송신 FSM임.
// tx_start가 1클럭 들어오면 tx_data 1Byte를 Start, Data, Stop 순서로 송신함.
// 기존 uart_tx_core 역할을 FSM 이름으로 재정리한 모듈임.

module uart_tx_fsm #(
    // 100 MHz / 9600 bps 기준 1 Bit 시간 Clock 수임.
    parameter CLKS_PER_BIT = 10417
)(
    // uart_tx_core에서 넘겨받는 100 MHz 시스템 Clock임.
    input  wire       clk,

    // uart_tx_core에서 넘겨받는 Active-high 동기 Reset임.
    input  wire       reset,

    // 앞단 uart_tx_sender에서 넘겨받는 송신 시작 1클럭 Pulse임.
    input  wire       tx_start,

    // 앞단 uart_tx_sender에서 넘겨받는 송신 데이터임.
    input  wire [7:0] tx_data,

    // FPGA에서 PC 방향으로 나가는 UART TX 직렬 신호임.
    output reg        tx_serial,

    // 이 모듈이 생성하는 송신 중 상태임.
    output reg        tx_busy,

    // 이 모듈이 생성하는 송신 완료 1클럭 Pulse임.
    output reg        tx_done
);

    // 송신 대기 상태임.
    localparam S_IDLE  = 2'b00;

    // Start Bit 출력 상태임.
    localparam S_START = 2'b01;

    // Data Bit 출력 상태임.
    localparam S_DATA  = 2'b10;

    // Stop Bit 출력 상태임.
    localparam S_STOP  = 2'b11;

    // 현재 FSM 상태 저장 레지스터임.
    reg [1:0] state_reg;

    // 1 Bit 시간을 세는 Counter임.
    reg [31:0] bit_timer;

    // 현재 출력 중인 Data Bit 번호임.
    reg [2:0] bit_index;

    // 송신 중 데이터가 바뀌지 않도록 저장하는 레지스터임.
    reg [7:0] data_reg;

    always @(posedge clk) begin
        // tx_done은 1클럭 Pulse이므로 기본값을 0으로 둠.
        tx_done <= 1'b0;

        // Reset이면 FSM 상태와 출력을 초기화함.
        if (reset) begin
            state_reg <= S_IDLE;
            bit_timer <= 32'd0;
            bit_index <= 3'd0;
            data_reg  <= 8'd0;
            tx_serial <= 1'b1;
            tx_busy   <= 1'b0;
            tx_done   <= 1'b0;
        end

        // Reset이 아니면 현재 상태에 따라 UART 송신을 수행함.
        else begin
            case (state_reg)

                // 송신 대기 상태임.
                S_IDLE: begin
                    tx_serial <= 1'b1;
                    tx_busy   <= 1'b0;
                    bit_timer <= 32'd0;
                    bit_index <= 3'd0;

                    // tx_start가 들어오면 tx_data를 저장하고 Start Bit 출력을 시작함.
                    if (tx_start) begin
                        data_reg  <= tx_data;
                        tx_serial <= 1'b0;
                        tx_busy   <= 1'b1;
                        state_reg <= S_START;
                    end

                    // tx_start가 없으면 대기 상태를 유지함.
                    else begin
                        state_reg <= S_IDLE;
                    end
                end

                // Start Bit를 1 Bit 시간 동안 출력함.
                S_START: begin
                    tx_serial <= 1'b0;
                    tx_busy   <= 1'b1;

                    // Start Bit 시간이 끝나면 Data Bit D0 출력으로 이동함.
                    if (bit_timer == CLKS_PER_BIT - 1) begin
                        bit_timer <= 32'd0;
                        tx_serial <= data_reg[0];
                        bit_index <= 3'd0;
                        state_reg <= S_DATA;
                    end

                    // Start Bit 시간이 끝나지 않았으면 Counter를 증가함.
                    else begin
                        bit_timer <= bit_timer + 1'b1;
                    end
                end

                // Data Bit D0~D7을 순서대로 출력함.
                S_DATA: begin
                    tx_busy <= 1'b1;

                    // 현재 Data Bit 시간이 끝나면 다음 Bit로 이동함.
                    if (bit_timer == CLKS_PER_BIT - 1) begin
                        bit_timer <= 32'd0;

                        // D7까지 출력했으면 Stop Bit로 이동함.
                        if (bit_index == 3'd7) begin
                            bit_index <= 3'd0;
                            tx_serial <= 1'b1;
                            state_reg <= S_STOP;
                        end

                        // D7이 아니면 다음 Data Bit를 출력함.
                        else begin
                            bit_index <= bit_index + 1'b1;
                            tx_serial <= data_reg[bit_index + 1'b1];
                            state_reg <= S_DATA;
                        end
                    end

                    // 현재 Data Bit 시간이 끝나지 않았으면 Counter를 증가함.
                    else begin
                        bit_timer <= bit_timer + 1'b1;
                    end
                end

                // Stop Bit를 1 Bit 시간 동안 출력함.
                S_STOP: begin
                    tx_serial <= 1'b1;
                    tx_busy   <= 1'b1;

                    // Stop Bit 시간이 끝나면 송신을 완료함.
                    if (bit_timer == CLKS_PER_BIT - 1) begin
                        bit_timer <= 32'd0;
                        tx_busy   <= 1'b0;
                        tx_done   <= 1'b1;
                        state_reg <= S_IDLE;
                    end

                    // Stop Bit 시간이 끝나지 않았으면 Counter를 증가함.
                    else begin
                        bit_timer <= bit_timer + 1'b1;
                    end
                end

                // 정의되지 않은 상태이면 안전하게 IDLE로 복귀함.
                default: begin
                    state_reg <= S_IDLE;
                    bit_timer <= 32'd0;
                    bit_index <= 3'd0;
                    tx_serial <= 1'b1;
                    tx_busy   <= 1'b0;
                    tx_done   <= 1'b0;
                end
            endcase
        end
    end

endmodule
