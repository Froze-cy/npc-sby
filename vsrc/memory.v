module memory
#(
      parameter MEM_WIDTH = 8 ,
      parameter MEM_DEPTH = 16  
)
(
   input  wire        clk          ,
   input  wire        rst_n        ,  
   //IFU<-->memory
   input  wire        pc_addr_valid,
   input  wire [31:0] pc_addr      ,   
   output reg  [31:0] mem_inst     ,
   //LSU<-->memory 
   input  wire [31:0] mem_waddr    ,
   input  wire [31:0] mem_wdata    ,
   input  wire        mem_wen      ,
   input  wire [3:0]  mem_wmask    ,   
   input  wire [31:0] mem_raddr    ,
   input  wire        mem_ren      ,
   input  wire [3:0]  mem_rmask    ,
   output wire [3:0]  rdata_offset ,
   output reg  [31:0] mem_rdata    
);

localparam IMEM_START = 16'h0, IMEM_END = 16'h3FFF;
localparam DMEM_START = 16'h4000, DMEM_END = 16'h7FFF;

reg [MEM_WIDTH-1:0] memory [0:1<<MEM_DEPTH-1];

integer i;
initial begin
  $readmemh("/home/froze/ysyx-workbench/npc-sby/vsrc/test.hex",memory);
  for (i=0;i<10;i=i+1)
   $display("IMEM[%0d]=0x%08x",i,memory[i]);
end


//imem 0000H~3FFFH
wire [15:0] imem_addr = pc_addr[15:0];

always @(posedge clk or negedge rst_n)begin
   if(!rst_n)
	   mem_inst <= 32'b0;
   else if(pc_addr_valid&&imem_addr>(IMEM_END-3))
	   mem_inst <= 32'b0;
   else if(pc_addr_valid)
	   mem_inst <= {memory[imem_addr+3],memory[imem_addr+2],memory[imem_addr+1],memory[imem_addr]};
end

//data 4000H~7FFFH
wire [15:0] dmem_raddr   = {mem_raddr[15:2],2'b0};
assign      rdata_offset = mem_rmask << mem_raddr[1:0]; 
always @(posedge clk or negedge rst_n)begin
   if(!rst_n)
	mem_rdata <= 32'b0;   
   else if(mem_ren&&dmem_raddr<DMEM_START||mem_ren&&(dmem_raddr+3)>DMEM_END)
	mem_rdata <= 32'b0;   
   else if(mem_ren)  
      case(rdata_offset)	   
        4'b0001: mem_rdata <= {24'b0,memory[dmem_raddr]};	  
        4'b0010: mem_rdata <= {16'b0,memory[dmem_raddr+1],8'b0};
        4'b0100: mem_rdata <= {8'b0,memory[dmem_raddr+2],16'b0};
        4'b1000: mem_rdata <= {memory[dmem_raddr+3],24'b0};
        4'b0011: mem_rdata <= {16'b0,memory[dmem_raddr+1],memory[dmem_raddr]};
        4'b1100: mem_rdata <= {memory[dmem_raddr+3],memory[dmem_raddr+2],16'b0};
        4'b1111: mem_rdata <= {memory[dmem_raddr+3],memory[dmem_raddr+2],memory[dmem_raddr+1],memory[dmem_raddr]};
        default: mem_rdata <= 32'b0;
      endcase
end

wire [15:0] dmem_waddr   = {mem_waddr[15:2],2'b0};
wire [3:0]  wdata_offset = mem_wmask << mem_waddr[1:0];
always @(posedge clk)begin
   if(mem_wen&&dmem_waddr>=DMEM_START&&(dmem_waddr+3)<=DMEM_END)  
      case(wdata_offset)	   
        4'b0001: memory[dmem_waddr]   <= mem_wdata[7:0]; 
        4'b0010: memory[dmem_waddr+1] <= mem_wdata[7:0]; 
        4'b0100: memory[dmem_waddr+2] <= mem_wdata[7:0]; 
        4'b1000: memory[dmem_waddr+3] <= mem_wdata[7:0]; 
        4'b0011: {memory[dmem_waddr+1],memory[dmem_waddr]}   <= mem_wdata[15:0]; 
        4'b1100: {memory[dmem_waddr+3],memory[dmem_waddr+2]} <= mem_wdata[15:0]; 
        4'b1111: {memory[dmem_waddr+3],memory[dmem_waddr+2],memory[dmem_waddr+1],memory[dmem_waddr]} <= mem_wdata; 
        default: ;
    endcase      	   
end


endmodule
