module csr_regfile(
    input  wire        clk               ,  
    input  wire        rst_n             ,
    input  wire        mcycle_flag       ,         
    output reg         break_done        ,    
    //CSR<-->IFU
    output reg  [31:0] trap_pc           ,
    //CSR_IFU 握手
    input  wire        pc_ready          ,
    output reg         trap_valid        ,	    
    //EXU<-->CSR
    input  wire [2:0]  exu_csr_op        ,
    input  wire [31:0] exu_rs1           ,
    input  wire [31:0] exu_zimm          ,
    input  wire        ecall_flag        ,
    input  wire        break_flag        ,
    input  wire        mret_flag         ,
    input  wire [31:0] curr_pc           ,
    input  wire [31:0] csr_wr            ,
    input  wire        csr_wr_flag       ,
    input  wire        csr_rd_flag       ,
    input  wire [11:0] csr_addr          ,
    output reg  [31:0] csr_rd            ,     
    //EXU_CSR 握手 
    input  wire        ex_csr_valid      ,
    output reg         ex_csr_ready      ,
    //RVFI
    //mcycle 
    output reg  [63:0] csr_mcycle_wdata  , 
    output reg  [63:0] csr_mcycle_wmask  ,
    output reg  [63:0] csr_mcycle_rdata  ,
    output reg  [63:0] csr_mcycle_rmask  ,
    //mepc
    output reg  [31:0] csr_mepc_wdata    ,
    output reg  [31:0] csr_mepc_wmask    ,
    output reg  [31:0] csr_mepc_rdata    ,
    output reg  [31:0] csr_mepc_rmask      
     
);


/////////////////////////////状态机///////////////////////////////
localparam IDLE = 2'd0, TRAP_SEND = 2'd1; 
reg [1:0]  curr_state;
reg        ecall_flag_reg;
reg        break_flag_reg;
reg        mret_flag_reg;
reg [31:0] curr_pc_reg;
reg [2:0]  csr_op_reg;
reg [31:0] rs1_reg;
reg [31:0] zimm_reg;


always @(posedge clk or negedge rst_n)begin
	if(!rst_n)begin
                      trap_valid   <= 1'b0;    
                      ex_csr_ready <= 1'b1;
                      curr_state   <= IDLE;
                      break_done   <= 1'b0;
      	end
	else case(curr_state)
	     IDLE:begin
                  if(ex_csr_valid)begin
		      curr_state   <= TRAP_SEND;
	              trap_valid   <= 1'b1;
		      ex_csr_ready <= 1'b0;
		      break_done   <= 1'b0;
	          end
		  else begin
		      curr_state   <= IDLE;
	              trap_valid   <= 1'b0;
		      ex_csr_ready <= 1'b1;
		      break_done   <= 1'b0;
	          end	      
	     end
	     TRAP_SEND:begin 
	          if(pc_ready)begin
		      curr_state   <= IDLE;
		      trap_valid   <= 1'b0;
		      ex_csr_ready <= 1'b1;
		      break_done   <= break_flag_reg;
	          end    
		  else begin
		      curr_state   <= TRAP_SEND;
	              trap_valid   <= 1'b1;
		      ex_csr_ready <= 1'b0;
		      break_done   <= 1'b0;
	          end	      
	     end
	     default:begin
                      trap_valid   <= 1'b0;
	              ex_csr_ready <= 1'b1;
                      curr_state   <= IDLE;
		      break_done   <= 1'b0;
	     end
     endcase
end

