/*-----------------------------------------------------------------------
                                 \\\|///
                               \\  - -  //
                                (  @ @  )
+-----------------------------oOOo-(_)-oOOo-----------------------------+
CONFIDENTIAL IN CONFIDENCE
This confidential and proprietary software may be only used as authorized
by a licensing agreement from CrazyBingo (Thereturnofbingo).
In the event of publication, the following notice is applicable:
Copyright (C) 2011-20xx CrazyBingo Corporation
The entire notice above must be reproduced on all authorized copies.
Author              :       CrazyBingo
Technology blogs    :       www.crazyfpga.com
Email Address       :       crazyfpga@qq.com
Filename            :       RGB2YCbCr_Convert.v
Date                :       2013-05-26
Description         :       Convert the RGB888 format to YCbCr444 format.
Modification History    :
Date            By          Version         Change Description
=========================================================================
13/05/26        CrazyBingo  1.0             Original
14/03/16        CrazyBingo  2.0             Modification
-------------------------------------------------------------------------
|                                     Oooo                              |
+-------------------------------oooO--(   )-----------------------------+
                               (   )   ) /
                                \ (   (_/
                                 \_)
-----------------------------------------------------------------------*/ 

`timescale 1ns/1ns
module VIP_RGB888_YCbCr444
(
    //global clock
    input               clk,                //cmos video pixel clock
    input               rst_n,              //global reset

    //Image data prepred to be processed
    input               per_img_vsync,      //Prepared Image data vsync valid signal
    input               per_img_href,       //Prepared Image data href vaild signal
    input               per_img_deo,
    input       [7:0]   per_img_red,        //Prepared Image red data to be processed
    input       [7:0]   per_img_green,      //Prepared Image green data to be processed
    input       [7:0]   per_img_blue,       //Prepared Image blue data to be processed
    
    //Image data has been processed
    output              post_img_vsync,     //Processed Image data vsync valid signal
    output              post_img_href,      //Processed Image data href vaild signal
    output               post_img_deo,
    output      [7:0]   post_img_Y,         //Processed Image brightness output
    output      [7:0]   post_img_Cb,        //Processed Image blue shading output
    output      [7:0]   post_img_Cr         //Processed Image red shading output
);

//--------------------------------------------
/*********************************************
//Refer to full/pc range YCbCr format
    Y   =  R*0.299 + G*0.587 + B*0.114
    Cb  = -R*0.169 - G*0.331 + B*0.5   + 128
    Cr  =  R*0.5   - G*0.419 - B*0.081 + 128
--->      
    Y   = (76 *R + 150*G + 29 *B)>>8
    Cb  = (-43*R - 84 *G + 128*B + 32768)>>8
    Cr  = (128*R - 107*G - 20 *B + 32768)>>8

    Y   = (306 *R + 601*G + 117 *B)>>10
    Cb  = (-173*R - 339 *G + 512*B )>>10+128
    Cr  = (512*R - 429*G - 83 *B )>>10+128
**********************************************/

/*魔改2.0
　　　　R = Y  + 1.140*V
　　　　G = Y - 0.394*U - 0.581*V
　　　　B = Y + 2.032*U


R = Y + 1.402(Cr-128) 
G = Y - 0.34414(Cb-128) - 0.71414(Cr-128) 
B = Y + 1.772(Cb-128)
*/
//Step 1
reg [31:0]  img_red_r0,   img_red_r1,   img_red_r2; 
reg [31:0]  img_green_r0, img_green_r1, img_green_r2; 
reg [31:0]  img_blue_r0,  img_blue_r1,  img_blue_r2; 
always@(posedge clk)
begin
    img_red_r0   <= per_img_red   * 10'd306;img_green_r0 <= per_img_green * 10'd601;img_blue_r0  <= per_img_blue  * 10'd117;
    img_red_r1   <= per_img_red   * 10'd173; img_green_r1 <= per_img_green * 10'd339;img_blue_r1  <= per_img_blue  * 10'd512;
    img_red_r2   <= per_img_red   * 10'd512;img_green_r2 <= per_img_green * 10'd429;img_blue_r2  <= per_img_blue  * 10'd83;
end

//--------------------------------------------------
//Step 2
reg signed[31:0]  img_Y_r0;   
reg signed[31:0]  img_Cb_r0; 
reg signed[31:0]  img_Cr_r0; 
always@(posedge clk)
begin
    img_Y_r0  <= img_red_r0  + img_green_r0 + img_blue_r0;
    img_Cb_r0 <= img_blue_r1 - img_red_r1   - img_green_r1+18'd131072 ;
    img_Cr_r0 <= img_red_r2  - img_green_r2 - img_blue_r2+18'd131072  ;
end


//--------------------------------------------------
//Step 3
reg [7:0] img_Y_r1; 
reg [7:0] img_Cb_r1; 
reg [7:0] img_Cr_r1; 
always@(posedge clk)
begin
    // img_Y_r1  <= img_Y_r0[31:10];
    // img_Cb_r1 <= img_Cb_r0[31:10];
    // img_Cr_r1 <= img_Cr_r0[31:10]; 
    if (img_Y_r0 > 18'd261120)
        img_Y_r1 <= 8'd255;
    else if (img_Y_r0 < 18'd0)
        img_Y_r1 <= 8'b0;
    else
        img_Y_r1 <= img_Y_r0[31:10];

    if (img_Cb_r0 > 18'd261120)
        img_Cb_r1 <= 8'd255;
    else if (img_Cb_r0 < 18'd0)
        img_Cb_r1 <= 8'b0;
    else
        img_Cb_r1 <= img_Cb_r0[31:10];

    if (img_Cr_r0 > 18'd261120)
        img_Cr_r1 <= 8'd255;
    else if (img_Cr_r0 < 18'd0)
        img_Cr_r1 <= 8'b0;
    else
        img_Cr_r1 <= img_Cr_r0[31:10];
end

//------------------------------------------
//lag 3 clocks signal sync  
reg [2:0] per_img_vsync_r;
reg [2:0] per_img_href_r;   
reg [2:0]   per_img_deo_r;
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        begin
        per_img_vsync_r <= 0;
        per_img_href_r <= 0;
        end
    else
        begin
        per_img_vsync_r <=  {per_img_vsync_r[1:0],  per_img_vsync};
        per_img_href_r  <=  {per_img_href_r[1:0],   per_img_href};
        per_img_deo_r  <=  {per_img_deo_r[1:0],   per_img_deo};
        end
end
assign  post_img_vsync = per_img_vsync_r[2];
assign  post_img_href  = per_img_href_r[2];
assign  post_img_deo  = per_img_deo_r[2];
assign  post_img_Y     = post_img_deo ? img_Y_r1 : 8'd0;
assign  post_img_Cb    = post_img_deo ? img_Cb_r1: 8'd0;
assign  post_img_Cr    = post_img_deo ? img_Cr_r1: 8'd0;


endmodule
