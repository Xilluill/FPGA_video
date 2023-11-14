//************************************************
// Author       : Jack
// Create Date  : 2023年4月11日 16:34:01
// File Name    : video_stitching.v
// Version      : v1.0
// Target Device: PANGO PGL50H
// Function     : 
//************************************************

module video_stitching#(
    parameter SLAVE_ADDR            = 7'b0111100    , // 从器件的地址
    parameter CLK_FREQ              = 26'd50_000_000, // SCCB模块的时钟频率
    parameter SCCB_FREQ             = 18'd250_000   , // SCCB的驱动时钟频率

    parameter CAM_H_PIXEL           = 24'd960       , // 摄像头水平方向像素个数
    parameter CAM_V_PIXEL           = 24'd540       , // 摄像头垂直方向像素个数
    parameter HDMI_H_PIXEL          = 24'd960       , // 摄像头水平方向像素个数
    parameter HDMI_V_PIXEL          = 24'd540       , // 摄像头垂直方向像素个数
    parameter HDMI_RGB_R_WIDTH      = 8             ,
    parameter HDMI_RGB_G_WIDTH      = 8             ,
    parameter HDMI_RGB_B_WIDTH      = 8             ,

    parameter BOARD_MAC             = 48'h00_11_22_33_44_55         , //开发板MAC地址 00-11-22-33-44-55
    parameter BOARD_IP              = {8'd192, 8'd168, 8'd1, 8'd10} , //开发板IP地址 192.168.1.10
    parameter DES_MAC               = 48'hff_ff_ff_ff_ff_ff         , //目的MAC地址 ff_ff_ff_ff_ff_ff
    parameter DES_IP                = {8'd192, 8'd168, 8'd1, 8'd102}, //目的IP地址 192.168.1.102
    
    parameter CAM_DATA_WIDTH        = 16            ,
    parameter HDMI_DATA_WIDTH       = 24            ,
    parameter ETH_DATA_WIDTH        = 32            ,
    parameter FIFO_DATA_WIDTH       = 32            ,
    parameter MEM_ROW_WIDTH         = 15            ,
    parameter MEM_COL_WIDTH         = 10            ,
    parameter MEM_BANK_WIDTH        = 3             ,
    parameter MEM_DQ_WIDTH          = 32            ,
    parameter MEM_DM_WIDTH          = MEM_DQ_WIDTH/8,
    parameter MEM_DQS_WIDTH         = MEM_DQ_WIDTH/8,
    parameter MEM_BURST_LEN         = 8             ,
    parameter AXI_WRITE_BURST_LEN   = 8             , // 写突发传输长度，支持（1,2,4,8,16）
    parameter AXI_READ_BURST_LEN    = 16            , // 读突发传输长度，支持（1,2,4,8,16）
    parameter AXI_ID_WIDTH          = 4             ,
    parameter AXI_USER_WIDTH        = 1             ,
    
    parameter X_BITS    = 12        , // 行扫描周期位宽
    parameter Y_BITS    = 12        , // 场扫描周期位宽
    
    // 1920x1080@60 148.5MHz
    parameter H_SYNC    = 24'd44    , // 行同步
    parameter H_BACK    = 24'd148   , // 行显示后沿
    parameter H_DISP    = 24'd1920  , // 行有效数据
    parameter H_FRONT   = 24'd88    , // 行显示前沿
    parameter H_TOTAL   = 24'd2200  , // 行扫描周期
    
    parameter V_SYNC    = 24'd5     , // 场同步
    parameter V_BACK    = 24'd36    , // 场显示后沿
    parameter V_DISP    = 24'd1080  , // 场有效数据
    parameter V_FRONT   = 24'd4     , // 场显示前沿
    parameter V_TOTAL   = 24'd1125    // 场扫描周期
)(
    input   wire            sys_clk     ,
    input   wire            key_rst_n   ,
    
    // 摄像头接口
    input   wire            cam_pclk    , // 摄像头数据像素时钟
    input   wire            cam_vsync   , // 摄像头场同步信号
    input   wire            cam_href    , // 摄像头行同步信号
    input   wire    [ 7:0]  cam_data    , // 摄像头数据
    output  wire            cam_rst_n   , // 摄像头复位信号，低电平有效
    output  wire            cam_scl     , // 摄像头SCCB_SCL线
    inout   wire            cam_sda     , // 摄像头SCCB_SDA线
    

// 摄像头接口二号
    input   wire            cam_2_pclk    , // 摄像头数据像素时钟
    input   wire            cam_2_vsync   , // 摄像头场同步信号
    input   wire            cam_2_href    , // 摄像头行同步信号
    input   wire    [ 7:0]  cam_2_data    ,  /* synthesis syn_keep=1 */
    output  wire            cam_2_rst_n   , // 摄像头复位信号，低电平有效
    output  wire            cam_2_scl     , // 摄像头SCCB_SCL线
    inout   wire            cam_2_sda     , // 摄像头SCCB_SDA线


    // 以太网 RGMII 接口
    input   wire            eth_rxc         , // RGMII 接收数据时钟
    input   wire            eth_rx_ctl      , // RGMII 输入数据有效信号
    input   wire    [3:0]   eth_rxd         , // RGMII 输入数据
    output  wire            eth_txc         , // RGMII 发送数据时钟
    output  wire            eth_tx_ctl      , // RGMII 输出数据有效信号
    output  wire    [3:0]   eth_txd         , // RGMII 输出数据
    output  wire            eth_rst_n       , // 以太网芯片复位信号，低电平有效
    
    // HDMI 接口
    output  wire            hdmi_rst_n      , // HDMI输出芯片复位
    
    output  wire            hdmi_rx_scl     , // HDMI输入芯片SCL信号
    inout   wire            hdmi_rx_sda     , // HDMI输入芯片SDA信号
    input   wire            hdmi_rx_pix_clk , // HDMI输入芯片时钟
    input   wire            hdmi_rx_vs      , // HDMI输入场同步信号
    input   wire            hdmi_rx_hs      , // HDMI输入行同步信号
    input   wire            hdmi_rx_de      , // HDMI输入数据有效信号
    input   wire    [23:0]  hdmi_rx_data    , // HDMI输入数据
    
    output  wire            hdmi_tx_scl     , // HDMI输出芯片SCL信号
    inout   wire            hdmi_tx_sda     , // HDMI输出芯片SDA信号
    output  wire            hdmi_tx_pix_clk , // HDMI输出芯片时钟
    output  reg             hdmi_tx_vs      , // HDMI输出场同步信号
    output  reg             hdmi_tx_hs      , // HDMI输出行同步信号
    output  reg             hdmi_tx_de      , // HDMI输出数据有效信号
    output  reg     [23:0]  hdmi_tx_data    , // HDMI输出数据
    
    output                                  mem_rst_n       ,
    output                                  mem_ck          ,
    output                                  mem_ck_n        ,
    output                                  mem_cke         ,
    output                                  mem_cs_n        ,
    output                                  mem_ras_n       ,
    output                                  mem_cas_n       ,
    output                                  mem_we_n        ,
    output                                  mem_odt         ,
    output      [MEM_ROW_WIDTH-1:0]         mem_a           ,
    output      [MEM_BANK_WIDTH-1:0]        mem_ba          ,
    inout       [MEM_DQS_WIDTH-1:0]         mem_dqs         ,
    inout       [MEM_DQS_WIDTH-1:0]         mem_dqs_n       ,
    inout       [MEM_DQ_WIDTH-1:0]          mem_dq          ,
    output      [MEM_DM_WIDTH-1:0]          mem_dm          ,
    
    output  wire            led1        ,
    output  wire            led2        ,
    output  wire            led3        ,
    output  wire            led4        ,
    output  wire            led5        ,
    output  wire            led6        ,
    output  wire            led7        ,
    
    input [3:0]        key_in
);
/****************************wire****************************/
//cam 1
wire                            cam_init_done   ;
wire                            sys_init_done   ;
wire                            cam_frame_vsync ;
wire                            cam_frame_href  ;
wire                            cam_frame_valid ;
wire    [CAM_DATA_WIDTH-1:0]    cam_frame_data  ;
wire    [HDMI_RGB_R_WIDTH-1:0]  cam_data_r      ;
wire    [HDMI_RGB_G_WIDTH-1:0]  cam_data_g      ;
wire    [HDMI_RGB_B_WIDTH-1:0]  cam_data_b      ;

