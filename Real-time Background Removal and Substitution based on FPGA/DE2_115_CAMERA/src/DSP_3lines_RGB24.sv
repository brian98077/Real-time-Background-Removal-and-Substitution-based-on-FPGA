module DSP (
    input clk,
    input rst_n, 
    input i_en,                  // from Data_Process: after all lines ready, i_en is set to 1, and kept
    input [24*3-1:0] in_line_c,  // original image, 3 datas with RGB from 3 lines (0:23 top lines ~ 48:71 bottom lines) (RGB888)
    input  [7:0] i_back_gray,
    output [7:0] o_curr_dwt,
    input i_req,                 // from Data_Process: request mask for VGA
    output o_mask,               // to Data_Process: 1 bit mask per pixel
    input VS_negedge,            // 1 : frame change
    output [31:0] final_threshold
);

    // parameter
    parameter S_IDLE    = 0;
    parameter S_DATA_IN = 1;
    parameter S_OP_1    = 2;
    parameter S_OP_2    = 3;
    parameter S_OP_3    = 4;

    parameter width  = 800;
    parameter height = 600;

    // declaration
    integer i, j, k;
    logic [2:0] state_r, state_w;
    logic [2:0] data_in_counter_r, data_in_counter_w;
    logic [7:0] in_curr [0:2];
    logic [7:0] curr_data [0:5]; // 3 x 3 current data
    logic [10:0] sum1, sum2, sum3, sum4;
    logic [10:0] mean1, mean2, mean3, mean4;
    logic [8:0]  curr_dwt;
    logic [31:0] threshold_r, threshold_w, prev_threshold;
    logic [7:0]  sub_result; // |image - background|
    logic [19:0] threshold_counter_r, threshold_counter_w;
    logic [15:0] error;

    // wire assignment
    assign o_curr_dwt = curr_dwt;
    assign sub_result = (curr_dwt >= i_back_gray) ? curr_dwt - i_back_gray : i_back_gray - curr_dwt;
    assign error = (i_back_gray >= curr_dwt) ? (i_back_gray - curr_dwt) : (curr_dwt - i_back_gray);
	assign final_threshold = prev_threshold + 32'd24;

    // RGB to GRAY [Gray = (R*38 + G*75 + B*15) >> 7]
    assign in_curr[0] =  (in_line_c[23:16] * 38 + in_line_c[15:8]  * 75 + in_line_c[7:0]   * 15) >> 7;
    assign in_curr[1] =  (in_line_c[47:40] * 38 + in_line_c[39:32] * 75 + in_line_c[31:24] * 15) >> 7;
    assign in_curr[2] =  (in_line_c[71:64] * 38 + in_line_c[63:56] * 75 + in_line_c[55:48] * 15) >> 7;

    // mean filter
    assign sum1 = in_curr[0] + in_curr[1] + curr_data[0] + curr_data[1];
    assign sum2 = in_curr[1] + in_curr[2] + curr_data[1] + curr_data[2];
    assign sum3 = curr_data[0] + curr_data[1] + curr_data[3] + curr_data[4];
    assign sum4 = curr_data[1] + curr_data[2] + curr_data[4] + curr_data[5];
    assign mean1 = (sum1 >> 2);
    assign mean2 = (sum2 >> 2);
    assign mean3 = (sum3 >> 2);
    assign mean4 = (sum4 >> 2);

    // 2D dwt
    assign curr_dwt = (mean1 + mean2 + mean3 + mean4) >> 2;

    // FSM
    always_comb begin
        state_w = state_r;
        case (state_r)
            S_IDLE: begin
                if(i_en) state_w = S_DATA_IN;
                else     state_w = S_IDLE;
            end
            S_DATA_IN: begin
                if(data_in_counter_r == 3'd1) state_w = S_OP_1;
                else                          state_w = S_DATA_IN;
            end
        endcase
    end

    // data_in counter
    always_comb begin
        data_in_counter_w = data_in_counter_r;
        case (state_r)
            S_IDLE: begin
                if(i_en) data_in_counter_w = data_in_counter_r + 1;
            end
            S_DATA_IN: begin
                if(i_en) data_in_counter_w = data_in_counter_r + 1;
            end
        endcase
    end

    // input data FIFO (3*3)
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            for(i=0;i<6;i=i+1) begin
                curr_data[i] <= 8'd0;
            end
        end
        else begin
            for(i=0;i<6;i=i+1) begin
                curr_data[i] <= curr_data[i];
            end
            if(i_en) begin
                for(i=0;i<3;i=i+1) begin
                    curr_data[i] <= in_curr[i];
                end
                for(i=3;i<6;i=i+1) begin
                    curr_data[i] <= curr_data[i-3];
                end
            end
        end
    end

    // threshold counter
    always_comb begin
        threshold_counter_w = threshold_counter_r;
        case (state_r)
            S_OP_1: begin
                threshold_counter_w = (VS_negedge) ? 20'd0 :
                ((threshold_counter_r == width * (height - 2)) ? threshold_counter_r : threshold_counter_r + 1);
            end
        endcase
    end

    // threshold
    always_comb begin
        threshold_w = threshold_r;
        case (state_r)
            S_OP_1: begin
                threshold_w = (VS_negedge) ? 32'd0 :
                ((threshold_counter_r == width * (height - 2) - 1) ? (((threshold_r + error) * 11) >> 21) / 5 : //chang 21 to 2
                ((threshold_counter_r == width * (height - 2)) ? threshold_r : threshold_r + error));
            end
        endcase
    end

    // output mask
    assign o_mask = (sub_result >= final_threshold)? 1 : 0;

    // sequential
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state_r <= S_IDLE;
            data_in_counter_r <= 3'd0;
            threshold_r <= 32'd0;
            threshold_counter_r <= 20'd0;
            prev_threshold <= 32'd0;
        end
        else begin
            state_r <= state_w;
            data_in_counter_r <= data_in_counter_w;
            threshold_r <= threshold_w;
            threshold_counter_r <= threshold_counter_w;
            prev_threshold <= (VS_negedge) ? threshold_r : prev_threshold;
        end
    end
endmodule