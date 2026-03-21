module regfile
(
    input  wire         clk         ,     
    input  wire [4:0]   rs1_addr    ,  
    input  wire [4:0]   rs2_addr    ,  
    input  wire [4:0]   rd_wr_addr  ,   
    input  wire         reg_we      ,  
    input  wire [31:0]  wr_data     ,      
    output wire [31:0]  rs1         ,  
    output wire [31:0]  rs2         ,
    //debug
    input  wire [4:0]   debug_addr  ,
    output wire [31:0]  debug_reg   ,	    
    output wire [4:0]   rf_rd_addr  ,
    output wire [31:0]  rf_rd_data  
);

reg [31:0] registers [31:0] ;

integer i ;
initial begin
 for (i=0;i<32;i=i+1)
       registers[i] = 32'h0;	 
end

assign rs1 = (rs1_addr==0) ? 32'h0:registers[rs1_addr];
assign rs2 = (rs2_addr==0) ? 32'h0:registers[rs2_addr];
assign debug_reg = (debug_addr==0) ? 32'h0:registers[debug_addr];
assign rf_rd_addr = rd_wr_addr;
assign rf_rd_data = (rf_rd_addr==0) ? 32'h0:registers[rf_rd_addr];

always @(posedge clk)begin
	if(reg_we&&rd_wr_addr!=0)begin
        	registers[rd_wr_addr] <= wr_data ;   
	end
end      
	  


endmodule
