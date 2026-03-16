module mem_pc
#(
      parameter MEM_WIDTH = 8 ,
      parameter MEM_DEPTH = 16  
)
(
   input  wire        clk          ,
   input  wire        rst_n        ,  
   input  wire [31:0] pc_addr      , 
   input  wire        pc_addr_valid,  
   output reg         mem_pc_ready ,
   output wire [31:0] inst   
);


reg [MEM_WIDTH-1:0] imem [0:1<<MEM_DEPTH-1];

integer i;

initial begin
  $readmemh("/home/froze/ysyx-workbench/npc-sby/vsrc/test.hex",imem);
  for (i=0;i<10;i=i+1)
   $display("IMEM[%0d]=0x%08x",i,imem[i]);
end

/////////////////////////状态机//////////////////////////////
localparam IDLE = 1'b0, MEM_RD = 1'b1;
reg curr_state;

always @(posedge clk or negedge rst_n)begin
       if(!rst_n)begin
            mem_pc_ready <= 1'b1;
            curr_state   <= IDLE;
       end
       else case(curr_state)
	       IDLE:begin
		       if(pc_addr_valid)begin
                          mem_pc_ready <= 1'b0;
                          curr_state   <= MEM_RD;
		       end
	       end
	       MEM_RD:begin
                          curr_state   <= IDLE;
		          mem_pc_ready <= 1'b1;       
	       end
	       default:begin
                          curr_state   <= IDLE;
                          mem_pc_ready <= 1'b0;
	       end
       endcase
end
//////////////////////////////////////////////////////////////

wire [15:0] imem_addr = pc_addr[15:0];


always @(posedge clk or negedge rst_n)begin
   if(!rst_n)
	   inst <= 32'b0;
   else if(mem_pc_ready&&pc_addr_valid)
	   inst <= {imem[imem_addr+3],imem[imem_addr+2],imem[imem_addr+1],imem[imem_addr]};
end


endmodule
