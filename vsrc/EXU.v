module EXU
(   
    input  wire        clk            ,
    input  wire        rst_n          ,  
    output  reg        exu_done       ,  
    output  reg [31:0] exu_rs1        ,
    output  reg [31:0] exu_rs2        ,
    output wire        jump_exce      ,
    //EXU<-->IDU
    input  wire [5:0]  idu_alu_op     ,
    input  wire [4:0]  idu_zimm       ,
    input  wire [31:0] idu_imm        ,
    input  wire        idu_mem_wen    ,
    input  wire [3:0]  idu_mem_wmask  ,
    input  wire        idu_mem_ren    ,
    input  wire [3:0]  idu_mem_rmask  ,   
    input  wire        idu_sign_type  ,
    input  wire        idu_load_flag  , 
    input  wire        idu_reg_we     ,
    input  wire [4:0]  idu_rd_addr    ,
    input  wire        idu_break_flag ,    
    input  wire        idu_ecall_flag ,
    input  wire        idu_mret_flag  ,
    input  wire [31:0] idu_curr_pc    ,
    input  wire [11:0] idu_csr_addr   ,
    input  wire        idu_csr_wr_flag,
    input  wire        idu_csr_rd_flag,
    input  wire        jump_flag      ,
    input  wire        trap_flag      ,
    input  wire        lsu_flag       ,
    //IDU_EXU 握手
    input  wire        idu_valid      ,
    output  reg        exu_ready      ,	    
    //EXU<-->IFU
    output  reg [31:0] jump_pc        ,
    //EXU_IFU 握手
    input  wire        pc_ready       ,
    output  reg        jump_valid     ,	    
    //EXU<-->LSU 
    output  reg        exu_sign_type  ,   
    output  reg [31:0] exu_mem_waddr  ,
    output  reg [31:0] exu_mem_wdata  ,
    output  reg        exu_mem_wen    ,
    output  reg [3:0]  exu_mem_wmask  , 
    output  reg [31:0] exu_mem_raddr  ,
    output  reg        exu_mem_ren    ,
    output  reg [3:0]  exu_mem_rmask  ,   
    //EXU_LSU 握手
    input  wire        ex_ls_ready    , 
    output  reg        ex_ls_valid    ,	    
    //EXU<-->registers
    input  wire [31:0] rs1            ,
    input  wire [31:0] rs2            ,  
    //EXU<-->csr_registers 
    input  wire [31:0] csr_rd         ,  
    output  reg [31:0] csr_wr         ,
    output  reg [2:0]  exu_csr_op     , 
    output  reg [31:0] exu_zimm       ,
    output  reg        exu_break_flag ,
    output  reg        exu_ecall_flag ,
    output  reg        exu_mret_flag  ,
    output  reg        exu_csr_wr_flag,
    output  reg        exu_csr_rd_flag,
    output  reg [11:0] exu_csr_addr   ,
    output  reg [31:0] exu_curr_pc    ,
    //EXU_CSR 握手
    output  reg        ex_csr_valid   ,
    input  wire        ex_csr_ready   ,
    //EXU<-->WBU
    output  reg        exu_reg_done   ,
    output  reg        exu_load_flag  ,	    
    output  reg [31:0] exu_rd_wr      ,
    output  reg [4:0]  exu_rd_addr    ,
    output  reg        exu_reg_we     
);



/////////////////////////////////状态机//////////////////////////////////
localparam IDLE = 3'd0, JUMP = 3'd1, WAIT_CSR = 3'd2; 
localparam LSU_SEND = 3'd3, LSU_WAIT = 3'd4, ALU_SEND = 3'd5;

reg [2:0]  curr_state;
reg [31:0] imm_reg;
reg [5:0]  alu_op_reg;


