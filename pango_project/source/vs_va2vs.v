module vs_va2vs(


      input       clk,
	   input       rst_n,
		input       data,
		
		output      pos_edge,    //上升沿
		output      neg_edge,    //下降沿  
		output      data_edge,  //数据边沿
		
		output reg     [1:0]   D      
);
	
//设置两个寄存器，实现前后电平状态的寄存
//相当于对dat_i 打两拍

	always @(posedge clk or negedge rst_n)begin
	    if(rst_n == 1'b0)begin
	        D <= 2'b00;
	    end
	    else begin
	        D <= {D[0], data};  	//D[1]表示前一状态，D[0]表示后一状态（新数据） 
	    end
	end
	
//组合逻辑进行边沿检测

	assign  pos_edge = ~D[1] & D[0];
	assign  neg_edge = D[1] & ~D[0];
	assign  data_edge = pos_edge | neg_edge;
	
endmodule