module Data_Process(
    input i_clk,
    input i_rst_n,

    input [9:0] i_RED_data_c, // from SDRAM current
    input [9:0] i_GREEN_data_c, 
    input [9:0] i_BLUE_data_c,
    input i_control_ready,
    input [7:0] i_control,

    output [4:0] state,

    output [19:0] o_SRAM_ADDR,
	inout  [15:0] io_SRAM_DQ,
	output        o_SRAM_WE_N,
	output        o_SRAM_CE_N,
	output        o_SRAM_OE_N,
	output        o_SRAM_LB_N,
	output        o_SRAM_UB_N,

    output logic o_SDRAM_read, // output to SDARM
    input i_VGA_request, // from VGA
    input i_VGA_V_sync,

    input [12:0] i_VGA_x,
    input [12:0] i_VGA_y,
    output logic [9:0] R_data_out,
    output logic [9:0] G_data_out,
    output logic [9:0] B_data_out,

    output [31:0] threshold
);
    `include "Data_Param_3.h"
    localparam  IDLE        = 5'd0,
                WAIT_BAC    = 5'd1,
                WAIT_1      = 5'd2,
                READ        = 5'd3,
                BLINK       = 5'd4,
                PROCESSING  = 5'd5;

    // display mode
    localparam D_ORIGIN = 0;
    localparam D_GREEN_MASK = 1;
    localparam D_REPLACED = 2;
    localparam D_MEAN = 3;
    localparam D_GREY = 4;
    localparam D_BACK = 5;

    localparam WAIT_CYCLE = 32'h1ffffff;
    localparam BLINK_TIME = 32'h1312D00;

    logic [23:0] pixel_in_c;
    logic [7:0] curr_grey, back_grey;
    //FSM
    logic [4:0] state_r, state_w;
    logic [31:0] wait_counter_r, wait_counter_w;
    logic [31:0] valid_counter_r, valid_counter_w;
    //SRAM
    logic [19:0] addr_record_r, addr_record_w;
    logic [19:0] addr_play_r, addr_play_w;
    //VGA
    logic prev_VS, VS_negedge;
    // line buffer for current and background
    logic [23:0] stream1_c_r [width-1:0]; //width = 800
    logic [23:0] stream2_c_r [width-1:0];
    logic [23:0] stream3_c_r [width-1:0];

    logic [23:0] stream1_c_w [width-1:0];
    logic [23:0] stream2_c_w [width-1:0];
    logic [23:0] stream3_c_w [width-1:0];


    logic [7:0]  delay_R_r [delay-1:0]; //delay = 5
    logic [7:0]  delay_G_r [delay-1:0];
    logic [7:0]  delay_B_r [delay-1:0];
    logic [7:0]  delay_R_w [delay-1:0];
    logic [7:0]  delay_G_w [delay-1:0];
    logic [7:0]  delay_B_w [delay-1:0];
    
    // pre-fetch
    localparam PREFETCH_NUM = width*prefetch_lines; //fetch prefetch_lines lines
    logic [19:0] prefetch_counter_r, prefetch_counter_w;
    logic shift_r, shift_w; // 1 for shifting, 0 for holding

    //DSP
    logic [16*4-1:0] DSP_line_c;
    logic        DSP_req;
    logic        DSP_mask;
    logic        DSP_en;
    logic [2:0]  DSP_state;
    logic [7:0]  curr_dwt;
    logic [31:0] prev_threshold;

    // display control
    logic [2:0] display_option;
    logic Capture, Recapture;
	integer i, j;

    // ROM data
    logic [9:0] ROM_R, ROM_G, ROM_B;

    //=========================================================================
    // DSP
    DSP n1(
        .clk(i_clk),
        .rst_n(i_rst_n),
        .i_en(DSP_en),
        .in_line_c(DSP_line_c),
        .i_back_gray(io_SRAM_DQ[7:0]),
        .o_curr_dwt(curr_dwt),
        .i_req(DSP_req),
        .o_mask(DSP_mask),
        .final_threshold(prev_threshold),
        .VS_negedge(VS_negedge)
    );
    // Control
    display_control u_display_control(
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_control_ready(i_control_ready),
        .i_control(i_control),
        .display_option(display_option),
        .Capture(Capture),
        .Recapture(Recapture)
    );
    ROM_Wrapper u_ROM_Wrapper(
        .addr_x(i_VGA_x),
        .addr_y(i_VGA_y),
        .i_VGA_request(i_VGA_request),
        .clk(i_clk),
        .o_red(ROM_R),
        .o_green(ROM_G),
        .o_blue(ROM_B)
    );

    //=========================================================================
    // wire assignment
    //DSP
    assign pixel_in_c = {i_RED_data_c[9:2], i_GREEN_data_c[9:2], i_BLUE_data_c[9:2]};   //RGB 888
    assign back_grey = (i_RED_data_c[9:2] * 38 + i_GREEN_data_c[9:2]* 75 + i_BLUE_data_c[9:2] * 15) >> 7;
    assign DSP_req = 0; //can be removed
    assign DSP_line_c  = {stream1_c_r[width-1], stream2_c_r[width-1], stream3_c_r[width-1]};
    assign curr_grey = (delay_R_r[(delay-1)] * 38 + (delay_G_r[(delay-1)]) * 75 + delay_B_r[(delay-1)]  * 15) >> 7; //RGB 888 to gray
    assign threshold = prev_threshold;

    //SRAM
    assign o_SRAM_ADDR = (state_r == READ) ? addr_record_r : addr_play_r;
    assign io_SRAM_DQ  = (state_r == READ) ? {8'b0, back_grey} : 16'dz; // sram_dq as output
    assign o_SRAM_WE_N = (state_r == READ) ? 1'b0 : 1'b1;
    assign o_SRAM_CE_N = 1'b0;
    assign o_SRAM_OE_N = 1'b0;
    assign o_SRAM_LB_N = 1'b0;
    assign o_SRAM_UB_N = 1'b0;

    assign state = state_r;
    assign VS_negedge = prev_VS && !i_VGA_V_sync;

    // state machine
    always_comb begin  
        state_w     = state_r;
        wait_counter_w = wait_counter_r;
        valid_counter_w = valid_counter_r;
        addr_record_w = addr_record_r;
        addr_play_w = addr_play_r;
        case(state_r)
            IDLE: begin
                if (valid_counter_r == WAIT_CYCLE) begin
                    state_w      = WAIT_BAC;
                end
                else begin
                    valid_counter_w = valid_counter_r + 1;
                    state_w = state_r;
                    wait_counter_w  = 0;
                end
            end
            WAIT_BAC: begin
                if (Capture)begin
                    state_w      = WAIT_1;
                end
                else begin
                    state_w = state_r;
                    wait_counter_w  = 0;
                end
            end
            WAIT_1: begin
                if(VS_negedge) begin
                    state_w      = READ;
                    addr_record_w = 0;
                end
                else begin
                    wait_counter_w  = 0;
                    state_w = state_r;
                end
            end
            READ: begin // read one image
                if (VS_negedge) begin
                    state_w = BLINK;
                end
                else begin
                    addr_record_w = (i_VGA_request) ? (i_VGA_y * width + i_VGA_x) : 0;
                    state_w = state_r;
                end
            end
            BLINK: begin
                if (wait_counter_r > BLINK_TIME) begin
                    state_w = (VS_negedge) ? PROCESSING: state_r;
                end
                else begin
                    wait_counter_w  = wait_counter_r + 1;
                end
            end
            PROCESSING: begin
                addr_play_w = (i_VGA_request) ? (i_VGA_y * width + i_VGA_x) : 0;
                if (Recapture)begin
                    state_w      = WAIT_BAC;
                end
            end
        endcase
    end

    always_comb begin
        DSP_en = 0;
        o_SDRAM_read = i_VGA_request;
        shift_w = shift_r;
        prefetch_counter_w = prefetch_counter_r;
        if (state_r == PROCESSING) begin
            if (prefetch_counter_r < PREFETCH_NUM) begin // prefetch before VGA ask
                o_SDRAM_read = 1;
                shift_w = 1;
                DSP_en = 0;
                prefetch_counter_w = prefetch_counter_r + 1;
            end
            else if (i_VGA_request) begin // if VGA request, then ask for SDRAM & shift FIFO
                o_SDRAM_read = 1;
                shift_w = 1;
                DSP_en = 1;
                prefetch_counter_w = prefetch_counter_r;
            end
            else begin // hold when not asked by VGA and not prefetching
                o_SDRAM_read = 0;
                shift_w = 0;
                DSP_en = 0;
                prefetch_counter_w = prefetch_counter_r;
            end
        end
    end



    // FIFO
    always_comb begin
        if (shift_r) begin // shift
            stream1_c_w[0] = pixel_in_c;
            stream2_c_w[0] = stream1_c_r[width-1];
            stream3_c_w[0] = stream2_c_r[width-1];


            for (j = 1; j <= (width - 1); j = j + 1) begin
                stream1_c_w[j] = stream1_c_r[j-1];
                stream2_c_w[j] = stream2_c_r[j-1];
                stream3_c_w[j] = stream3_c_r[j-1];


            end

            delay_R_w[0] = stream3_c_r[width-1][23:16];
            delay_G_w[0] = stream3_c_r[width-1][15:8];
            delay_B_w[0] = stream3_c_r[width-1][7:0];

            for (j = 1; j <= (delay- 1); j = j + 1) begin
                delay_R_w[j] = delay_R_r[j-1];
                delay_G_w[j] = delay_G_r[j-1];
                delay_B_w[j] = delay_B_r[j-1];
            end
        end
        else begin // hold
            for (j = 0; j <= (width - 1); j = j + 1) begin
                stream1_c_w[j] = stream1_c_r[j];
                stream2_c_w[j] = stream2_c_r[j];
                stream3_c_w[j] = stream3_c_r[j];
            end

            for (j = 0; j <= (delay - 1); j = j + 1) begin
                delay_R_w[j] = delay_R_r[j];
                delay_G_w[j] = delay_G_r[j];
                delay_B_w[j] = delay_B_r[j];
            end
        end
    end
    always_comb begin
        case (state_r)
            BLINK: begin
                R_data_out = 10'h3ff;
                G_data_out = 10'h3ff;
                B_data_out = 10'h3ff;
            end
            PROCESSING: begin
                case (display_option)
                    D_ORIGIN: begin // original display (camera)
                        R_data_out = {delay_R_r[(delay-1)], 2'b0};
                        G_data_out = {delay_G_r[(delay-1)], 2'b0};
                        B_data_out = {delay_B_r[(delay-1)], 2'b0};
                    end
                    D_GREEN_MASK: begin // mask
                    // each 10 bits
                        R_data_out = (DSP_mask) ? {delay_R_r[(delay-1)], 2'b0}: 10'd350;
                        G_data_out = (DSP_mask) ? {delay_G_r[(delay-1)], 2'b0}: 10'd1000;
                        B_data_out = (DSP_mask) ? {delay_B_r[(delay-1)], 2'b0}: 10'd400;
                    end
                    D_GREY: begin
                        R_data_out = {curr_grey};
                        G_data_out = {curr_grey};
                        B_data_out = {curr_grey};
                    end
                    D_MEAN: begin
                        R_data_out = {curr_dwt};
                        G_data_out = {curr_dwt};
                        B_data_out = {curr_dwt};
                    end
                    D_BACK: begin
                        R_data_out = {io_SRAM_DQ[7:0]};
                        G_data_out = {io_SRAM_DQ[7:0]};
                        B_data_out = {io_SRAM_DQ[7:0]};
                    end
                    D_REPLACED: begin
                        // TODO
                        R_data_out = (DSP_mask) ? {delay_R_r[(delay-1)], 2'b0}: ROM_R;
                        G_data_out = (DSP_mask) ? {delay_G_r[(delay-1)], 2'b0}: ROM_G;
                        B_data_out = (DSP_mask) ? {delay_B_r[(delay-1)], 2'b0}: ROM_B;
                    end

                    default: begin // default original
                        R_data_out = {delay_R_r[(delay-1)], 2'b0};
                        G_data_out = {delay_G_r[(delay-1)], 2'b0};
                        B_data_out = {delay_B_r[(delay-1)], 2'b0};
                    end
                endcase
            end
            default: begin
                R_data_out = i_RED_data_c;
                G_data_out = i_GREEN_data_c;
                B_data_out = i_BLUE_data_c;
            end
        endcase
        
    end


    // ---------------------------------------------------------------------------
    // Sequential Block
    always @(posedge i_clk or negedge i_rst_n) begin
        if(!i_rst_n) begin
            state_r     <= IDLE;
            valid_counter_r <= 0;
            addr_record_r <= 0;
            addr_play_r <= 0;
            prev_VS <= 0;
        end
        else begin
            valid_counter_r <= valid_counter_w;
            state_r     <= state_w;
            wait_counter_r <= wait_counter_w;
            addr_record_r <= addr_record_w;
            addr_play_r <= addr_play_w;
            prev_VS <= i_VGA_V_sync;
        end
    end

    always @(posedge i_clk or negedge i_rst_n) begin
        if(!i_rst_n) begin
            shift_r <= 0;
            prefetch_counter_r <= 0;
            for (i = 0; i <= (width-1); i = i + 1) begin
                stream1_c_r[i] <= 0;
                stream2_c_r[i] <= 0;
                stream3_c_r[i] <= 0;
            end
            for (i = 0; i <= (delay-1); i = i + 1) begin
                delay_R_r[i] <= 0;
                delay_G_r[i] <= 0;
                delay_B_r[i] <= 0;
            end
        end
        else begin
            shift_r <= shift_w;
            prefetch_counter_r <= prefetch_counter_w;
            for (i = 0; i <= (width-1); i = i + 1) begin
                stream1_c_r[i] <= stream1_c_w[i];
                stream2_c_r[i] <= stream2_c_w[i];
                stream3_c_r[i] <= stream3_c_w[i];
            end

            for (i = 0; i <= (delay-1); i = i + 1) begin
                delay_R_r[i] <= delay_R_w[i];
                delay_G_r[i] <= delay_G_w[i];
                delay_B_r[i] <= delay_B_w[i];
            end
        end
    end
endmodule


module display_control (
    input i_clk,
    input i_rst_n,
    input i_control_ready,
    input [7:0] i_control,

    output [2:0] display_option,
    output Capture, Recapture
);
    localparam IDLE = 3'b000, 
                WAIT = 3'b001, 
                OUTPUT = 3'b010;
    localparam D_ORIGIN = 0;
    localparam D_GREEN_MASK = 1;
    localparam D_REPLACED = 2;
    localparam D_MEAN = 3;
    localparam D_GREY = 4;
    localparam D_BACK = 5;
    logic [2:0] state_r, state_w;
    logic [2:0] display_option_r, display_option_w;
    logic Capture_r, Capture_w;
    logic Recapture_r, Recapture_w;
    logic [1:0] counter_r, counter_w;

    assign display_option = display_option_r;
    assign Capture = Capture_r;
    assign Recapture = Recapture_r;


    // state machine
    always_comb begin
        state_w = state_r;
        counter_w = counter_r;
        case (state_r)
            IDLE: begin
                    state_w = WAIT;
            end
            WAIT: begin
                counter_w = 0;
                if (i_control_ready) begin
                    state_w = OUTPUT;
                end
            end
            OUTPUT: begin
                if(counter_r == 3) begin
                    state_w = WAIT;
                end
                else begin
                    state_w = OUTPUT;
                    counter_w = counter_r + 1;
                end
            end
        endcase
    end
    // display option
    always_comb begin
        display_option_w = display_option_r;
        Capture_w = 0;
        Recapture_w = 0;
        if (state_r == OUTPUT) begin
            case (i_control)
                8'h0f: display_option_w = D_GREEN_MASK;
                8'h13: display_option_w = D_REPLACED;
                8'h10: display_option_w = D_ORIGIN;
                8'h01: display_option_w = D_MEAN;
                8'h02: display_option_w = D_GREY;
                8'h03: display_option_w = D_BACK;
                8'h12: Capture_w = 1;
                8'h16: Recapture_w = 1;
                default: display_option_w = D_ORIGIN; // origin
            endcase
        end
        else begin
            display_option_w = display_option_r;
            Capture_w = 0;
            Recapture_w = 0;
        end
    end

    // Sequential Block
    always @(posedge i_clk or negedge i_rst_n) begin
        if(!i_rst_n) begin
            state_r <= IDLE;
            display_option_r <= D_ORIGIN;
            Capture_r <= 0;
            Recapture_r <= 0;
        end
        else begin
            state_r <= state_w;
            display_option_r <= display_option_w;
            Capture_r <= Capture_w;
            Recapture_r <= Recapture_w;
        end
    end


endmodule