always @(posedge clk or negedge rst_n)begin
	if(!rst_n)begin
               curr_state  <= IDLE;
               exu_ready   <= 1'b1;
               ex_csr_valid<= 1'b0;
               jump_valid  <= 1'b0;
	       ex_ls_valid <= 1'b0;
	       exu_done    <= 1'b0;
	       exu_reg_done<= 1'b0;
	end
	else case(curr_state)
	       IDLE:begin
		      if(idu_valid&&trap_flag)begin
                           curr_state  <= WAIT_CSR;
		           exu_ready   <= 1'b0;
		           ex_ls_valid <= 1'b0;
		           ex_csr_valid<= 1'b1;
		           jump_valid  <= 1'b0;
			   exu_done    <= 1'b0;
			   exu_reg_done<= 1'b0; 
		      end
		      else if(idu_valid&&jump_flag)begin
			   curr_state  <= JUMP;
                           exu_ready   <= 1'b0;
		           ex_ls_valid <= 1'b0;
		           ex_csr_valid<= 1'b0;
		           jump_valid  <= 1'b1;
			   exu_done    <= 1'b0;
			   exu_reg_done<= 1'b1; 
		      end
		      else if(idu_valid&&lsu_flag)begin
			   curr_state  <= LSU_SEND;
		           exu_ready   <= 1'b0;
		           ex_ls_valid <= 1'b1;
		           ex_csr_valid<= 1'b0;
		           jump_valid  <= 1'b0;
			   exu_done    <= 1'b0;
                           exu_reg_done<= 1'b0; 
		      end
                      else if(idu_valid)begin
			   curr_state  <= ALU_SEND;
		           exu_ready   <= 1'b0;
		           ex_ls_valid <= 1'b0;
		           ex_csr_valid<= 1'b0;
		           jump_valid  <= 1'b0;
			   exu_done    <= 1'b0;
		           exu_reg_done<= 1'b0; 
		      end
		      else begin
			   curr_state  <= IDLE;   
	                   exu_ready   <= 1'b1;
		           ex_ls_valid <= 1'b0;
		           ex_csr_valid<= 1'b0;
		           jump_valid  <= 1'b0;
			   exu_done    <= 1'b0; 
		           exu_reg_done<= 1'b0; 
		      end
	       end
	       JUMP:begin 
	              if(pc_ready)begin 
			   curr_state  <= IDLE;
		           exu_ready   <= 1'b1;
                           ex_ls_valid <= 1'b0;
                           ex_csr_valid<= 1'b0;
                           jump_valid  <= 1'b0;
			   exu_done    <= 1'b0; 
                           exu_reg_done<= 1'b0; 
		      end
		      else begin
			   curr_state  <= JUMP;   
	                   exu_ready   <= 1'b0;
                           ex_ls_valid <= 1'b0;
                           ex_csr_valid<= 1'b0;
                           jump_valid  <= 1'b1;
			   exu_done    <= 1'b0; 
                           exu_reg_done<= 1'b0; 
		      end
	       end
	       WAIT_CSR:begin 
	             if(ex_csr_ready)begin   
		           curr_state  <= IDLE;    
	                   exu_ready   <= 1'b1;             
                           ex_ls_valid <= 1'b0;
                           ex_csr_valid<= 1'b0;
                           jump_valid  <= 1'b0;
		           exu_done    <= 1'b0; 
		           exu_reg_done<= 1'b0; 
		     end 
		     else begin
			   curr_state  <= WAIT_CSR;     
	                   exu_ready   <= 1'b0;
                           ex_ls_valid <= 1'b0;
                           ex_csr_valid<= 1'b1;
                           jump_valid  <= 1'b0;
		           exu_done    <= 1'b0;	
	                   exu_reg_done<= 1'b0; 
		     end
	       end
	       LSU_SEND:begin 
	             if(ex_ls_ready)begin
			   curr_state  <= LSU_WAIT;
	                   exu_ready   <= 1'b0; 	     
                           ex_ls_valid <= 1'b0;
                           ex_csr_valid<= 1'b0;
                           jump_valid  <= 1'b0;
			   exu_done    <= 1'b0; 
		           exu_reg_done<= 1'b0; 
		     end
		     else begin
			   curr_state  <= LSU_SEND;  
                           exu_ready   <= 1'b0; 
                           ex_ls_valid <= 1'b1;
                           ex_csr_valid<= 1'b0;
                           jump_valid  <= 1'b0;
			   exu_done    <= 1'b0;
                           exu_reg_done<= 1'b0; 
	             end		   
	       end
	     LSU_WAIT:begin
	                   curr_state  <= IDLE;  
                           exu_ready   <= 1'b1; 
                           ex_ls_valid <= 1'b0;
                           ex_csr_valid<= 1'b0;
                           jump_valid  <= 1'b0;
			   exu_done    <= 1'b1;
                           exu_reg_done<= 1'b1; 
	     end 
             ALU_SEND:begin
			   curr_state  <= IDLE;  
                           exu_ready   <= 1'b1; 
                           ex_ls_valid <= 1'b0;
                           ex_csr_valid<= 1'b0;
                           jump_valid  <= 1'b0;
			   exu_done    <= 1'b1; 
                           exu_reg_done<= 1'b1; 
	              end
	      default:begin
                           exu_ready   <= 1'b1;
		           ex_ls_valid <= 1'b0;
		           ex_csr_valid<= 1'b0;
                           jump_valid  <= 1'b0;
		           exu_done    <= 1'b0;
		           exu_reg_done<= 1'b0; 
			   curr_state  <= IDLE;
	       end
       endcase
