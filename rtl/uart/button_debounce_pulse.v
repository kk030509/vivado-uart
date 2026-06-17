`timescale 1ns / 1ps

// button_debounce_pulse.v
// Basys3 버튼 입력을 Clock에 동기화함.
// 버튼 채터링을 제거함.
// 안정적으로 눌린 순간에만 1클럭 Pulse를 생성함.

module button_debounce_pulse #(
    // 100 MHz 기준 약 20 ms 디바운스 시간임.
    parameter DEBOUNCE_LIMIT = 2000000
)(
    // Top에서 넘겨받는 100 MHz 시스템 Clock임.
    input  wire clk,

    // Top에서 넘겨받는 Active-high 동기 Reset임.
    input  wire rst,

    // Basys3 버튼에서 들어오는 비동기 입력임.
    input  wire btn_in,

    // 이 모듈이 생성하여 뒤단 로직으로 넘기는 1클럭 Pulse임.
    output reg  btn_pulse
);

    // 버튼 입력 1단 동기화 레지스터임.
    reg btn_meta;

    // 버튼 입력 2단 동기화 레지스터임.
    reg btn_sync;

    // 디바운스 후 안정된 버튼 상태임.
    reg btn_stable;

    // 이전 안정 상태 저장용 레지스터임.
    reg btn_stable_d;

    // 입력 변화가 유지된 시간을 세는 Counter임.
    reg [21:0] debounce_cnt;

    // 비동기 버튼 입력을 Clock 도메인으로 동기화함.
    always @(posedge clk) begin
        // Reset이면 동기화 레지스터를 초기화함.
        if (rst) begin
            btn_meta <= 1'b0;
            btn_sync <= 1'b0;
        end

        // Reset이 아니면 버튼 입력을 2단으로 동기화함.
        else begin
            btn_meta <= btn_in;
            btn_sync <= btn_meta;
        end
    end

    // 디바운스 처리와 1클럭 Pulse 생성을 수행함.
    always @(posedge clk) begin
        // Reset이면 버튼 상태와 Counter를 초기화함.
        if (rst) begin
            btn_stable    <= 1'b0;
            btn_stable_d  <= 1'b0;
            debounce_cnt  <= 22'd0;
            btn_pulse     <= 1'b0;
        end

        // Reset이 아니면 버튼 안정 상태를 판단함.
        else begin
            // btn_pulse는 1클럭 Pulse이므로 기본값을 0으로 둠.
            btn_pulse <= 1'b0;

            // 상승 에지 검출을 위해 이전 안정 상태를 저장함.
            btn_stable_d <= btn_stable;

            // 현재 동기화 입력이 기존 안정 상태와 같으면 변화가 없는 상태임.
            if (btn_sync == btn_stable) begin
                debounce_cnt <= 22'd0;
            end

            // 현재 동기화 입력이 기존 안정 상태와 다르면 변화가 발생한 상태임.
            else begin
                // 변화가 충분히 오래 유지되면 안정된 변화로 인정함.
                if (debounce_cnt == DEBOUNCE_LIMIT - 1) begin
                    debounce_cnt <= 22'd0;
                    btn_stable   <= btn_sync;
                end

                // 안정 시간에 도달하지 않았으면 Counter를 증가함.
                else begin
                    debounce_cnt <= debounce_cnt + 1'b1;
                end
            end

            // 안정 상태가 0에서 1로 바뀌면 버튼 눌림으로 판단함.
            if ((btn_stable == 1'b1) && (btn_stable_d == 1'b0)) begin
                btn_pulse <= 1'b1;
            end
        end
    end

endmodule
