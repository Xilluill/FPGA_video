module zmx_rotate(

    input video_a_clk    ,
    input video_a_en    ,     
    input  [31:0]video_a_data,
    input video_a_rst  ,

    input video_b_clk    ,
    input video_b_en    ,
    input [31:0]video_b_data,
    input video_b_rst  ,

    input video_c_clk    ,
    input video_c_en    ,
    input  [31:0]video_c_data,
    input video_c_rst  ,

    input video_d_clk    ,
    input video_d_en    ,
    input  [31:0]video_d_data,
    input video_d_rst  ,

    output video0_clk,
    output video0_en,
    output [31:0] video0_data,
    output video0_rst,

    output video1_clk,
    output video1_en,
    output  [31:0]video1_data,
    output video1_rst,

    output video2_clk,
    output video2_en,
    output  [31:0]video2_data,
    output video2_rst,

    output video3_clk,
    output video3_en,
    output  [31:0]video3_data,
    output video3_rst,

    input [3:0] key_in_ctl
    );

    assign video0_clk = (video_a_clk&key_in_ctl[0])|(video_d_clk&key_in_ctl[1])|(video_c_clk&key_in_ctl[2])|(video_b_clk&key_in_ctl[3]);
    assign video0_en = (video_a_en&key_in_ctl[0])|(video_d_en&key_in_ctl[1])|(video_c_en&key_in_ctl[2])|(video_b_en&key_in_ctl[3]);
    assign video0_data = (video_a_data&{32{key_in_ctl[0]}})|(video_d_data&{32{key_in_ctl[1]}})|(video_c_data&{32{key_in_ctl[2]}})|(video_b_data&{32{key_in_ctl[3]}});
    assign video0_rst = (video_a_rst&key_in_ctl[0])|(video_d_rst&key_in_ctl[1])|(video_c_rst&key_in_ctl[2])|(video_b_rst&key_in_ctl[3]);

    assign video1_clk = (video_b_clk&key_in_ctl[0])|(video_a_clk&key_in_ctl[1])|(video_d_clk&key_in_ctl[2])|(video_c_clk&key_in_ctl[3]);
    assign video1_en = (video_b_en&key_in_ctl[0])|(video_a_en&key_in_ctl[1])|(video_d_en&key_in_ctl[2])|(video_c_en&key_in_ctl[3]);
    assign video1_data = (video_b_data&{32{key_in_ctl[0]}})|(video_a_data&{32{key_in_ctl[1]}})|(video_d_data&{32{key_in_ctl[2]}})|(video_c_data&{32{key_in_ctl[3]}});
    assign video1_rst = (video_b_rst&key_in_ctl[0])|(video_a_rst&key_in_ctl[1])|(video_d_rst&key_in_ctl[2])|(video_c_rst&key_in_ctl[3]);

    assign video2_clk = (video_c_clk&key_in_ctl[0])|(video_b_clk&key_in_ctl[1])|(video_a_clk&key_in_ctl[2])|(video_d_clk&key_in_ctl[3]);
    assign video2_en = (video_c_en&key_in_ctl[0])|(video_b_en&key_in_ctl[1])|(video_a_en&key_in_ctl[2])|(video_d_en&key_in_ctl[3]);
    assign video2_data = (video_c_data&{32{key_in_ctl[0]}})|(video_b_data&{32{key_in_ctl[1]}})|(video_a_data&{32{key_in_ctl[2]}})|(video_d_data&{32{key_in_ctl[3]}});
    assign video2_rst = (video_c_rst&key_in_ctl[0])|(video_b_rst&key_in_ctl[1])|(video_a_rst&key_in_ctl[2])|(video_d_rst&key_in_ctl[3]);

    assign video3_clk = (video_d_clk&key_in_ctl[0])|(video_c_clk&key_in_ctl[1])|(video_b_clk&key_in_ctl[2])|(video_a_clk&key_in_ctl[3]);
    assign video3_en = (video_d_en&key_in_ctl[0])|(video_c_en&key_in_ctl[1])|(video_b_en&key_in_ctl[2])|(video_a_en&key_in_ctl[3]);
    assign video3_data = (video_d_data&{32{key_in_ctl[0]}})|(video_c_data&{32{key_in_ctl[1]}})|(video_b_data&{32{key_in_ctl[2]}})|(video_a_data&{32{key_in_ctl[3]}});
    assign video3_rst = (video_d_rst&key_in_ctl[0])|(video_c_rst&key_in_ctl[1])|(video_b_rst&key_in_ctl[2])|(video_a_rst&key_in_ctl[3]);

endmodule