//cam 2
wire                            cam_2_init_done   ;
wire                            sys_2_init_done   ;
wire                            cam_2_frame_vsync ;
wire                            cam_2_frame_href  ;
wire                            cam_2_frame_valid ;
wire    [CAM_DATA_WIDTH-1:0]    cam_2_frame_data  ;
wire    [HDMI_RGB_R_WIDTH-1:0]  cam_2_data_r      ;
wire    [HDMI_RGB_G_WIDTH-1:0]  cam_2_data_g      ;
wire    [HDMI_RGB_B_WIDTH-1:0]  cam_2_data_b      ;

//eth
wire                            eth_rx_clk      ;
wire                            eth_frame_rst   ;
wire                            eth_frame_valid ;
wire    [ETH_DATA_WIDTH-1:0]    eth_frame_data  ;

wire                            ddr_init_done   ;
wire    [FIFO_DATA_WIDTH-1:0]   cam_wr_data     ;

wire    [FIFO_DATA_WIDTH-1:0]   cam_2_wr_data;
wire    [FIFO_DATA_WIDTH-1:0]   hdmi_wr_data    ;

wire                            pix_req         ;
wire    [FIFO_DATA_WIDTH-1:0]   fifo_rd_data    ;
wire    [HDMI_DATA_WIDTH-1:0]   pix_data        ;
wire                            hdmi_tx_init    ;
wire                            hdmi_rx_init    ;