end

//数据缓存
always @(posedge clk or negedge rst_n)begin
	if(!rst_n)begin
             imm_reg         <= 32'b0;
	     alu_op_reg      <= 6'b0 ;
             exu_zimm        <= 32'b0;
	     exu_rs1         <= 32'b0;
             exu_rs2         <= 32'b0; 
             exu_break_flag  <= 1'b0 ;
             exu_ecall_flag  <= 1'b0 ;
             exu_mret_flag   <= 1'b0 ; 
	     exu_curr_pc     <= 32'b0;
             exu_csr_wr_flag <= 1'b0 ;
             exu_csr_rd_flag <= 1'b0 ;
	     exu_csr_addr    <= 12'b0;
	     exu_reg_we      <= 1'b0 ;
	     exu_load_flag   <= 1'b0 ;
             exu_rd_addr     <= 5'b0 ;
             exu_sign_type   <= 1'b0 ; 
             exu_mem_wen     <= 1'b0 ;
             exu_mem_wmask   <= 4'b0 ;
             exu_mem_ren     <= 1'b0 ;
             exu_mem_rmask   <= 4'b0 ;
        end
	else if(idu_valid&&exu_ready)begin
             imm_reg         <= idu_imm   ; 
	     alu_op_reg      <= idu_alu_op;
	     exu_zimm        <= {27'b0,idu_zimm};
	     exu_rs1         <= rs1;
	     exu_rs2         <= rs2; 
	     exu_break_flag  <= idu_break_flag;
             exu_ecall_flag  <= idu_ecall_flag;
             exu_mret_flag   <= idu_mret_flag;
	     exu_curr_pc     <= idu_curr_pc;
             exu_csr_wr_flag <= idu_csr_wr_flag;
             exu_csr_rd_flag <= idu_csr_rd_flag;	     
	     exu_csr_addr    <= idu_csr_addr;
	     exu_load_flag   <= idu_load_flag; 
	     exu_reg_we      <= idu_reg_we;  
             exu_rd_addr     <= idu_rd_addr;
             exu_sign_type   <= idu_sign_type;
             exu_mem_wen     <= idu_mem_wen;
             exu_mem_wmask   <= idu_mem_wmask;
             exu_mem_ren     <= idu_mem_ren;
             exu_mem_rmask   <= idu_mem_rmask;
       end
end


/////////////////////////////////////////////////////////////////////////

reg system_flag;

assign jump_exce = (jump_pc[1:0]!=2'b0) ? 1'b1 : 1'b0;

always @(*) begin
      if(alu_op_reg==6'd20)  //sb
	   exu_mem_wdata = {24'b0,exu_rs2[7:0]};
      else if(alu_op_reg==6'd35) //sh
	   exu_mem_wdata = {16'b0,exu_rs2[15:0]};
      else if(alu_op_reg==6'd21) //sw
	   exu_mem_wdata = exu_rs2;   
      else
           exu_mem_wdata = 32'b0;	      
end

always @(*)begin
      if(alu_op_reg==6'd38)  //csrrw
	   exu_csr_op = 3'd0;
      else if(alu_op_reg==6'd39) //csrrs
	   exu_csr_op = 3'd1;   
      else if(alu_op_reg==6'd42) //csrrwi
	   exu_csr_op = 3'd2;   
      else if(alu_op_reg==6'd43) //csrrsi
 	   exu_csr_op = 3'd3;   
      else if(alu_op_reg==6'd44)
	   exu_csr_op = 3'd4;
      else if(alu_op_reg==6'd45)
	   exu_csr_op = 3'd5;
      else
	   exu_csr_op = 3'd0;   
end


always @(*) begin
   jump_pc       = 32'b0;
   exu_rd_wr     = 32'b0;
   csr_wr        = 32'b0;
   exu_mem_waddr = 32'b0;
   exu_mem_raddr = 32'b0;
   system_flag   = 1'b0 ;

   case(alu_op_reg)
	 6'd0: exu_rd_wr = exu_rs1 + exu_rs2 ;  //add
	 6'd1: exu_rd_wr = exu_rs1 - exu_rs2 ;  //sub
	 6'd2: exu_rd_wr = exu_rs1 << exu_rs2[4:0];  //sll  
	 6'd3: exu_rd_wr = ($signed(exu_rs1)<$signed(exu_rs2))? 32'h1:32'h0; //slt 
	 6'd4: exu_rd_wr = (exu_rs1<exu_rs2)? 32'h1:32'h0; //sltu
	 6'd5: exu_rd_wr = exu_rs1 ^ exu_rs2 ;  //xor
         6'd6: exu_rd_wr = $signed(exu_rs1)>>>exu_rs2[4:0]; //sra
	 6'd7: exu_rd_wr = exu_rs1 >> exu_rs2[4:0];  //srl 
	 6'd8: exu_rd_wr = exu_rs1 & exu_rs2 ;  //and
	 6'd9: exu_rd_wr = exu_rs1 + imm_reg ;  //addi 
	 6'd10:exu_rd_wr = exu_rs1 << imm_reg[4:0] ; //slli
	 6'd11:exu_rd_wr = exu_rs1 ^ imm_reg ;  //xori 
	 6'd12:exu_rd_wr = $signed(exu_rs1)>>>imm_reg[4:0]; //srai 
         6'd13:exu_rd_wr = exu_rs1 >> imm_reg[4:0] ; //srli
	 6'd14:exu_rd_wr = exu_rs1 & imm_reg ;  //andi
	 6'd15:exu_rd_wr = {imm_reg[31:12],12'b0} ;  //lui
	 6'd16:exu_rd_wr = exu_curr_pc + {imm_reg[31:12],12'b0} ; //auipc
	 6'd17:exu_mem_raddr = exu_rs1 + imm_reg ; //lb 
         6'd18:exu_mem_raddr = exu_rs1 + imm_reg ; //lw 
         6'd19:exu_mem_raddr = exu_rs1 + imm_reg ; //lbu 
	 6'd20:exu_mem_waddr = exu_rs1 + imm_reg ; //sb     
	 6'd21:exu_mem_waddr = exu_rs1 + imm_reg ; //sw 
	 6'd22: begin  //jal
                 exu_rd_wr = exu_curr_pc + 4;  //pc + 4
                 jump_pc = exu_curr_pc + imm_reg; 
	     end
	 6'd23: begin  //jalr
                 exu_rd_wr = exu_curr_pc + 4;  //pc + 4
                 jump_pc   = (exu_rs1 + imm_reg)&~1; 
	     end
	 6'd24: system_flag = exu_break_flag; //ebreak  
	 6'd25: begin  //beq
                if(exu_rs1==exu_rs2)
                   jump_pc = exu_curr_pc + imm_reg ;
	        else 
	           jump_pc = exu_curr_pc + 4 ;
	     end	 
	 
	 6'd26: begin  //bne
                if(exu_rs1!=exu_rs2)
                   jump_pc = exu_curr_pc + imm_reg ;
	        else 
	           jump_pc = exu_curr_pc + 4 ;
	     end	 
         6'd27: begin  //blt
                if($signed(exu_rs1)<$signed(exu_rs2))
                   jump_pc = exu_curr_pc + imm_reg ;
	        else 
	           jump_pc = exu_curr_pc + 4 ;
	     end	 
	 6'd28: begin  //bge
                if($signed(exu_rs1)>=$signed(exu_rs2))
                   jump_pc = exu_curr_pc + imm_reg ;
	        else 
	           jump_pc = exu_curr_pc + 4 ;
	     end	 
         6'd29: begin  //bltu
                if(exu_rs1<exu_rs2)
                   jump_pc = exu_curr_pc + imm_reg ;
	        else 
	           jump_pc = exu_curr_pc + 4 ;
	     end	 
	 6'd30: begin  //bgeu
                if(exu_rs1>=exu_rs2)
                   jump_pc = exu_curr_pc + imm_reg ;
	        else 
	           jump_pc = exu_curr_pc + 4 ;
	     end
         6'd31: exu_rd_wr = ($signed(exu_rs1)<$signed(imm_reg))? 32'h1:32'h0; //slti
	 6'd32: exu_rd_wr = (exu_rs1<imm_reg)? 32'h1:32'h0; //sltiu 
	 6'd33: exu_mem_raddr = exu_rs1 + imm_reg ; //lh
	 6'd34: exu_mem_raddr = exu_rs1 + imm_reg ; //lhu 	     
         6'd35: exu_mem_waddr = exu_rs1 + imm_reg ; //sh
         6'd36: exu_rd_wr = exu_rs1 | imm_reg ; //ori
	 6'd37: exu_rd_wr = exu_rs1 | exu_rs2 ; //or
	 6'd38:begin  
	        exu_rd_wr = csr_rd ;  //csrrw
		csr_wr = exu_rs1 ; 
                end
         6'd39:begin
		exu_rd_wr = csr_rd ;  //csrrs
                csr_wr = csr_rd | exu_rs1 ;
	       end
	 6'd40: system_flag = exu_ecall_flag; //ecall
	 6'd41: system_flag = exu_mret_flag;  //mret
	 6'd42:begin                  
                exu_rd_wr = csr_rd;   //csrrwi
                csr_wr = exu_zimm;
	       end
         6'd43:begin                  //csrrsi
                exu_rd_wr = csr_rd;
                csr_wr = csr_rd | exu_zimm;
	       end
         6'd44:begin
                exu_rd_wr = csr_rd;   //csrrc
                csr_wr = csr_rd & ~exu_rs1;  
	       end
         6'd45:begin
                exu_rd_wr = csr_rd;   //csrrci
                csr_wr = csr_rd & ~exu_zimm;
	       end		 
       default:begin
                exu_rd_wr     = 32'h0;
		csr_wr        = 32'h0;
	        exu_mem_waddr = 32'h0;
                exu_mem_raddr = 32'h0;
		system_flag   = 1'b0;
              end		  
     endcase
end

endmodule
