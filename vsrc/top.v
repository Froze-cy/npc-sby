module top
(
    input  wire        clk                   ,
    input  wire        rst_n                 , 
    output wire [31:0] curr_pc               ,
    output wire [31:0] inst                  ,
    //debug
    input  wire [4:0]  debug_addr            ,
    output wire [31:0] debug_reg             ,
    output wire        good_trap             ,
    output wire        bad_trap              , 
    output reg         diff_flag             ,
    //RVFI
    output reg         rvfi_valid            ,
    output reg  [63:0] rvfi_order            ,
    output wire [31:0] rvfi_insn             ,
    output reg         rvfi_trap             ,
    output wire [1:0]  rvfi_mode             ,
    output wire [1:0]  rvfi_ixl              ,  
    output reg  [4:0]  rvfi_rs1_addr         ,
    output reg  [4:0]  rvfi_rs2_addr         ,
    output reg  [31:0] rvfi_rs1_rdata        ,
    output reg  [31:0] rvfi_rs2_rdata        ,
    output wire [4:0]  rvfi_rd_addr          ,
    output wire [31:0] rvfi_rd_wdata         ,
    output reg  [31:0] rvfi_pc_rdata         ,
    output wire [31:0] rvfi_pc_wdata         ,
    output reg  [31:0] rvfi_mem_addr         ,
    output reg  [3:0]  rvfi_mem_rmask        ,
    output reg  [3:0]  rvfi_mem_wmask        ,
    output reg  [31:0] rvfi_mem_rdata        ,
    output reg  [31:0] rvfi_mem_wdata        ,    
    //RVFI_CSR
    //mcycle
    output reg  [63:0] rvfi_csr_mcycle_wdata ,
    output reg  [63:0] rvfi_csr_mcycle_wmask ,
    output reg  [63:0] rvfi_csr_mcycle_rdata ,
    output reg  [63:0] rvfi_csr_mcycle_rmask ,
    //mepc
    output reg  [31:0] rvfi_csr_mepc_wdata   ,
    output reg  [31:0] rvfi_csr_mepc_wmask   ,
    output reg  [31:0] rvfi_csr_mepc_rdata   ,
    output reg  [31:0] rvfi_csr_mepc_rmask   
);

//IFU
wire        if_id_valid    ;
wire        pc_ready       ;
wire        pc_addr_valid  ;
wire [31:0] pc_addr        ;

//IDU
wire        inst_exce      ;
wire        if_id_ready    ;
wire        idu_valid      ;
wire [4:0]  idu_rs1_addr   ;
wire [4:0]  idu_rs2_addr   ;
wire [4:0]  idu_rd_wr_addr ;  
wire [31:0] idu_imm        ;
wire [5:0]  idu_alu_op     ;
wire [4:0]  idu_zimm       ;
wire        idu_reg_we     ;
wire        idu_sign_type  ;
wire        idu_load_flag  ;
wire        idu_ecall_flag ;
wire        idu_mret_flag  ;
wire        idu_break_flag ;
wire        idu_jump_flag  ;
wire        idu_trap_flag  ;
wire        idu_lsu_flag   ;
wire [31:0] idu_curr_pc    ;
wire [11:0] idu_csr_addr   ;
wire        idu_csr_wr_flag;
wire        idu_csr_rd_flag;
wire        idu_mem_wen    ;
wire [3:0]  idu_mem_wmask  ;
wire        idu_mem_ren    ;
wire [3:0]  idu_mem_rmask  ;

