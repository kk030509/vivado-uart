`timescale 1ns / 1ps

// uart_tx_fifo.v
// UART TX 송신 대기 데이터를 저장하는 FIFO임.
// 앞단 uart_tx_core에서 wr_en과 wr_data를 받아 데이터를 저장함.
// 뒤단 uart_tx_sender가 rd_en을 발생시키면 저장된 데이터를 1Byte씩 내보냄.

module uart_tx_fifo(
    // uart_tx_core에서 넘겨받는 100 MHz 시스템 Clock임.
    input  wire       clk,

    // uart_tx_core에서 넘겨받는 Active-high 동기 Reset임.
    input  wire       reset,

    // uart_tx_core 앞단 로직에서 넘어온 FIFO Write 요청임.
    input  wire       wr_en,

    // uart_tx_core 앞단 로직에서 넘어온 FIFO Write 데이터임.
    input  wire [7:0] wr_data,

    // 뒤단 uart_tx_sender에서 넘어오는 FIFO Read 요청임.
    input  wire       rd_en,

    // FIFO가 뒤단 uart_tx_sender로 넘기는 Read 데이터임.
    output wire [7:0] rd_data,

    // FIFO가 가득 찼을 때 1이 되는 상태 신호임.
    output wire       full,

    // FIFO가 비어 있을 때 1이 되는 상태 신호임.
    output wire       empty,

    // FIFO에 저장된 데이터 개수임.
    output wire [4:0] count
);

    // 8비트 데이터 16개를 저장하는 FIFO 메모리임.
    reg [7:0] mem [0:15];

    // 다음 Write 위치를 가리키는 포인터임.
    reg [3:0] wr_ptr;

    // 다음 Read 위치를 가리키는 포인터임.
    reg [3:0] rd_ptr;

    // FIFO에 현재 저장된 데이터 개수임.
    reg [4:0] count_reg;

    // 현재 Read Pointer 위치의 데이터를 출력함.
    assign rd_data = mem[rd_ptr];

    // 저장 개수를 출력함.
    assign count = count_reg;

    // 저장 개수가 16이면 Full임.
    assign full = (count_reg == 5'd16);

    // 저장 개수가 0이면 Empty임.
    assign empty = (count_reg == 5'd0);

    always @(posedge clk) begin
        // Reset이면 FIFO 내부 상태를 초기화함.
        if (reset) begin
            wr_ptr    <= 4'd0;
            rd_ptr    <= 4'd0;
            count_reg <= 5'd0;
        end

        // Reset이 아니면 Write와 Read 요청을 처리함.
        else begin
            // Write는 full이 아닐 때만 허용함.
            // Read는 empty가 아닐 때만 허용함.
            case ({wr_en && !full, rd_en && !empty})

                // Write만 수행함.
                // wr_data를 현재 wr_ptr 위치에 저장함.
                // wr_ptr과 count_reg를 증가시킴.
                2'b10: begin
                    mem[wr_ptr] <= wr_data;
                    wr_ptr      <= wr_ptr + 1'b1;
                    count_reg   <= count_reg + 1'b1;
                end

                // Read만 수행함.
                // rd_data는 현재 rd_ptr 위치의 값을 출력함.
                // rd_ptr을 증가시키고 count_reg를 감소시킴.
                2'b01: begin
                    rd_ptr    <= rd_ptr + 1'b1;
                    count_reg <= count_reg - 1'b1;
                end

                // Write와 Read를 동시에 수행함.
                // 하나가 들어오고 하나가 나가므로 count_reg는 유지함.
                2'b11: begin
                    mem[wr_ptr] <= wr_data;
                    wr_ptr      <= wr_ptr + 1'b1;
                    rd_ptr      <= rd_ptr + 1'b1;
                    count_reg   <= count_reg;
                end

                // Write도 Read도 없으면 현재 상태를 유지함.
                default: begin
                    wr_ptr    <= wr_ptr;
                    rd_ptr    <= rd_ptr;
                    count_reg <= count_reg;
                end
            endcase
        end
    end

endmodule
