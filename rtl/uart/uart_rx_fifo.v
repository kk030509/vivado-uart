module uart_rx_fifo(
    input        clk,
    input        reset,
    input        clear,

    input        wr_en,
    input  [7:0] wr_data,

    input        rd_en,
    output [7:0] rd_data,

    output       empty,
    output       full,
    output       valid,
    output       overrun_error
);

    // FIFO 저장 깊이
    parameter FIFO_DEPTH = 16;

    // 16개 주소 표현용 주소 폭
    parameter ADDR_WIDTH = 4;

    // FIFO 저장 공간
    reg [7:0] mem [0:FIFO_DEPTH-1];

    // 다음 Write 위치 Pointer
    reg [ADDR_WIDTH-1:0] wr_ptr;

    // 다음 Read 위치 Pointer
    reg [ADDR_WIDTH-1:0] rd_ptr;

    // FIFO 내부 데이터 개수
    reg [ADDR_WIDTH:0] count;

    // FIFO Full 상태에서 Write가 발생한 이력
    reg overrun_reg;

    // 실제 Write 가능 조건
    wire write_ok;

    // 실제 Read 가능 조건
    wire read_ok;

    assign empty = (count == 0);
    assign full  = (count == FIFO_DEPTH);
    assign valid = !empty;

    assign write_ok = wr_en && !full;
    assign read_ok  = rd_en && !empty;

    // Fall-through 방식 출력
    assign rd_data = mem[rd_ptr];

    always @(posedge clk) begin
        // Reset 또는 Clear 시 FIFO 상태를 초기화함
        if (reset || clear) begin
            wr_ptr      <= {ADDR_WIDTH{1'b0}};
            rd_ptr      <= {ADDR_WIDTH{1'b0}};
            count       <= {(ADDR_WIDTH+1){1'b0}};
            overrun_reg <= 1'b0;
        end

        // Reset이 아니면 Write/Read를 처리함
        else begin
            // Full 상태에서 Write 요청이 오면 Overrun을 저장함
            if (wr_en && full) begin
                overrun_reg <= 1'b1;
            end

            // Overrun은 Reset 또는 Clear 전까지 유지함
            else begin
                overrun_reg <= overrun_reg;
            end

            // Write 가능하면 현재 wr_ptr 위치에 저장함
            if (write_ok) begin
                mem[wr_ptr] <= wr_data;
                wr_ptr      <= wr_ptr + 1'b1;
            end

            // Read 가능하면 rd_ptr을 다음 위치로 이동함
            if (read_ok) begin
                rd_ptr <= rd_ptr + 1'b1;
            end

            // Write만 발생하면 count를 증가함
            if (write_ok && !read_ok) begin
                count <= count + 1'b1;
            end

            // Read만 발생하면 count를 감소함
            else if (!write_ok && read_ok) begin
                count <= count - 1'b1;
            end

            // Write/Read 동시 또는 둘 다 없으면 count를 유지함
            else begin
                count <= count;
            end
        end
    end

    assign overrun_error = overrun_reg;

endmodule