//EXU
wire [2:0]  exu_csr_op     ;
wire [31:0] exu_zimm       ; 
wire        jump_exce      ;
wire [31:0] exu_rs1        ;
wire [31:0] exu_rs2        ;
wire        exu_done       ;
wire        exu_reg_done   ;
wire        jump_valid     ;
wire [31:0] jump_pc        ;
wire        ex_csr_valid   ;
wire        ex_ls_valid    ;
wire        exu_ready      ; 
wire        exu_break_flag ;
wire        exu_ecall_flag ; 
wire        exu_mret_flag  ; 
wire        exu_reg_we     ; 
wire [4:0]  exu_rd_addr    ;
wire        exu_load_flag  ;
wire        exu_csr_wr_flag;
wire        exu_csr_rd_flag;
wire [11:0] exu_csr_addr   ; 
wire [31:0] exu_curr_pc    ;
wire [31:0] exu_rd_wr      ;
wire [31:0] csr_wr         ;
wire        exu_sign_type  ;
wire [31:0] exu_mem_waddr  ;  
wire [31:0] exu_mem_wdata  ;
wire        exu_mem_wen    ;
wire [3:0]  exu_mem_wmask  ;
wire [31:0] exu_mem_raddr  ;
wire        exu_mem_ren    ;
wire [3:0]  exu_mem_rmask  ;

//LSU
wire        ex_ls_ready    ;
wire [31:0] lsu_mem_rdata  ;
wire        lsu_data_valid ;
wire [31:0] mem_waddr      ;      
wire [31:0] mem_wdata      ;
wire        mem_wen        ;
wire [3:0]  mem_wmask      ;
wire [31:0] mem_raddr      ;
wire        mem_ren        ;
wire [3:0]  mem_rmask      ;

//WBU
wire [31:0] wbu_wr_data    ;
wire        wbu_we         ;
wire [4:0]  wbu_wr_addr    ;

//regfile
wire [31:0] rs1            ;
wire [31:0] rs2            ;
wire [4:0]  rf_rd_addr     ;
wire [31:0] rf_rd_data     ;


//csr_regfile
wire        mcycle_flag     ;
wire        break_done      ;
wire        trap_valid      ;
wire [31:0] trap_pc         ;
wire        ex_csr_ready    ;
wire [31:0] csr_rd          ;
wire [63:0] csr_mcycle_wdata;
wire [63:0] csr_mcycle_wmask;
wire [63:0] csr_mcycle_rdata;
wire [63:0] csr_mcycle_rmask;                
wire [31:0] csr_mepc_wdata  ;
wire [31:0] csr_mepc_wmask  ;
wire [31:0] csr_mepc_rdata  ;
wire [31:0] csr_mepc_rmask  ;


//memory
wire        memory_exce     ;
wire [31:0] mem_inst        ;
wire [31:0] mem_rdata       ;
wire [3:0]  rdata_offset    ;
wire [3:0]  wdata_offset    ;
wire [31:0] rvfi_mem_waddr  ;
wire [31:0] rvfi_mem_raddr  ;
wire [31:0] rvfi_wdata_shift;
/////////////////////////////////////////////////////////////

assign good_trap   = break_done&&inst[31:20]==12'h1;
assign bad_trap    = break_done&&inst[31:20]==12'h2;
assign mcycle_flag = exu_done||jump_valid||trap_valid;

always @(posedge clk or negedge rst_n)begin
       if(!rst_n)
	      diff_flag <= 1'b0;
       else
	      diff_flag <= exu_done||jump_valid||trap_valid;
end

//RVFI
reg r_wbu_we;

always @(posedge clk or negedge rst_n)begin
       if(!rst_n)
	    r_wbu_we <= 1'b0;

       else 
	    r_wbu_we <= wbu_we;   
end

assign rvfi_insn     = inst;
assign rvfi_mode     = 2'b11;
assign rvfi_ixl      = 2'b01;
assign rvfi_rd_addr  = (r_wbu_we) ? rf_rd_addr : 5'b0 ;
assign rvfi_rd_wdata = (r_wbu_we) ? rf_rd_data : 32'b0;
assign rvfi_pc_wdata = curr_pc;


always @(posedge clk or negedge rst_n)begin
      if(!rst_n)
          rvfi_valid <= 1'b0;
/*      else if(rvfi_trap)
	  rvfi_valid <= 1'b0;  */  
      else
	  rvfi_valid <= exu_done||jump_valid||trap_valid;    
end