wire                            fifo_video0_full;
wire                            fifo_video1_full;
wire                            fifo_o_full     ;

wire                            hdmi_frame_vs   ;
wire                            hdmi_frame_hs   ;
wire                            hdmi_frame_valid;
wire    [HDMI_DATA_WIDTH-1:0]   hdmi_frame_data ;


wire                            hdmi_frame_vs_2   ;
wire                            hdmi_frame_hs_2   ;
wire                            hdmi_frame_valid_2;
wire    [HDMI_DATA_WIDTH-1:0]   hdmi_frame_data_2 ;


wire                             post_img_vsync;
wire                             post_img_href;
wire                             [7:0] post_img_gray;

wire                            hdmi_tx_vs_temp ; // HDMI输出场同步信号
wire                            hdmi_tx_hs_temp ; // HDMI输出行同步信号
wire                            hdmi_tx_de_temp ; // HDMI输出数据有效信号
wire    [23:0]                  hdmi_tx_data_temp; // HDMI输出数据

wire                            hdmi_yuv_vs ; // HDMI输出场同步信号
wire                            hdmi_yuv_h ; // HDMI输出行同步信号
wire                            hdmi_yuv_deo ; // HDMI输出数据有效信号
wire    [23:0]                  hdmi_yuv_data; // HDMI输出数据

wire                            hdmi_rgb_vs ; // HDMI输出场同步信号
wire                            hdmi_rgb_h ; // HDMI输出行同步信号
wire                            hdmi_rgb_deo ; // HDMI输出数据有效信号
wire    [23:0]                  hdmi_rgb_data; // HDMI输出数据

reg                            hdmi_mux_vs ; // HDMI输出场同步信号
reg                            hdmi_mux_h ; // HDMI输出行同步信号
reg                            hdmi_mux_deo ; // HDMI输出数据有效信号
reg    [23:0]                  hdmi_mux_data; // HDMI输出数据

wire [2:0]key_1_out;
wire [2:0]key_2_out;
wire [2:0]key_3_out;
wire [2:0]key_4_out;

wire video1_clk;
wire video1_en;
wire [31:0]video1_data;
wire video1_rst;

wire video2_clk;
wire video2_en;
wire [31:0]video2_data;
wire video2_rst;

wire video3_clk;
wire video3_en;
wire [31:0]video3_data;
wire video3_rst;
/********************combinational logic*********************/
assign sys_init_done    = cam_2_init_done&&cam_init_done && ddr_init_done;
assign hdmi_tx_pix_clk  = hdmi_rx_pix_clk;

assign cam_data_r       = {cam_frame_data[15:11], cam_frame_data[13:11]};
assign cam_data_g       = {cam_frame_data[10: 5], cam_frame_data[ 6: 5]};
assign cam_data_b       = {cam_frame_data[ 4: 0], cam_frame_data[ 2: 0]};


assign cam_2_data_r       = {cam_2_frame_data[15:11], cam_2_frame_data[13:11]};
assign cam_2_data_g       = {cam_2_frame_data[10: 5], cam_2_frame_data[ 6: 5]};
assign cam_2_data_b       = {cam_2_frame_data[ 4: 0], cam_2_frame_data[ 2: 0]};

