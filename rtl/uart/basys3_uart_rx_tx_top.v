`timescale 1ns / 1ps

// basys3_uart_rx_tx_top.v
// Basys3 보드용 RX + TX 결합 Top임.
// uart_core.v를 사용하여 RX Core와 TX Core를 하나의 UART Core로 묶음.
// rx_bram_line_buffer.v는 uart_core 밖에 둠.
// button_debounce_pulse.v도 uart_core 밖에 둠.
// Echo는 아직 수행하지 않음.

module basys3_uart_rx_tx_top #(
    // Basys3 시스템 Clock 주파수임.
    parameter CLK_FREQ = 100_000_000,

    // 보드 실동작용 UART Baud Rate임.
    parameter BAUD_RATE = 9600
)(
    // Basys3 보드에서 넘겨받는 100 MHz 시스템 Clock임.
    input  wire        clk,

    // Basys3 보드에서 넘겨받는 Center Button 입력임.
    // TX 문자 송신 버튼으로 사용함.
    input  wire        btnC,

    // Basys3 보드에서 넘겨받는 Up Button 입력임.
    // 내부 Reset으로 사용함.
    input  wire        btnU,

    // PC에서 FPGA 방향으로 들어오는 UART RX 신호임.
    input  wire        RsRx,

    // FPGA에서 PC 방향으로 나가는 UART TX 신호임.
    output wire        RsTx,

    // RX 상태와 TX 상태를 함께 표시하는 LED 출력임.
    output wire [15:0] led
);

    // btnU를 내부 Reset 신호로 사용함.
    wire reset;

    assign reset = btnU;

    // =========================================================
    // 1. uart_core RX 인터페이스 신호
    // =========================================================

    // uart_core가 rx_bram_line_buffer로 넘기는 수신 Byte임.
    wire [7:0] rx_data;

    // uart_core 내부 RX FIFO에 읽을 데이터가 있음을 표시하는 Valid 신호임.
    wire       rx_valid;

    // rx_bram_line_buffer가 uart_core 내부 RX FIFO에 넘기는 Read 요청임.
    wire       rx_ready;

    // uart_core 내부 RX FIFO Empty 상태임.
    wire       rx_empty;

    // uart_core 내부 RX FIFO Full 상태임.
    wire       rx_full;

    // uart_core가 생성하는 UART Stop Bit 오류 신호임.
    wire       frame_error;

    // uart_core가 생성하는 RX FIFO Overrun 오류 신호임.
    wire       overrun_error;

    // =========================================================
    // 2. RX BRAM Line Buffer 신호
    // =========================================================

    // rx_bram_line_buffer가 출력하는 마지막 실제 수신 문자임.
    wire [7:0] line_last_data;

    // rx_bram_line_buffer가 LF 감지 후 출력하는 Frame 완료 1클럭 Pulse임.
    wire       line_frame_valid;

    // rx_bram_line_buffer가 출력하는 LF 제외 문자열 길이임.
    wire [6:0] line_frame_length;

    // rx_bram_line_buffer가 출력하는 문자열 수신 중 상태임.
    wire       line_receiving;

    // rx_bram_line_buffer가 출력하는 Buffer Overflow 상태임.
    wire       line_overflow;

    // rx_bram_line_buffer가 출력하는 Overflow 이후 폐기 상태임.
    wire       line_discarding;

    // LED 표시 시간을 만들기 위한 분주 Counter임.
    reg [25:0] display_div;

    // LED0~LED7에 표시할 마지막 수신 문자임.
    reg [7:0] display_last_data;

    // frame_valid는 1클럭 Pulse이므로 LED 확인용 Latch를 둠.
    reg frame_valid_latched;

    // =========================================================
    // 3. TX 인터페이스 신호
    // =========================================================

    // button_debounce_pulse가 생성하는 1클럭 버튼 Pulse임.
    wire btn_pulse;

    // uart_core 내부 TX FIFO에 넘기는 Write 요청임.
    reg tx_wr_en;

    // uart_core 내부 TX FIFO에 넘기는 송신 데이터임.
    reg [7:0] tx_wr_data;

    // 다음에 송신할 ASCII 문자값임.
    reg [7:0] ascii_reg;

    // uart_core 내부 TX FIFO Full 상태임.
    wire tx_full;

    // uart_core 내부 TX FIFO Empty 상태임.
    wire tx_empty;

    // uart_core 내부 TX FIFO 저장 데이터 개수임.
    wire [4:0] tx_count;

    // uart_core 내부 TX FSM 송신 중 상태임.
    wire tx_busy;

    // uart_core 내부 TX FSM 1Byte 송신 완료 Pulse임.
    wire tx_done;

    // =========================================================
    // 4. UART Core
    // =========================================================

    // UART Core는 RX Core와 TX Core를 포함함.
    // CLK_FREQ와 BAUD_RATE를 넘겨 RX/TX 내부 Clock Count를 한 곳에서 관리함.
    uart_core #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) u_uart_core (
        .clk            (clk),
        .reset          (reset),

        .rx_serial      (RsRx),
        .tx_serial      (RsTx),

        .rx_data        (rx_data),
        .rx_valid       (rx_valid),
        .rx_ready       (rx_ready),
        .rx_empty       (rx_empty),
        .rx_full        (rx_full),
        .rx_fifo_clear  (1'b0),
        .frame_error    (frame_error),
        .overrun_error  (overrun_error),

        .tx_wr_en       (tx_wr_en),
        .tx_wr_data     (tx_wr_data),
        .tx_full        (tx_full),
        .tx_empty       (tx_empty),
        .tx_count       (tx_count),
        .tx_busy        (tx_busy),
        .tx_done        (tx_done)
    );

    // =========================================================
    // 5. RX BRAM Line Buffer
    // =========================================================

    // RX BRAM Line Buffer는 uart_core 밖에 둠.
    // LF를 기준으로 문자열 Frame을 구분함.
    // 현재 단계에서는 RX 데이터를 TX로 되돌려 보내지 않음.
    rx_bram_line_buffer u_rx_bram_line_buffer (
        .clk          (clk),
        .reset        (reset),

        .rx_data      (rx_data),
        .rx_valid     (rx_valid),
        .rx_ready     (rx_ready),

        .last_data    (line_last_data),
        .frame_valid  (line_frame_valid),
        .frame_length (line_frame_length),
        .receiving    (line_receiving),
        .overflow     (line_overflow),
        .discarding   (line_discarding)
    );

    // =========================================================
    // 6. Button Debounce
    // =========================================================

    // btnC 입력을 안정화하고 1클럭 Pulse로 변환함.
    // 이 Pulse가 발생할 때마다 ASCII 문자 1개를 TX FIFO에 넣음.
    button_debounce_pulse u_button_debounce_pulse (
        .clk       (clk),
        .rst       (reset),
        .btn_in    (btnC),
        .btn_pulse (btn_pulse)
    );

    // =========================================================
    // 7. RX 표시 Register
    // =========================================================

    always @(posedge clk) begin
        // Reset이면 RX 표시용 Register를 초기화함.
        if (reset) begin
            display_div         <= 26'd0;
            display_last_data   <= 8'd0;
            frame_valid_latched <= 1'b0;
        end

        // Reset이 아니면 RX Frame 완료 상태를 LED 표시용으로 저장함.
        else begin
            // LED 표시 시간을 만들기 위해 Counter를 증가시킴.
            display_div <= display_div + 1'b1;

            // LF를 만나 Frame이 완료되면 마지막 데이터와 Frame 완료 상태를 저장함.
            if (line_frame_valid) begin
                display_last_data   <= line_last_data;
                frame_valid_latched <= 1'b1;
                display_div         <= 26'd0;
            end

            // 표시 시간이 지나면 Frame 완료 표시를 해제함.
            else if (display_div[25]) begin
                frame_valid_latched <= 1'b0;
            end

            // 그 외에는 현재 표시 상태를 유지함.
            else begin
                display_last_data   <= display_last_data;
                frame_valid_latched <= frame_valid_latched;
            end
        end
    end

    // =========================================================
    // 8. TX ASCII 증가 로직
    // =========================================================

    always @(posedge clk) begin
        // Reset이면 송신 문자를 'a'로 초기화하고 Write 요청을 해제함.
        if (reset) begin
            ascii_reg  <= 8'h61;
            tx_wr_en   <= 1'b0;
            tx_wr_data <= 8'd0;
        end

        // Reset이 아니면 버튼 Pulse에 따라 ASCII 문자를 TX FIFO에 넣음.
        else begin
            // tx_wr_en은 1클럭 Pulse로 사용하므로 기본값을 0으로 둠.
            tx_wr_en <= 1'b0;

            // 버튼 Pulse가 들어오고 TX FIFO가 가득 차지 않았으면 현재 문자를 저장함.
            if (btn_pulse && !tx_full) begin
                tx_wr_data <= ascii_reg;
                tx_wr_en   <= 1'b1;

                // 현재 문자가 'z'이면 다음 문자는 다시 'a'로 초기화함.
                if (ascii_reg == 8'h7A) begin
                    ascii_reg <= 8'h61;
                end

                // 현재 문자가 'z'가 아니면 다음 ASCII 문자로 증가함.
                else begin
                    ascii_reg <= ascii_reg + 1'b1;
                end
            end

            // 버튼 Pulse가 없거나 TX FIFO가 가득 차면 현재 문자값을 유지함.
            else begin
                ascii_reg <= ascii_reg;
            end
        end
    end

    // =========================================================
    // 9. LED 표시
    // =========================================================

    // LED0~LED7은 RX에서 마지막으로 수신한 실제 데이터 문자를 표시함.
    assign led[7:0] = display_last_data;

    // LED8은 RX Frame 완료 상태를 표시함.
    assign led[8] = frame_valid_latched;

    // LED9는 RX 문자열 수신 중 상태를 표시함.
    assign led[9] = line_receiving;

    // LED10은 RX Line Buffer Overflow 또는 Discarding 상태를 표시함.
    assign led[10] = line_overflow | line_discarding;

    // LED11은 TX FIFO Empty 상태를 표시함.
    assign led[11] = tx_empty;

    // LED12는 TX FIFO Full 상태를 표시함.
    assign led[12] = tx_full;

    // LED13은 TX FSM 송신 중 상태를 표시함.
    assign led[13] = tx_busy;

    // LED14는 TX FSM 송신 완료 Pulse를 표시함.
    assign led[14] = tx_done;

    // LED15는 RX 오류 상태를 표시함.
    assign led[15] = frame_error | overrun_error;

endmodule