always @(posedge clk or negedge rst_n)begin
      if(!rst_n)
	  rvfi_trap <= 1'b0;
      else if(rvfi_valid)
	  rvfi_trap <= 1'b0;
      else
	  rvfi_trap <= inst_exce||memory_exce||jump_exce;    
end

always @(posedge clk or negedge rst_n)begin
      if(!rst_n)
	  rvfi_order <= 64'd0;    
      else if(rvfi_valid)
	  rvfi_order <= rvfi_order + 1;    
end

always @(posedge clk or negedge rst_n)begin
      if(!rst_n)begin
	 rvfi_mem_addr  <= 32'b0;
         rvfi_mem_rmask <= 4'b0 ;
         rvfi_mem_wmask <= 4'b0 ;
         rvfi_mem_rdata <= 32'b0;
	 rvfi_mem_wdata <= 32'b0;
      end
      else if(rvfi_valid)begin
	 rvfi_mem_addr  <= 32'b0;
         rvfi_mem_rmask <= 4'b0 ;
         rvfi_mem_wmask <= 4'b0 ;
         rvfi_mem_rdata <= 32'b0;
	 rvfi_mem_wdata <= 32'b0;
      end
      else if(mem_wen)begin 
         rvfi_mem_addr  <= rvfi_mem_waddr;
         rvfi_mem_wmask <= wdata_offset;
	 rvfi_mem_wdata <= rvfi_wdata_shift;
      end
      else if(mem_ren)begin
	 rvfi_mem_addr  <= rvfi_mem_raddr;
         rvfi_mem_rmask <= rdata_offset;
         rvfi_mem_rdata <= mem_rdata;
      end	 
end


always @(posedge clk or negedge rst_n)begin
      if(!rst_n) begin     
           rvfi_rs1_addr  <= 5'b0 ;
           rvfi_rs2_addr  <= 5'b0 ;
           rvfi_rs1_rdata <= 32'b0;
           rvfi_rs2_rdata <= 32'b0;
	   rvfi_pc_rdata  <= 32'b0;  
      end
      else begin
           rvfi_rs1_addr  <= idu_rs1_addr;
           rvfi_rs2_addr  <= idu_rs2_addr;
           rvfi_rs1_rdata <= exu_rs1;
           rvfi_rs2_rdata <= exu_rs2;
	   rvfi_pc_rdata  <= curr_pc;
      end
end

//RVFI_CSR
always @(posedge clk or negedge rst_n)begin
      if(!rst_n)begin
           rvfi_csr_mcycle_wdata <= 64'b0;  
           rvfi_csr_mcycle_wmask <= 64'b0;
           rvfi_csr_mcycle_rdata <= 64'b0;
           rvfi_csr_mcycle_rmask <= 64'b0;
      end
      else begin
           rvfi_csr_mcycle_wdata <= csr_mcycle_wdata; 
           rvfi_csr_mcycle_wmask <= csr_mcycle_wmask;
           rvfi_csr_mcycle_rdata <= csr_mcycle_rdata;
           rvfi_csr_mcycle_rmask <= csr_mcycle_rmask;
      end
end

always @(posedge clk or negedge rst_n)begin
      if(!rst_n)begin
           rvfi_csr_mepc_wdata <= 32'b0;  
           rvfi_csr_mepc_wmask <= 32'b0;
           rvfi_csr_mepc_rdata <= 32'b0;
           rvfi_csr_mepc_rmask <= 32'b0;
      end
      else begin
           rvfi_csr_mepc_wdata <= csr_mepc_wdata; 
           rvfi_csr_mepc_wmask <= csr_mepc_wmask;
           rvfi_csr_mepc_rdata <= csr_mepc_rdata;
           rvfi_csr_mepc_rmask <= csr_mepc_rmask;
      end
end