assign cam_wr_data      = {{(FIFO_DATA_WIDTH-HDMI_DATA_WIDTH){1'b0}}, cam_data_r, cam_data_g, cam_data_b};
assign cam_2_wr_data      = {{(FIFO_DATA_WIDTH-HDMI_DATA_WIDTH){1'b0}}, cam_2_data_r, cam_2_data_g, cam_2_data_b};



assign hdmi_wr_data     = {{(FIFO_DATA_WIDTH-HDMI_DATA_WIDTH){1'b0}}, hdmi_frame_data};

assign pix_data         = fifo_rd_data[HDMI_DATA_WIDTH-1:0];

assign led1 = cam_init_done     ;
assign led2 = ddr_init_done     ;
assign led3 = hdmi_tx_init      ;
assign led4 = hdmi_rx_init      ;
assign led5 = fifo_video0_full  ;
assign led6 = fifo_video1_full  ;
assign led7 = fifo_o_full       ;

/***********************instantiation************************/
Camera_top #(
    .SLAVE_ADDR             (SLAVE_ADDR         ), // 从器件的地址
    .CLK_FREQ               (CLK_FREQ           ), // SCCB模块的时钟频率
    .SCCB_FREQ              (SCCB_FREQ          ), // SCCB的驱动时钟频率
    .CAM_H_PIXEL            (CAM_H_PIXEL        ), // 摄像头水平方向像素个数
    .CAM_V_PIXEL            (CAM_V_PIXEL        )  // 摄像头垂直方向像素个数
)u_Camera_top(
    .sys_clk                (sys_clk            ), // input
    .sys_rst_n              (key_rst_n          ), // input
    .cam_init_done          (cam_init_done      ), // output 摄像头完成复位
    .sys_init_done          (sys_init_done      ), // input  DDR3和摄像头都完成复位
    
    .cam_pclk               (cam_pclk           ), // 摄像头数据像素时钟
    .cam_vsync              (cam_vsync          ), // 摄像头场同步信号
    .cam_href               (cam_href           ), // 摄像头行同步信号
    .cam_data               (cam_data           ), // 摄像头数据
    .cam_rst_n              (cam_rst_n          ), // 摄像头复位信号，低电平有效
    .cam_scl                (cam_scl            ), // 摄像头SCCB_SCL线
    .cam_sda                (cam_sda            ), // 摄像头SCCB_SDA线
    
    .cam_frame_vsync        (cam_frame_vsync    ), // output 帧有效信号
    .cam_frame_href         (cam_frame_href     ), // output 行有效信号
    .cam_frame_valid        (cam_frame_valid    ), // output 数据有效使能信号
    .cam_frame_data         (cam_frame_data     )  // output 有效数据
);
//2
Camera_top #(
    .SLAVE_ADDR             (SLAVE_ADDR         ), // 从器件的地址
    .CLK_FREQ               (CLK_FREQ           ), // SCCB模块的时钟频率
    .SCCB_FREQ              (SCCB_FREQ          ), // SCCB的驱动时钟频率
    .CAM_H_PIXEL            (CAM_H_PIXEL        ), // 摄像头水平方向像素个数
    .CAM_V_PIXEL            (CAM_V_PIXEL        )  // 摄像头垂直方向像素个数
)u_Camera_2_top(
    .sys_clk                (sys_clk            ), // input
    .sys_rst_n              (key_rst_n          ), // input
    .cam_init_done          (cam_2_init_done      ), // output 摄像头完成复位
    .sys_init_done          (sys_init_done      ), // input  DDR3和摄像头都完成复位
    
    .cam_pclk               (cam_2_pclk           ), // 摄像头数据像素时钟
    .cam_vsync              (cam_2_vsync          ), // 摄像头场同步信号
    .cam_href               (cam_2_href           ), // 摄像头行同步信号
    .cam_data               (cam_2_data           ), // 摄像头数据
    .cam_rst_n              (cam_2_rst_n          ), // 摄像头复位信号，低电平有效
    .cam_scl                (cam_2_scl            ), // 摄像头SCCB_SCL线
    .cam_sda                (cam_2_sda            ), // 摄像头SCCB_SDA线
    
    .cam_frame_vsync        (cam_2_frame_vsync    ), // output 帧有效信号
    .cam_frame_href         (cam_2_frame_href     ), // output 行有效信号
    .cam_frame_valid        (cam_2_frame_valid    ), // output 数据有效使能信号
    .cam_frame_data         (cam_2_frame_data     )  // output 有效数据
);

/*
Ethernet_top #(
    .BOARD_MAC              (BOARD_MAC          ), //开发板MAC地址 00-11-22-33-44-55
    .BOARD_IP               (BOARD_IP           ), //开发板IP地址 192.168.1.10
    .DES_MAC                (DES_MAC            ), //目的MAC地址 ff_ff_ff_ff_ff_ff
    .DES_IP                 (DES_IP             )  //目的IP地址 192.168.1.102
)u_Ethernet_top(
    .sys_clk                (sys_clk            ), // input  系统时钟
    .sys_rst_n              (key_rst_n          ), // input  系统复位信号，低电平有效

    //以太网RGMII接口
    .eth_rxc                (eth_rxc            ), // input  RGMII 接收数据时钟
    .eth_rx_ctl             (eth_rx_ctl         ), // input  RGMII 输入数据有效信号
    .eth_rxd                (eth_rxd            ), // input  RGMII 输入数据
    .eth_txc                (eth_txc            ), // output RGMII 发送数据时钟
    .eth_tx_ctl             (eth_tx_ctl         ), // output RGMII 输出数据有效信号
    .eth_txd                (eth_txd            ), // output RGMII 输出数据
    .eth_rst_n              (eth_rst_n          ), // output 以太网芯片复位信号，低电平有效

    .eth_rx_clk             (eth_rx_clk         ), // output 以太网接收数据时钟
    .eth_frame_valid        (eth_frame_valid    ), // output 以太网数据有效信号
    .eth_frame_data         (eth_frame_data     ), // output 以太网数据
    .eth_frame_rst          (eth_frame_rst      )  // output 以太网帧同步信号
);*/
DDR3_interface_top #(
    .FIFO_DATA_WIDTH        (FIFO_DATA_WIDTH    ), // FIFO 用户端数据位宽
    .CAM_H_PIXEL            (CAM_H_PIXEL        ), // CAMERA 行像素
    .CAM_V_PIXEL            (CAM_V_PIXEL        ), // CAMERA 列像素
    .HDMI_H_PIXEL           (HDMI_H_PIXEL       ), // HDMI 行像素
    .HDMI_V_PIXEL           (HDMI_V_PIXEL       ), // HDMI 列像素
    .DISP_H                 (H_DISP             ), // 显示的行像素
    .DISP_V                 (V_DISP             ), // 显示的列像素
    
    .MEM_ROW_WIDTH          (MEM_ROW_WIDTH      ), // DDR 行地址位宽
    .MEM_COL_WIDTH          (MEM_COL_WIDTH      ), // DDR 列地址位宽
    .MEM_BANK_WIDTH         (MEM_BANK_WIDTH     ), // DDR BANK地址位宽
    .MEM_BURST_LEN          (MEM_BURST_LEN      ), // DDR 突发传输长度
    
    .AXI_WRITE_BURST_LEN    (AXI_WRITE_BURST_LEN), // 写突发传输长度，支持（1,2,4,8,16）
    .AXI_READ_BURST_LEN     (AXI_READ_BURST_LEN ), // 读突发传输长度，支持（1,2,4,8,16）
    .AXI_ID_WIDTH           (AXI_ID_WIDTH       ), // AXI ID位宽
    .AXI_USER_WIDTH         (AXI_USER_WIDTH     )  // AXI USER位宽
)u_DDR3_interface_top(
    .sys_clk                (sys_clk            ), // input
    .key_rst_n              (key_rst_n          ), // input
    .ddr_init_done          (ddr_init_done      ), // output
    
    .video0_wr_clk          (cam_2_pclk           ), // input
    .video0_wr_en           (cam_2_frame_valid    ), // input
    .video0_wr_data         (cam_2_wr_data        ), // input
    .video0_wr_rst          (cam_2_frame_vsync    ), // input
    
    .video1_wr_clk          (cam_pclk           ), // input
    .video1_wr_en           (cam_frame_valid    ), // input
    .video1_wr_data         (cam_wr_data        ), // input
    .video1_wr_rst          (cam_frame_vsync    ), // input
    
    // .video1_wr_clk          (eth_rx_clk         ), // input
    // .video1_wr_en           (eth_frame_valid    ), // input
    // .video1_wr_data         (eth_frame_data     ), // input
    // .video1_wr_rst          (eth_frame_rst      ), // input

    .video2_wr_clk          (hdmi_rx_pix_clk    ), // input
    .video2_wr_en           (hdmi_frame_valid   ), // input
    .video2_wr_data         (hdmi_wr_data       ), // input
    .video2_wr_rst          (hdmi_frame_vs      ), // input

    /*.video3_wr_clk          (hdmi_rx_pix_clk    ), // input
    .video3_wr_en           (post_img_href   ), // input
    .video3_wr_data         ({8'd0,post_img_gray,8'd0,8'd0}       ), // input
    .video3_wr_rst          (post_out_vs      ), // input
    */
    .video3_wr_clk          (   hdmi_rx_pix_clk ), // input
    .video3_wr_en           ( hdmi_frame_valid  ), // input
    .video3_wr_data         (hdmi_wr_data   ), // input
    .video3_wr_rst          (  hdmi_frame_vs    ), // input

    .fifo_rd_clk            (hdmi_tx_pix_clk    ), // input
    .fifo_rd_en             (pix_req            ), // input
    .fifo_rd_data           (fifo_rd_data       ), // output
    .rd_rst                 (hdmi_tx_vs         ), // input
    
    .mem_rst_n              (mem_rst_n          ),
    .mem_ck                 (mem_ck             ),
    .mem_ck_n               (mem_ck_n           ),
    .mem_cke                (mem_cke            ),
    .mem_cs_n               (mem_cs_n           ),
    .mem_ras_n              (mem_ras_n          ),
    .mem_cas_n              (mem_cas_n          ),
    .mem_we_n               (mem_we_n           ),
    .mem_odt                (mem_odt            ),
    .mem_a                  (mem_a              ),
    .mem_ba                 (mem_ba             ),
    .mem_dqs                (mem_dqs            ),
    .mem_dqs_n              (mem_dqs_n          ),
    .mem_dq                 (mem_dq             ),
    .mem_dm                 (mem_dm             ),
    
    .fifo_video0_full       (fifo_video0_full   ),
    .fifo_video1_full       (fifo_video1_full   ),
    .fifo_o_full            (fifo_o_full        ),
    .key_ctl                   ()
);

HDMI_top #(
    .CLK_FREQ               (CLK_FREQ           ),
    
    .X_BITS                 (X_BITS             ), // 行扫描周期位宽
    .Y_BITS                 (Y_BITS             ), // 场扫描周期位宽
    
    .H_SYNC                 (H_SYNC             ), // 行同步
    .H_BACK                 (H_BACK             ), // 行显示后沿
    .H_DISP                 (H_DISP             ), // 行有效数据
    .H_FRONT                (H_FRONT            ), // 行显示前沿
    .H_TOTAL                (H_TOTAL            ), // 行扫描周期
    
    .V_SYNC                 (V_SYNC             ), // 场同步
    .V_BACK                 (V_BACK             ), // 场显示后沿
    .V_DISP                 (V_DISP             ), // 场有效数据
    .V_FRONT                (V_FRONT            ), // 场显示前沿
    .V_TOTAL                (V_TOTAL            )  // 场扫描周期
)u_HDMI_top(
    .sys_clk                (sys_clk            ), // input
    .hdmi_tx_pix_clk        (hdmi_tx_pix_clk    ), // input
    .sys_rst_n              (key_rst_n          ), // input
    .ddr_init_done          (ddr_init_done      ), // input
    .hdmi_rx_init           (hdmi_rx_init       ), // output
    .hdmi_tx_init           (hdmi_tx_init       ), // output
    .hdmi_rst_n             (hdmi_rst_n         ), // output
    
    .pix_req                (pix_req            ), // output 显示像素请求
    .pix_data               (pix_data           ), // input  显示像素数据
    
    .hdmi_rx_scl            (hdmi_rx_scl        ), // output
    .hdmi_rx_sda            (hdmi_rx_sda        ), // output
    
    .hdmi_tx_scl            (hdmi_tx_scl        ), // output
    .hdmi_tx_sda            (hdmi_tx_sda        ), // output
    .hdmi_tx_vs             (hdmi_tx_vs_temp    ), // output
    .hdmi_tx_hs             (hdmi_tx_hs_temp    ), // output
    .hdmi_tx_de             (hdmi_tx_de_temp    ), // output
    .hdmi_tx_data           (hdmi_tx_data_temp  )  // output
);

Video_processing_top #(
    .HDMI_DATA_WIDTH        (HDMI_DATA_WIDTH    ),
    .HDMI_RGB_R_WIDTH       (HDMI_RGB_R_WIDTH   ),
    .HDMI_RGB_G_WIDTH       (HDMI_RGB_G_WIDTH   ),
    .HDMI_RGB_B_WIDTH       (HDMI_RGB_B_WIDTH   ), 
    .HDMI_H_PIXEL           (H_DISP             ),
    .HDMI_V_PIXEL           (V_DISP             )
)u_Video_processing_top(
    .sys_clk                (sys_clk            ),
    .sys_rst_n              (key_rst_n          ),
    
    .hdmi_pix_clk           (hdmi_rx_pix_clk    ),
    .hdmi_vs                (hdmi_rx_vs         ),
    .hdmi_hs                (hdmi_rx_hs         ),
    .hdmi_de                (hdmi_rx_de         ),
    .hdmi_data              (hdmi_rx_data       ),
    
    .hdmi_frame_vs          (hdmi_frame_vs      ),
    .hdmi_frame_hs          (hdmi_frame_hs      ),
    .hdmi_frame_valid       (hdmi_frame_valid   ),
    .hdmi_frame_data        (hdmi_frame_data    )
);
key_Module key_inst (
	.clk(sys_clk),
	.rst_n(key_rst_n),
	.key_in(key_in),
	.key_1_out(key_1_out),
	.key_2_out(key_2_out),
	.key_3_out(key_3_out),
    .key_4_out(key_4_out)
);
/*
wire                            hdmi_ycr_vs ; // HDMI输出场同步信号
wire                            hdmi_ycr_h ; // HDMI输出行同步信号
wire                            hdmi_ycr_deo ; // HDMI输出数据有效信号
wire    [23:0]                  hdmi_ycr_data; // HDMI输出数据
*/

reg hdmi_rx_vs_r;
reg hdmi_rx_hs_r;
reg hdmi_rx_de_r;
reg [23:0] hdmi_rx_data_r;
always@(posedge hdmi_rx_pix_clk)
begin
    if(!key_rst_n)
        begin
            hdmi_rx_vs_r   <= 1'b0;
            hdmi_rx_hs_r   <= 1'b0;
            hdmi_rx_de_r   <= 1'b0;
            hdmi_rx_data_r <= 24'b0;
        end
    else
            hdmi_rx_vs_r   <= hdmi_rx_vs  ;
            hdmi_rx_hs_r   <= hdmi_rx_hs ;
            hdmi_rx_de_r   <= hdmi_rx_de ;
            hdmi_rx_data_r <= hdmi_rx_data;

        end
always @(*)begin
        case (key_1_out[0])
            1'b0: begin
            hdmi_mux_vs=hdmi_rx_vs_r;
            hdmi_mux_h=hdmi_rx_hs_r;
            hdmi_mux_deo=hdmi_rx_de_r;
            hdmi_mux_data=hdmi_rx_data_r;
            end
            1'b1: begin
            hdmi_mux_vs=hdmi_tx_vs_temp;
            hdmi_mux_h=hdmi_tx_hs_temp;
            hdmi_mux_deo=hdmi_tx_de_temp;
            hdmi_mux_data=hdmi_tx_data_temp;
            end
            default:begin
            hdmi_mux_vs=hdmi_rx_vs;
            hdmi_mux_h=hdmi_rx_hs;
            hdmi_mux_deo=hdmi_rx_de;
            hdmi_mux_data=hdmi_rx_data;
            end
        endcase
    end
VIP_RGB888_YCbCr444 vip_rgb888_ycbcr444_inst (
    .clk(hdmi_tx_pix_clk),
    .rst_n(key_rst_n),
    .per_img_vsync(hdmi_mux_vs),
    .per_img_href(hdmi_mux_h),
    .per_img_deo(hdmi_mux_deo),

    .per_img_red(hdmi_mux_data[23:16]),
    .per_img_green(hdmi_mux_data[15:8]),
    .per_img_blue(hdmi_mux_data[7:0]),

    .post_img_vsync(hdmi_yuv_vs),
    .post_img_href(hdmi_yuv_h),
    .post_img_deo(hdmi_yuv_deo),
    .post_img_Y(hdmi_yuv_data[23:16]),
    .post_img_Cb(hdmi_yuv_data[15:8]),
    .post_img_Cr(hdmi_yuv_data[7:0])
);

yuv_rgb yuv_rgb_inst (
    .clk(hdmi_tx_pix_clk),
    .rst_n(key_rst_n),

    
    .per_img_vsync(hdmi_yuv_vs),
    .per_img_href(hdmi_yuv_h),
    .per_img_deo(hdmi_yuv_deo),

    .per_img_y(hdmi_yuv_data[23:16]),
    .per_img_u(hdmi_yuv_data[15:8]),
    .per_img_v(hdmi_yuv_data[7:0]),
    

  /*  .per_img_vsync(hdmi_rx_vs),
    .per_img_href(hdmi_rx_hs),
    .per_img_deo(hdmi_rx_de),

    .per_img_y(hdmi_rx_data[23:16]),
    .per_img_u(hdmi_rx_data[15:8]),
    .per_img_v(hdmi_rx_data[7:0]),*/


    .post_img_vsync(hdmi_rgb_vs),
    .post_img_href(hdmi_rgb_h),
    .post_img_deo(hdmi_rgb_deo),
    .post_img_r(hdmi_rgb_data[23:16]),
    .post_img_g(hdmi_rgb_data[15:8]),
    .post_img_b(hdmi_rgb_data[7:0]),

    .y_ctl(key_2_out),
    .u_ctl(key_3_out),
    .v_ctl(key_4_out)
);
// .cam_frame_vsync        (cam_2_frame_vsync    ), // output 帧有效信号
//    .cam_frame_href         (cam_2_frame_href     ), // output 行有效信号
 //  .cam_frame_valid        (cam_2_frame_valid    ), // output 数据有效使能信号
 //   .cam_frame_data         (cam_2_frame_data     )  // output 有效数据
/*Video_processing_top #(
    .HDMI_DATA_WIDTH        (HDMI_DATA_WIDTH    ),
    .HDMI_RGB_R_WIDTH       (HDMI_RGB_R_WIDTH   ),
    .HDMI_RGB_G_WIDTH       (HDMI_RGB_G_WIDTH   ),
    .HDMI_RGB_B_WIDTH       (HDMI_RGB_B_WIDTH   ),
    .HDMI_H_PIXEL           (960            ),
    .HDMI_V_PIXEL           (540         )
)u_Video_processing_top_2(
    .sys_clk                (sys_clk            ),
    .sys_rst_n              (key_rst_n          ),
    
    .hdmi_pix_clk           (hdmi_rx_pix_clk    ),
    .hdmi_vs                (hdmi_frame_vs         ),
    .hdmi_hs                (hdmi_frame_hs         ),
    .hdmi_de                (hdmi_frame_valid         ),
    .hdmi_data              (hdmi_frame_data       ),
    
    .hdmi_frame_vs          (hdmi_frame_vs_2      ),
    .hdmi_frame_hs          (hdmi_frame_hs_2      ),
    .hdmi_frame_valid       (hdmi_frame_valid_2   ),
    .hdmi_frame_data        (hdmi_frame_data_2    )
);*/
//双线性插值缩放
//.video3_wr_clk          (hdmi_rx_pix_clk    ), // input
   // .video3_wr_en           (hdmi_frame_valid   ), // input
   // .video3_wr_data         (hdmi_wr_data       ), // input
  //  .video3_wr_rst          (hdmi_frame_vs      ), // input
/*bilinear_top #(
    .C_SRC_IMG_WIDTH(11'd960),//src 960x540
    .C_SRC_IMG_HEIGHT(11'd540),
    .C_DST_IMG_WIDTH(11'd960),//dst 480*270
    .C_DST_IMG_HEIGHT(11'd540),
    .C_X_RATIO(17'd65536),//  floor(C_SRC_IMG_WIDTH/C_DST_IMG_WIDTH*2^16)
    .C_Y_RATIO(17'd65536)//  floor(C_SRC_IMG_HEIGHT/C_DST_IMG_HEIGHT*2^16)
) bilinear_top_inst (
    .clk_in1(hdmi_rx_pix_clk),
    .clk_in2(hdmi_rx_pix_clk),
    .rst_n(key_rst_n),
    .per_img_vsync(~hdmi_frame_vs),
    .per_img_href(hdmi_frame_valid),
    .per_img_gray(8'b1111_1111),//只看红色的先
    .post_img_vsync(post_img_vsync),
    .post_img_href(post_img_href),
    .post_img_gray(post_img_gray)
);

wire post_out_vs;
vs_va2vs vs_inst(
	.clk(hdmi_rx_pix_clk),
	.rst_n(key_rst_n),
	.data(post_img_vsync),
	.pos_edge(post_out_vs),
	.neg_edge(),
	.data_edge()
);
*/
// 输出打一拍

always@(posedge hdmi_tx_pix_clk)
begin
    if(!hdmi_tx_init)
        begin
            hdmi_tx_vs   <= 1'b0;
            hdmi_tx_hs   <= 1'b0;
            hdmi_tx_de   <= 1'b0;
            hdmi_tx_data <=  'd0;
        end
    else
        // begin
        // if(key_1_out[0])begin

        //     hdmi_mux_vs   <= hdmi_tx_vs_temp  ;
        //     hdmi_mux_h   <= hdmi_tx_hs_temp  ;
        //     hdmi_mux_deo   <= hdmi_tx_de_temp  ;
        //     hdmi_mux_data <= hdmi_tx_data_temp;
        //     end
        // else begin
        //     hdmi_mux_vs   <= hdmi_rx_vs  ;
        //     hdmi_mux_h   <= hdmi_rx_hs  ;
        //     hdmi_mux_deo   <= hdmi_rx_de  ;
        //     hdmi_mux_data <= hdmi_rx_data;
        //  end
             hdmi_tx_vs   <= hdmi_rgb_vs  ;
            hdmi_tx_hs   <= hdmi_rgb_h ;
            hdmi_tx_de   <= hdmi_rgb_deo ;
            hdmi_tx_data <= hdmi_rgb_data;

        end

endmodule
