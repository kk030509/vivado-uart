module uart_rx_fsm(
    input        clk,
    input        reset,
    input        tick,
    input        rx_sync,
    output [7:0] rx_data,
    output       rx_done,
    output       frame_error
);

    // UART RX FSM 상태 정의
    parameter S_IDLE  = 3'd0;
    parameter S_START = 3'd1;
    parameter S_DATA  = 3'd2;
    parameter S_STOP  = 3'd3;

    // 현재 상태 Register
    reg [2:0] state;

    // 16x Sample Tick Counter
    reg [3:0] sample_count;

    // 수신 중인 Data Bit 위치
    reg [2:0] bit_count;

    // 수신 Bit 임시 저장 Register
    reg [7:0] shift_reg;

    // 정상 수신 완료 Byte 저장 Register
    reg [7:0] data_reg;

    // 1Byte 수신 완료 Pulse Register
    reg done_reg;

    // Stop Bit 오류 Pulse Register
    reg frame_error_reg;

    always @(posedge clk) begin
        // Reset 시 모든 상태와 내부 Register를 초기화함
        if (reset) begin
            state           <= S_IDLE;
            sample_count    <= 4'd0;
            bit_count       <= 3'd0;
            shift_reg       <= 8'd0;
            data_reg        <= 8'd0;
            done_reg        <= 1'b0;
            frame_error_reg <= 1'b0;
        end

        // Reset이 아니면 UART RX FSM을 수행함
        else begin
            // rx_done과 frame_error는 1Clock Pulse이므로 기본값을 0으로 둠
            done_reg        <= 1'b0;
            frame_error_reg <= 1'b0;

            case (state)
                S_IDLE: begin
                    // Idle 상태에서는 Start Bit를 기다림
                    sample_count <= 4'd0;
                    bit_count    <= 3'd0;

                    // RX가 0이면 Start Bit 후보로 판단함
                    if (rx_sync == 1'b0) begin
                        state <= S_START;
                    end

                    // RX가 1이면 Idle 상태를 유지함
                    else begin
                        state <= S_IDLE;
                    end
                end

                S_START: begin
                    // Tick이 발생할 때만 Sample 위치를 이동함
                    if (tick) begin
                        // Start Bit 중앙 위치에서 다시 확인함
                        if (sample_count == 4'd7) begin
                            sample_count <= 4'd0;

                            // 중앙에서도 0이면 정상 Start Bit로 판단함
                            if (rx_sync == 1'b0) begin
                                state <= S_DATA;
                            end

                            // 중앙에서 1이면 Noise로 보고 Idle로 복귀함
                            else begin
                                state <= S_IDLE;
                            end
                        end

                        // 아직 중앙 위치가 아니면 Sample Count를 증가함
                        else begin
                            sample_count <= sample_count + 1'b1;
                        end
                    end
                end

                S_DATA: begin
                    // Tick이 발생할 때만 Data Bit 중앙 위치를 계산함
                    if (tick) begin
                        // 16Tick마다 Data Bit 중앙에서 샘플링함
                        if (sample_count == 4'd15) begin
                            sample_count <= 4'd0;

                            // UART는 LSB First이므로 bit_count 위치에 저장함
                            shift_reg[bit_count] <= rx_sync;

                            // D0~D7까지 모두 수신하면 Stop Bit 확인 상태로 이동함
                            if (bit_count == 3'd7) begin
                                bit_count <= 3'd0;
                                state     <= S_STOP;
                            end

                            // 아직 8Bit가 끝나지 않았으면 다음 Bit로 이동함
                            else begin
                                bit_count <= bit_count + 1'b1;
                            end
                        end

                        // 다음 Data Bit 중앙까지 대기함
                        else begin
                            sample_count <= sample_count + 1'b1;
                        end
                    end
                end

                S_STOP: begin
                    // Tick이 발생할 때만 Stop Bit 중앙 위치를 계산함
                    if (tick) begin
                        // Stop Bit 중앙 위치에서 값을 확인함
                        if (sample_count == 4'd15) begin
                            sample_count <= 4'd0;

                            // Stop Bit가 1이면 정상 수신 완료임
                            if (rx_sync == 1'b1) begin
                                data_reg <= shift_reg;
                                done_reg <= 1'b1;
                            end

                            // Stop Bit가 0이면 Frame Error임
                            else begin
                                frame_error_reg <= 1'b1;
                            end

                            // 다음 문자를 위해 Idle로 복귀함
                            state <= S_IDLE;
                        end

                        // Stop Bit 중앙 위치까지 대기함
                        else begin
                            sample_count <= sample_count + 1'b1;
                        end
                    end
                end

                default: begin
                    // 정의되지 않은 상태에서는 Idle로 복귀함
                    state <= S_IDLE;
                end
            endcase
        end
    end

    assign rx_data     = data_reg;
    assign rx_done     = done_reg;
    assign frame_error = frame_error_reg;

endmodule