/////////////////////////////////////////////////////////////
IFU  IFU_inst
(
.clk          (clk           ) ,
.rst_n        (rst_n         ) ,
.pc_addr_valid(pc_addr_valid ) ,
.pc_addr      (pc_addr       ) ,
.mem_inst     (mem_inst      ) ,
.pc_ready     (pc_ready      ) ,
.jump_valid   (jump_valid    ) ,
.trap_valid   (trap_valid    ) ,
.exu_done     (exu_done      ) ,
.if_id_valid  (if_id_valid   ) ,
.if_id_ready  (if_id_ready   ) ,
.jump_pc      (jump_pc       ) ,
.trap_pc      (trap_pc       ) ,
.curr_pc      (curr_pc       ) ,    
.inst         (inst          )
);


/////////////////////////////////////////////////////////////
IDU IDU_inst
(
.clk           (clk            ) ,
.rst_n         (rst_n          ) ,
.inst_exce     (inst_exce      ) ,
//IFU<-->IDU   
.if_id_ready   (if_id_ready    ) ,
.inst          (inst           ) ,
.if_id_valid   (if_id_valid    ) ,
.curr_pc       (curr_pc        ) ,
//IDU<-->register
.rs1_addr      (idu_rs1_addr   ) ,
.rs2_addr      (idu_rs2_addr   ) , 
//IDU<-->EXU   
.imm           (idu_imm        ) ,
.idu_valid     (idu_valid      ) ,
.exu_ready     (exu_ready      ) ,
.alu_op        (idu_alu_op     ) ,
.zimm          (idu_zimm       ) ,
.idu_reg_we    (idu_reg_we     ) ,
.rd_wr_addr    (idu_rd_wr_addr ) ,
.sign_type     (idu_sign_type  ) ,
.load_flag     (idu_load_flag  ) ,
.jump_flag     (idu_jump_flag  ) ,
.trap_flag     (idu_trap_flag  ) ,
.lsu_flag      (idu_lsu_flag   ) ,
.idu_curr_pc   (idu_curr_pc    ) ,
.ecall_flag    (idu_ecall_flag ) ,
.mret_flag     (idu_mret_flag  ) ,
.break_flag    (idu_break_flag ) ,
.idu_mem_wen   (idu_mem_wen    ) , 
.idu_mem_wmask (idu_mem_wmask  ) ,
.idu_mem_ren   (idu_mem_ren    ) ,
.idu_mem_rmask (idu_mem_rmask  ) ,
//IDU<-->csr_register
.csr_addr      (idu_csr_addr   ) ,
.csr_wr_flag   (idu_csr_wr_flag) ,
.csr_rd_flag   (idu_csr_rd_flag) ,
);


