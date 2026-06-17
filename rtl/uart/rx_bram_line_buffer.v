module rx_bram_line_buffer(
    // 기존 앞단에서 연결: Basys3 100 MHz 시스템 Clock
    input        clk,

    // 기존 앞단에서 연결: btnU Reset을 Top에서 변환하여 연결
    input        reset,

    // 기존 앞단에서 연결: uart_rx_core 내부 FIFO에서 나온 현재 Byte
    input  [7:0] rx_data,

    // 기존 앞단에서 연결: uart_rx_core 내부 FIFO에 읽을 데이터가 있음을 표시
    input        rx_valid,

    // 새롭게 추가: BRAM Line Buffer가 FIFO에서 1Byte를 읽겠다는 요청
    output       rx_ready,

    // 새롭게 추가: 마지막으로 저장한 실제 데이터 문자
    output [7:0] last_data,

    // 새롭게 추가: LF 감지 후 Frame 완료를 알리는 1Clock Pulse
    output       frame_valid,

    // 새롭게 추가: LF를 제외한 문자열 길이
    output [6:0] frame_length,

    // 새롭게 추가: 문자열 수신 중 상태
    output       receiving,

    // 새롭게 추가: BRAM Buffer Overflow 상태
    output       overflow,

    // 새롭게 추가: Overflow 이후 LF까지 데이터를 버리는 상태
    output       discarding
);

    // 새롭게 추가: 교육용 BRAM Line Buffer 깊이
    // 64Byte = 문자 64개 저장 가능
    parameter BRAM_DEPTH = 64;

    // 새롭게 추가: 64개 주소를 표현하기 위한 주소 폭
    parameter ADDR_WIDTH = 6;

    // 새롭게 추가: Line Ending 기준 문자
    // LF는 0x0A이며 문자열 끝을 의미함
    localparam LF = 8'h0A;

    // 새롭게 추가: BRAM_DEPTH 값을 frame_length 폭에 맞게 표현함
    localparam [ADDR_WIDTH:0] FRAME_MAX_LEN = BRAM_DEPTH;

    // 새롭게 추가: BRAM으로 추론될 수 있는 저장 공간
    // Vivado 합성 시 작은 메모리는 LUT RAM으로 잡힐 수도 있음
    // 개념상 BRAM Line Buffer 구조로 사용함
    (* ram_style = "block" *) reg [7:0] bram_mem [0:BRAM_DEPTH-1];

    // 새롭게 추가: 다음 문자를 저장할 BRAM Write Address
    reg [ADDR_WIDTH-1:0] wr_addr;

    // 새롭게 추가: 마지막으로 저장한 실제 데이터 문자
    reg [7:0] last_data_reg;

    // 새롭게 추가: Frame 완료를 알리는 1Clock Pulse
    reg frame_valid_reg;

    // 새롭게 추가: LF를 제외한 문자열 길이
    reg [ADDR_WIDTH:0] frame_length_reg;

    // 새롭게 추가: 문자열 수신 중 상태 표시
    reg receiving_reg;

    // 새롭게 추가: BRAM Buffer Overflow 상태
    reg overflow_reg;

    // 새롭게 추가: Overflow 이후 LF가 들어올 때까지 데이터를 버리는 상태
    reg discarding_reg;

    // 새롭게 추가: 현재 단계에서는 BRAM Line Buffer가 항상 FIFO를 읽을 준비가 되어 있음
    // rx_valid가 1이면 FIFO Read 요청을 발생시킴
    assign rx_ready = rx_valid;

    always @(posedge clk) begin

        // Reset이 들어오면 BRAM Line Buffer 상태를 초기화함
        if (reset) begin
            wr_addr          <= {ADDR_WIDTH{1'b0}};
            last_data_reg    <= 8'd0;
            frame_valid_reg  <= 1'b0;
            frame_length_reg <= {(ADDR_WIDTH+1){1'b0}};
            receiving_reg    <= 1'b0;
            overflow_reg     <= 1'b0;
            discarding_reg   <= 1'b0;
        end

        // Reset이 아니면 FIFO에서 나온 Byte를 처리함
        else begin

            // frame_valid는 1Clock Pulse이므로 매 Clock 기본값을 0으로 둠
            frame_valid_reg <= 1'b0;

            // FIFO에 읽을 데이터가 있을 때만 처리함
            if (rx_valid) begin

                // Overflow 이후 버림 상태이면 LF가 나올 때까지 데이터를 저장하지 않음
                if (discarding_reg) begin

                    // 버림 상태에서 LF를 만나면 긴 Frame을 종료하고 다음 Frame을 준비함
                    if (rx_data == LF) begin
                        frame_valid_reg  <= 1'b1;
                        frame_length_reg <= FRAME_MAX_LEN;
                        wr_addr          <= {ADDR_WIDTH{1'b0}};
                        receiving_reg    <= 1'b0;
                        discarding_reg   <= 1'b0;
                    end

                    // 버림 상태에서 LF가 아니면 계속 데이터를 버림
                    else begin
                        wr_addr        <= wr_addr;
                        receiving_reg  <= receiving_reg;
                        overflow_reg   <= overflow_reg;
                        discarding_reg <= discarding_reg;
                    end
                end

                // 버림 상태가 아니고 수신 Byte가 LF이면 정상 Frame 완료로 판단함
                else if (rx_data == LF) begin
                    frame_valid_reg  <= 1'b1;
                    frame_length_reg <= {1'b0, wr_addr};
                    wr_addr          <= {ADDR_WIDTH{1'b0}};
                    receiving_reg    <= 1'b0;
                end

                // 버림 상태가 아니고 LF가 아니면 실제 데이터 문자로 저장함
                else begin
                    receiving_reg <= 1'b1;
                    last_data_reg <= rx_data;

                    // BRAM 공간이 남아 있으면 현재 Byte를 저장함
                    if (wr_addr < BRAM_DEPTH - 1) begin
                        bram_mem[wr_addr] <= rx_data;
                        wr_addr <= wr_addr + 1'b1;
                    end

                    // 마지막 주소에도 저장한 뒤 Buffer가 가득 찬 상태로 처리함
                    else begin
                        bram_mem[wr_addr] <= rx_data;
                        overflow_reg      <= 1'b1;
                        discarding_reg    <= 1'b1;
                    end
                end
            end

            // FIFO에 읽을 데이터가 없으면 현재 상태를 유지함
            else begin
                wr_addr          <= wr_addr;
                last_data_reg    <= last_data_reg;
                frame_length_reg <= frame_length_reg;
                receiving_reg    <= receiving_reg;
                overflow_reg     <= overflow_reg;
                discarding_reg   <= discarding_reg;
            end
        end
    end

    // 새롭게 추가: 마지막 실제 데이터 문자 출력
    assign last_data = last_data_reg;

    // 새롭게 추가: Frame 완료 Pulse 출력
    assign frame_valid = frame_valid_reg;

    // 새롭게 추가: Frame 길이 출력
    assign frame_length = frame_length_reg;

    // 새롭게 추가: 수신 중 상태 출력
    assign receiving = receiving_reg;

    // 새롭게 추가: Overflow 상태 출력
    assign overflow = overflow_reg;

    // 새롭게 추가: 버림 상태 출력
    assign discarding = discarding_reg;

endmodule
