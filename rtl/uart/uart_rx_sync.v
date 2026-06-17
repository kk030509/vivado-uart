module uart_rx_sync(
    input  clk,
    input  reset,
    input  rx_async,
    output rx_sync
);

    // 외부 비동기 UART RX 입력을 1차로 받는 Register
    reg rx_meta_reg;

    // UART RX FSM에서 사용할 동기화된 RX Register
    reg rx_sync_reg;

    always @(posedge clk) begin
        // Reset 시 UART Idle 상태인 1로 초기화함
        if (reset) begin
            rx_meta_reg <= 1'b1;
            rx_sync_reg <= 1'b1;
        end

        // Reset이 아니면 2단 FF 동기화를 수행함
        else begin
            rx_meta_reg <= rx_async;
            rx_sync_reg <= rx_meta_reg;
        end
    end

    assign rx_sync = rx_sync_reg;

endmodule
