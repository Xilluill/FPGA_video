`timescale 1ns/1ns
module yuv_rgb
(
    //global clock
    input               clk,                //cmos video pixel clock
    input               rst_n,              //global reset

    //Image data prepred to be processed
    input               per_img_vsync,      //Prepared Image data vsync valid signal
    input               per_img_href,       //Prepared Image data href vaild signal
    input               per_img_deo,
    input       [7:0]   per_img_y,        //Prepared Image red data to be processed
    input       [7:0]   per_img_u,      //Prepared Image green data to be processed
    input       [7:0]   per_img_v,       //Prepared Image blue data to be processed
    
    input       [2:0]   y_ctl,
    input       [2:0]   u_ctl,
    input       [2:0]   v_ctl,
    //Image data has been processed
    output              post_img_vsync,     //Processed Image data vsync valid signal
    output              post_img_href,      //Processed Image data href vaild signal
    output               post_img_deo,
    output      [7:0]   post_img_r,         //Processed Image brightness output
    output      [7:0]   post_img_g,        //Processed Image blue shading output
    output      [7:0]   post_img_b         //Processed Image red shading output
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
**********************************************/

/*
R = Y + 1.4075 * V;  
G = Y - 0.3455 * U - 0.7169*V;  
B = Y + 1.779 * U;  

R = Y + (360* V)>>8;  
G = Y (- 88 * U - 184*V)>>8;  
B = Y + (455 * U)>>8;  

R= Y + ((360 * (V - 128))>>8) ; 
G= Y - (( ( 88 * (U - 128)  + 184 * (V - 128)) )>>8) ; 
B= Y +((455 * (U - 128))>>8) ;
*/

///魔改2.0
/*
R = Y + 1.402(Cr-128) 
G = Y - 0.34414(Cb-128) - 0.71414(Cr-128) 
B = Y + 1.772(Cb-128)

R = Y + 1437(Cr-128) >>10
G = Y (- 352(Cb-128) - 731(Cr-128) )>>10
B = Y + 1815(Cb-128)>>10
*/
//
//Step 1
reg signed[31:0] img_y_r0;
reg signed[31:0]  img_v_r0,   img_v_r1;
reg signed[31:0]  img_u_r0, img_u_r1; 
always@(posedge clk)
begin
    img_y_r0   <= (per_img_y+y_ctl*8'd16+8'd5)*12'd1024;                                         img_v_r0   <= (per_img_v+v_ctl*8'd16-8'd128)   * 11'd1437;  
                            img_u_r0 <= (per_img_u+u_ctl*8'd16-8'd128) * 11'd352; img_v_r1   <= (per_img_v+v_ctl*8'd16-8'd128)   * 11'd731;  
                            img_u_r1 <= (per_img_u+u_ctl*8'd16-8'd128) * 11'd1815;//u_ctl*8'd16
end

//--------------------------------------------------
//Step 2
reg signed[31:0]  img_r_r0;   
reg signed[31:0]  img_g_r0; 
reg signed[31:0]  img_b_r0; 
always@(posedge clk)
begin
    img_r_r0  <= img_y_r0+ img_v_r0;
    img_g_r0 <= img_y_r0- img_u_r0 - img_v_r1;
    img_b_r0  <= img_y_r0+img_u_r1;
end


//--------------------------------------------------
//Step 3
reg [7:0] img_r_r1; 
reg [7:0] img_g_r1; 
reg [7:0] img_b_r1; 
always@(posedge clk)
begin
  //  img_r_r1  <= img_r_r0[31:10];
    // img_g_r1 <=img_g_r0[31:10];
     //img_b_r1  <=img_b_r0[31:10]; 
    if (img_r_r0>18'd261120)
        img_r_r1<=8'd255;
    else if (img_r_r0<8'd0)
        img_r_r1<=8'b0;
    else
        img_r_r1<=img_r_r0[31:10];
    
    if (img_g_r0>18'd261120)
        img_g_r1<=8'd255;
    else if (img_g_r0<8'd0)
        img_g_r1<=8'b0;
    else
        img_g_r1<=img_g_r0[31:10];

    if (img_b_r0>18'd261120)
        img_b_r1<=8'd255;
    else if (img_b_r0<8'd0)
        img_b_r1<=8'b0;
    else
        img_b_r1<=img_b_r0[31:10];



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
// assign  post_img_Y     = post_img_deo ? img_Y_r1 : 8'd0;
// assign  post_img_Cb    = post_img_deo ? img_Cb_r1: 8'd0;
// assign  post_img_Cr    = post_img_deo ? img_Cr_r1: 8'd0;\
assign  post_img_r     = post_img_deo ? img_r_r1 : 8'd0;
assign  post_img_g    = post_img_deo ? img_g_r1: 8'd0;
assign  post_img_b    = post_img_deo ? img_b_r1: 8'd0;


endmodule
