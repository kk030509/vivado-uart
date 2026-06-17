module uart_baud_tick_gen(
    input  clk,
    input  reset,
    output tick
);

    // 100 MHz / (9600 bps × 16) = 약 651
    parameter CLKS_PER_SAMPLE = 651;

    // Sample Tick 생성을 위한 Counter
    reg [15:0] count_reg;

    // 1Clock 폭의 Tick 출력 Register
    reg tick_reg;

    always @(posedge clk) begin
        // Reset 시 Counter와 Tick을 초기화함
        if (reset) begin
            count_reg <= 16'd0;
            tick_reg  <= 1'b0;
        end

        // 지정된 Clock 수에 도달하면 Tick을 1Clock 발생함
        else if (count_reg == CLKS_PER_SAMPLE - 1) begin
            count_reg <= 16'd0;
            tick_reg  <= 1'b1;
        end

        // 아직 Tick 시점이 아니면 Counter만 증가함
        else begin
            count_reg <= count_reg + 1'b1;
            tick_reg  <= 1'b0;
        end
    end

    assign tick = tick_reg;

endmodule