/////////////////////////////////////////////////////////////
EXU EXU_inst
(
.clk            (clk            ) ,
.rst_n          (rst_n          ) ,
.pc_ready       (pc_ready       ) ,
.exu_done       (exu_done       ) ,
.exu_rs1        (exu_rs1        ) ,
.exu_rs2        (exu_rs2        ) ,
.jump_exce      (jump_exce      ) ,
//EXU<-->IFU
.jump_valid     (jump_valid     ) ,
.jump_pc        (jump_pc        ) ,
//IDU<-->EXU
.idu_valid      (idu_valid      ) ,
.exu_ready      (exu_ready      ) ,
.idu_alu_op     (idu_alu_op     ) ,
.idu_zimm       (idu_zimm       ) ,
.idu_imm        (idu_imm        ) ,
.idu_curr_pc    (idu_curr_pc    ) , 
.idu_mem_wen    (idu_mem_wen    ) ,   
.idu_mem_wmask  (idu_mem_wmask  ) ,
.idu_mem_ren    (idu_mem_ren    ) ,
.idu_mem_rmask  (idu_mem_rmask  ) ,
.idu_sign_type  (idu_sign_type  ) ,
.idu_reg_we     (idu_reg_we     ) ,
.idu_rd_addr    (idu_rd_wr_addr ) ,
.idu_load_flag  (idu_load_flag  ) ,
.idu_break_flag (idu_break_flag ) , 
.idu_ecall_flag (idu_ecall_flag ) ,
.idu_mret_flag  (idu_mret_flag  ) ,
.idu_csr_addr   (idu_csr_addr   ) ,
.idu_csr_wr_flag(idu_csr_wr_flag) ,
.idu_csr_rd_flag(idu_csr_rd_flag) ,
.jump_flag      (idu_jump_flag  ) ,
.trap_flag      (idu_trap_flag  ) ,
.lsu_flag       (idu_lsu_flag   ) ,
//EXU<-->CSR
.ex_csr_valid   (ex_csr_valid   ) ,
.ex_csr_ready   (ex_csr_ready   ) ,
.exu_csr_wr_flag(exu_csr_wr_flag) ,
.exu_csr_rd_flag(exu_csr_rd_flag) ,
.exu_csr_addr   (exu_csr_addr   ) ,
.exu_curr_pc    (exu_curr_pc    ) ,
.exu_break_flag (exu_break_flag ) , 
.exu_ecall_flag (exu_ecall_flag ) , 
.exu_mret_flag  (exu_mret_flag  ) , 
.csr_rd         (csr_rd         ) ,
.csr_wr         (csr_wr         ) , 
.exu_zimm       (exu_zimm       ) ,
.exu_csr_op     (exu_csr_op     ) ,
//EXU<-->LSU
.ex_ls_valid    (ex_ls_valid    ) ,
.ex_ls_ready    (ex_ls_ready    ) ,
.exu_sign_type  (exu_sign_type  ) ,
.exu_mem_waddr  (exu_mem_waddr  ) ,
.exu_mem_wdata  (exu_mem_wdata  ) ,
.exu_mem_wen    (exu_mem_wen    ) ,
.exu_mem_wmask  (exu_mem_wmask  ) ,
.exu_mem_raddr  (exu_mem_raddr  ) ,
.exu_mem_ren    (exu_mem_ren    ) ,
.exu_mem_rmask  (exu_mem_rmask  ) ,
//EXU<-->WBU
.exu_reg_done   (exu_reg_done   ) ,
.exu_reg_we     (exu_reg_we     ) ,
.exu_rd_addr    (exu_rd_addr    ) ,
.exu_rd_wr      (exu_rd_wr      ) , 
.exu_load_flag  (exu_load_flag  ) ,
//EXU<-->register
.rs1            (rs1            ) ,
.rs2            (rs2            ) 
);

/////////////////////////////////////////////////////////////
LSU LSU_inst
(
.clk           (clk           ) ,
.rst_n         (rst_n         ) ,
//LSU<-->memory
.mem_waddr     (mem_waddr     ) ,
.mem_wdata     (mem_wdata     ) ,
.mem_wen       (mem_wen       ) ,
.mem_wmask     (mem_wmask     ) ,
.mem_raddr     (mem_raddr     ) ,
.mem_ren       (mem_ren       ) ,
.mem_rmask     (mem_rmask     ) , 
.mem_rdata     (mem_rdata     ) ,
.rdata_offset  (rdata_offset  ) ,
//LSU<-->EXU
.ex_ls_valid   (ex_ls_valid   ) ,
.ex_ls_ready   (ex_ls_ready   ) ,
.exu_sign_type (exu_sign_type ) ,
.exu_mem_waddr (exu_mem_waddr ) ,
.exu_mem_wdata (exu_mem_wdata ) ,
.exu_mem_wen   (exu_mem_wen   ) ,
.exu_mem_wmask (exu_mem_wmask ) ,
.exu_mem_raddr (exu_mem_raddr ) ,
.exu_mem_ren   (exu_mem_ren   ) ,
.exu_mem_rmask (exu_mem_rmask ) ,
//LSU<-->WBU
.lsu_mem_rdata (lsu_mem_rdata ) ,
.lsu_data_valid(lsu_data_valid)
);