always @(posedge clk or negedge rst_n)begin
	if(!rst_n)begin
            ecall_flag_reg <= 1'b0 ;
            break_flag_reg <= 1'b0 ;
            mret_flag_reg  <= 1'b0 ;
            curr_pc_reg    <= 32'b0;
	    csr_op_reg     <= 3'b0 ;
	    rs1_reg        <= 32'b0;
	    zimm_reg       <= 32'b0;
        end
	else if(ex_csr_valid&&ex_csr_ready)begin
            ecall_flag_reg <= ecall_flag;
            break_flag_reg <= break_flag;
            mret_flag_reg  <= mret_flag ;
            curr_pc_reg    <= curr_pc   ;
	    csr_op_reg     <= exu_csr_op;
	    rs1_reg        <= exu_rs1   ;
	    zimm_reg       <= exu_zimm  ;
        end
 	else if(trap_valid&&pc_ready)begin
            ecall_flag_reg <= 1'b0 ;
            break_flag_reg <= 1'b0 ;
            mret_flag_reg  <= 1'b0 ;
        end	
	
end

//////////////////////////////////////////////////////////////////

//定义csr地址
localparam MSTATUS   = 12'h300;
localparam MTVEC     = 12'h305;
localparam MSCRATCH  = 12'h340;
localparam MEPC      = 12'h341;
localparam MCAUSE    = 12'h342;
localparam MCYCLE    = 12'hb00;
localparam MCYCLEH   = 12'hb80;
localparam MVENDORID = 12'hf11;
localparam MARCHID   = 12'hf12;


reg [31:0] mstatus; 
reg [31:0] mepc;
reg [31:0] mcause;
reg [31:0] mcycle;
reg [31:0] mcycleh;
reg [31:0] mscratch;
reg [31:0] mtvec;
reg [31:0] mvendorid;
reg [31:0] marchid;
    
//初始化csr
initial begin
  mvendorid = 32'h79737978;
  marchid   = 32'h1234abcd;   
end

////////////////////////////////////////////////////////////////
////RVFI

//mcycle
always @(*)begin
       if(csr_wr_flag&&csr_addr==MCYCLE)
	      csr_mcycle_wmask = 64'h00000000ffffffff;
       else if(csr_wr_flag&&csr_addr==MCYCLEH)
	      csr_mcycle_wmask = 64'hffffffff00000000; 
       else
	      csr_mcycle_wmask = 64'h0;  
end