/////////////////////////////////////////////////////////////
WBU WBU_inst
(
.exu_reg_done  (exu_reg_done  ) ,
.exu_load_flag (exu_load_flag ) ,
.exu_rd_wr     (exu_rd_wr     ) ,   
.exu_reg_we    (exu_reg_we    ) ,
.exu_rd_addr   (exu_rd_addr   ) ,
.lsu_mem_rdata (lsu_mem_rdata ) ,
.lsu_data_valid(lsu_data_valid) ,
.wbu_wr_data   (wbu_wr_data   ) , 
.wbu_we        (wbu_we        ) ,
.wbu_wr_addr   (wbu_wr_addr   ) 
);

/////////////////////////////////////////////////////////////
regfile regfile_inst
(
.clk         (clk         ) , 
.rs1_addr    (idu_rs1_addr) ,
.rs2_addr    (idu_rs2_addr) ,
.rd_wr_addr  (wbu_wr_addr ) ,
.reg_we      (wbu_we      ) ,
.wr_data     (wbu_wr_data ) ,    
.rs1         (rs1         ) ,
.rs2         (rs2         ) ,
.debug_addr  (debug_addr  ) ,
.debug_reg   (debug_reg   ) ,
.rf_rd_addr  (rf_rd_addr  ) ,
.rf_rd_data  (rf_rd_data  ) 
);

/////////////////////////////////////////////////////////////
csr_regfile csr_regfile_inst
(
.clk              (clk             ),  
.rst_n            (rst_n           ),
.mcycle_flag      (mcycle_flag     ),
.break_done       (break_done      ),
.csr_addr         (exu_csr_addr    ), 
.ex_csr_valid     (ex_csr_valid    ),
.ex_csr_ready     (ex_csr_ready    ),
.pc_ready         (pc_ready        ),
.trap_valid       (trap_valid      ),
.trap_pc          (trap_pc         ),
.ecall_flag       (exu_ecall_flag  ),
.break_flag       (exu_break_flag  ),
.mret_flag        (exu_mret_flag   ),
.csr_wr_flag      (exu_csr_wr_flag ),
.csr_rd_flag      (exu_csr_rd_flag ),
.curr_pc          (exu_curr_pc     ), 
.csr_wr           (csr_wr          ),
.csr_rd           (csr_rd          ),
.exu_csr_op       (exu_csr_op      ),
.exu_zimm         (exu_zimm        ),
.exu_rs1          (exu_rs1         ),
.csr_mcycle_wdata (csr_mcycle_wdata), 
.csr_mcycle_wmask (csr_mcycle_wmask),
.csr_mcycle_rdata (csr_mcycle_rdata),
.csr_mcycle_rmask (csr_mcycle_rmask),                     
.csr_mepc_wdata   (csr_mepc_wdata  ),
.csr_mepc_wmask   (csr_mepc_wmask  ),
.csr_mepc_rdata   (csr_mepc_rdata  ),
.csr_mepc_rmask   (csr_mepc_rmask  )
);

/////////////////////////////////////////////////////////////
memory 
#(
.MEM_WIDTH (8 ),
.MEM_DEPTH (16)  
)
memory_inst
(
.clk             (clk             ),
.rst_n           (rst_n           ),
.memory_exce     (memory_exce     ),
//memory<-->IFU
.pc_addr_valid   (pc_addr_valid   ),
.pc_addr         (pc_addr         ),   
.mem_inst        (mem_inst        ),
//memory<-->LSU
.mem_waddr       (mem_waddr       ),
.mem_wdata       (mem_wdata       ),
.mem_wen         (mem_wen         ),
.mem_wmask       (mem_wmask       ),   
.mem_raddr       (mem_raddr       ),
.mem_ren         (mem_ren         ),
.mem_rmask       (mem_rmask       ),
.mem_rdata       (mem_rdata       ),
.rdata_offset    (rdata_offset    ),
.wdata_offset    (wdata_offset    ),
.rvfi_mem_waddr  (rvfi_mem_waddr  ),
.rvfi_mem_raddr  (rvfi_mem_raddr  ),
.rvfi_wdata_shift(rvfi_wdata_shift)
);


endmodule