always @(*)begin
       if(csr_wr_flag&&csr_addr==MCYCLE)
	      csr_mcycle_wdata = {32'b0,csr_wr};
       else if(csr_wr_flag&&csr_addr==MCYCLEH)
	      csr_mcycle_wdata = {csr_wr,32'b0}; 
       else
	      csr_mcycle_wdata = 64'b0; 
end

always @(*)begin
       if(csr_rd_flag&&csr_addr==MCYCLE)
	      csr_mcycle_rmask = 64'h00000000ffffffff;
       else if(csr_rd_flag&&csr_addr==MCYCLEH)
	      csr_mcycle_rmask = 64'hffffffff00000000; 
       else
	      csr_mcycle_rmask = 64'h0; 
end

always @(*)begin
       if(csr_rd_flag&&csr_addr==MCYCLE)
	      csr_mcycle_rdata = {32'b0,mcycle}; 
       else if(csr_rd_flag&&csr_addr==MCYCLEH)
	      csr_mcycle_rdata = {mcycleh,32'b0};  
       else
	      csr_mcycle_rdata = 64'b0; 
end

//mepc

always @(*)begin
      if(ecall_flag_reg||break_flag_reg)
         csr_mepc_wdata = curr_pc_reg;
      else if(csr_wr_flag&&csr_addr==mepc)
	 csr_mepc_wdata = csr_wr;
      else
	 csr_mepc_wdata = 32'b0;   
end

always @(*)begin
      if(csr_wr_flag&&csr_addr==MEPC)
	  case(csr_op_reg) 
	       3'd0: csr_mepc_wmask = 32'hffffffff;
	       3'd1: csr_mepc_wmask = rs1_reg; 
	       3'd2: csr_mepc_wmask = 32'hffffffff;
	       3'd3: csr_mepc_wmask = zimm_reg;
	       3'd4: csr_mepc_wmask = rs1_reg;
	       3'd5: csr_mepc_wmask = zimm_reg;
               default:csr_mepc_wmask = 32'h0;
          endcase
      else
	 csr_mepc_wmask = 32'h0;     
end

always @(*)begin
      if(mret_flag_reg)
         csr_mepc_rdata = mepc;	      
      else if(csr_rd_flag&&csr_addr==MEPC) 	 
	 csr_mepc_rdata = mepc;
      else
	 csr_mepc_rdata = 32'b0;     
end

always @(*)begin
      if(mret_flag_reg||csr_rd_flag&&csr_addr==MEPC)
	 csr_mepc_rmask = 32'hffffffff;
      else
	 csr_mepc_rmask = 32'b0;     
end
/////////////////////////////////////////////////////////////////////



//csr_rd
always @(*)begin
     case(csr_addr)
        MSTATUS: csr_rd = mstatus;
          MTVEC: csr_rd = mtvec;
       MSCRATCH: csr_rd = mscratch;	
           MEPC: csr_rd = mepc;
	 MCAUSE: csr_rd = mcause; 
         MCYCLE: csr_rd = mcycle;
	MCYCLEH: csr_rd = mcycleh;
      MVENDORID: csr_rd = mvendorid;
        MARCHID: csr_rd = marchid;
        default: csr_rd = 32'hffffffff;	
     endcase
end

//trap_pc
always @(*)begin
   if(ecall_flag_reg||break_flag_reg)
        trap_pc = {mtvec[31:2],2'b0};	   
   else if(mret_flag_reg)
	trap_pc = mepc;
   else
	trap_pc = 32'h0;   
end

//mtvec
always @(posedge clk or negedge rst_n)begin
   if(!rst_n)
	mtvec <= 32'h0;
   else if(csr_wr_flag&&csr_addr==MTVEC)
	mtvec <= csr_wr;  
end



//mstatus
always @(posedge clk or negedge rst_n)begin
   if(!rst_n)
	mstatus <= 32'h0;   
   else if(ecall_flag_reg||break_flag_reg)//MPP=3,MPIE=0,MIE=0
	mstatus <= 32'h00001800;  
   else if(mret_flag_reg) //MPP=3,MPIE=1,MIE=0
	mstatus <= 32'h00001c00;
   else if(csr_wr_flag&&csr_addr==MSTATUS)
	mstatus <= csr_wr;   
end

//mepc
always @(posedge clk or negedge rst_n)begin
   if(!rst_n)
	mepc <= 32'h0;    
   else if(ecall_flag_reg||break_flag_reg)
	mepc <= curr_pc_reg;
   else if(csr_wr_flag&&csr_addr==MEPC)
	mepc <= csr_wr;   
end

//mcause
always @(posedge clk or negedge rst_n)begin
   if(!rst_n)
	mcause <= 32'h0;   
   else if(ecall_flag_reg)
	mcause <= 32'h0000000b; //异常号11,即M模式环境调用 
   else if(break_flag_reg)
	mcause <= 32'h00000003; //异常号3，break   
   else if(csr_wr_flag&&csr_addr==MCAUSE)
	mcause <= csr_wr;   
end

//mscratch
always @(posedge clk or negedge rst_n)begin
     if(!rst_n)
       mscratch <= 32'h0;	     
     else if(csr_wr_flag&&csr_addr==MSCRATCH)
       mscratch <= csr_wr;	   
end

//mcycle
always @(posedge clk or negedge rst_n)begin
     if(!rst_n)
         mcycle <= 32'h0;
     else if(csr_wr_flag&&csr_addr==MCYCLE)
	 mcycle <= csr_wr;
//     else if(mcycle_flag)
     else
	 mcycle <= mcycle + 32'h1;   
end

//mcycleh
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
	 mcycleh <= 32'h0;   
    else if(csr_wr_flag&&csr_addr==MCYCLEH)
	 mcycleh <= csr_wr;   
//    else if(mcycle_flag&&(&mcycle))
    else if(&mcycle)
	 mcycleh <= mcycleh + 32'h1;
end


endmodule
