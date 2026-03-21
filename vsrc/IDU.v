module IDU
(
    input  wire        clk           ,
    input  wire        rst_n         ,    
    output reg         inst_exce     ,
    //IFU	
    input  wire [31:0] inst          ,
    input  wire [31:0] curr_pc       ,
    //IFU_IDU 握手
    input  wire        if_id_valid   ,
    output reg         if_id_ready   , 
    //registers
    output wire [4:0]  rs1_addr      ,
    output wire [4:0]  rs2_addr      , 
    output wire [4:0]  rd_wr_addr    ,
    //EXU
    output reg  [31:0] imm           ,
    output reg  [5:0]  alu_op        ,
    output wire [4:0]  zimm          ,
    output reg         idu_reg_we    ,
    output reg         idu_mem_wen   ,  
    output reg  [3:0]  idu_mem_wmask ,
    output reg         idu_mem_ren   , 
    output reg  [3:0]  idu_mem_rmask ,
    output reg         sign_type     ,
    output reg         break_flag    ,
    output reg         ecall_flag    ,
    output reg         mret_flag     ,  
    output wire [11:0] csr_addr      , 
    output reg         csr_wr_flag   ,
    output reg         csr_rd_flag   , 
    output reg         load_flag     ,
    output reg  [31:0] idu_curr_pc   ,   
    //IDU_EXU IDU_CSR 握手
    input  wire        exu_ready     ,
    output reg         idu_valid     ,
    output wire        jump_flag     ,
    output wire        trap_flag     ,
    output wire        lsu_flag    
);

////////////////////////////状态机//////////////////////////////
localparam  IDLE = 2'd0, SEND = 2'd1;

reg  [1:0]  curr_state;
reg  [31:0] inst_reg;

always @(posedge clk or negedge rst_n)begin
	if(!rst_n)begin
           curr_state  <= IDLE;
	   if_id_ready <= 1'b1;
           idu_valid   <= 1'b0;
	end
        else
	case(curr_state)
		IDLE:begin 
		  if(if_id_valid)begin
                    if_id_ready<= 1'b0;
		    idu_valid  <= 1'b1;
		    curr_state <= SEND; 
	          end
		  else begin
                    if_id_ready<= 1'b1;
                    idu_valid  <= 1'b0;
                    curr_state <= IDLE; 
		  end 
	        end
		SEND:begin
		  if(exu_ready)begin
		    curr_state <= IDLE;
                    if_id_ready<= 1'b1;
		    idu_valid  <= 1'b0;
	          end  
		  else begin
	            curr_state <= SEND;		    
	            if_id_ready<= 1'b0;
		    idu_valid  <= 1'b1;
	          end 
	       end
	      default:begin
                    if_id_ready<= 1'b1;
		    idu_valid  <= 1'b0;
                    curr_state <= IDLE;
	      end
      endcase
end

always @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
         inst_reg <= 32'h0;
         idu_curr_pc <= 32'h0;    
    end
    else if(if_id_valid&&if_id_ready)begin 
         inst_reg <= inst;
         idu_curr_pc <= curr_pc;
    end 
end

/////////////////////////////////////////////////////////////////
wire [6:0]  opcode ; 
wire [2:0]  funct3 ;
wire [6:0]  funct7 ;

assign opcode     = inst_reg[06:00];
assign rd_wr_addr = inst_reg[11:07]; 
assign funct3     = inst_reg[14:12];
assign rs1_addr   = inst_reg[19:15];
assign rs2_addr   = inst_reg[24:20];
assign funct7     = inst_reg[31:25];
assign csr_addr   = inst_reg[31:20];
assign zimm       = inst_reg[19:15];
assign jump_flag  = alu_op==6'd22||alu_op==6'd23||(alu_op>=6'd25&&alu_op<=6'd30);
assign trap_flag  = alu_op==6'd24||alu_op==6'd40||alu_op==6'd41;
assign lsu_flag   = (alu_op>=6'd17&&alu_op<=6'd21)||(alu_op>=6'd33&&alu_op<=6'd35);

always @(*)begin
     case (opcode) 	     
     //I-type
     7'b0010011: imm  = {{20{inst_reg[31]}},inst_reg[31:20]};  //addi  andi		
     7'b0000011: imm  = {{20{inst_reg[31]}},inst_reg[31:20]};  //lbu lw lb   
     7'b1100111: imm  = {{20{inst_reg[31]}},inst_reg[31:20]};  //jalr
     //S-type
     7'b0100011: imm  = {{20{inst_reg[31]}},inst_reg[31:25],inst_reg[11:7]}; //sw sb
     //U-type 
     7'b0110111: imm  = inst_reg[31:12]<<12;  //lui
     7'b0010111: imm  = inst_reg[31:12]<<12;  //auipc
     //J-type jal
     7'b1101111: imm  = {{12{inst_reg[31]}},inst_reg[19:12],inst_reg[20],inst_reg[30:21],1'b0}; 
     //B-type bne beq
     7'b1100011: imm  = {{20{inst_reg[31]}},inst_reg[7],inst_reg[30:25],inst_reg[11:8],1'b0}; 
     default   : imm  = 32'b0;        
   endcase	
end


//控制信号
always @(*)begin
    inst_exce     = 1'b0 ;
    alu_op        = 6'b0 ;
    idu_reg_we    = 1'b0 ;
    sign_type     = 1'b0 ;
    load_flag     = 1'b0 ;
    break_flag    = 1'b0 ;
    ecall_flag    = 1'b0 ;
    csr_wr_flag   = 1'b0 ;
    csr_rd_flag   = 1'b0 ;
    mret_flag     = 1'b0 ;
    idu_mem_wen   = 1'b0 ; 
    idu_mem_wmask = 4'b0 ;
    idu_mem_ren   = 1'b0 ;
    idu_mem_rmask = 4'b0 ;

    case (opcode)
    /// R-type
    7'b0110011: begin
        idu_reg_we = 1'b1 ;
        case (funct3)
            3'h0: begin // add/sub
                if (funct7 == 7'h0)      alu_op = 6'd0; // add
                else if (funct7 == 7'h20) alu_op = 6'd1; // sub
                else inst_exce = 1'b1;
            end
            3'h1: begin // sll
                if (funct7 == 7'h0) alu_op = 6'd2;
                else inst_exce = 1'b1;
            end
            3'h2: begin // slt
                if (funct7 == 7'h0) alu_op = 6'd3;
                else inst_exce = 1'b1;
            end
            3'h3: begin // sltu
                if (funct7 == 7'h0) alu_op = 6'd4;
                else inst_exce = 1'b1;
            end
            3'h4: begin // xor
                if (funct7 == 7'h0) alu_op = 6'd5;
                else inst_exce = 1'b1;
            end
            3'h5: begin // srl / sra
                if (funct7 == 7'h0)      alu_op = 6'd7; // srl
                else if (funct7 == 7'h20) alu_op = 6'd6; // sra
                else inst_exce = 1'b1;
            end
            3'h6: begin // or
                if (funct7 == 7'h0) alu_op = 6'd37;
                else inst_exce = 1'b1;
            end
            3'h7: begin // and
                if (funct7 == 7'h0) alu_op = 6'd8;
                else inst_exce = 1'b1;
            end
            default: inst_exce = 1'b1;
        endcase
    end
    // I-type (ALU immediate)
    7'b0010011: begin
        idu_reg_we = 1'b1 ;
        case (funct3)
            3'h0: alu_op = 6'd9;  // addi
            3'h1: begin // slli
                if (imm[11:5] == 7'h0) alu_op = 6'd10;
                else inst_exce = 1'b1;
            end
            3'h2: alu_op = 6'd31; // slti
            3'h3: alu_op = 6'd32; // sltiu
            3'h4: alu_op = 6'd11; // xori
            3'h5: begin // srli / srai
                if (imm[11:5] == 7'h0)      alu_op = 6'd13; // srli
                else if (imm[11:5] == 7'h20) alu_op = 6'd12; // srai
                else inst_exce = 1'b1;
            end
            3'h6: alu_op = 6'd36; // ori
            3'h7: alu_op = 6'd14; // andi
            default: inst_exce = 1'b1;
        endcase
    end
    //lui
    7'b0110111:begin
                inst_exce     = 1'b0 ;
	        alu_op        = 6'd15;
		idu_reg_we    = 1'b1 ;
        	sign_type     = 1'b0 ;
		load_flag     = 1'b0 ;
                break_flag    = 1'b0 ;       
	        csr_wr_flag   = 1'b0 ;
		csr_rd_flag   = 1'b0 ;
	       	mret_flag     = 1'b0 ;
		ecall_flag    = 1'b0 ;
                idu_mem_wen   = 1'b0 ;
                idu_mem_wmask = 4'b0 ;
                idu_mem_ren   = 1'b0 ;
                idu_mem_rmask = 4'b0 ;
	        end
    //auipc
    7'b0010111:begin
                inst_exce     = 1'b0 ;
	        alu_op        = 6'd16;
		idu_reg_we    = 1'b1 ;
        	sign_type     = 1'b0 ;
		load_flag     = 1'b0 ;
                break_flag    = 1'b0 ; 
                csr_wr_flag   = 1'b0 ;
		csr_rd_flag   = 1'b0 ;
	        mret_flag     = 1'b0 ;
		ecall_flag    = 1'b0 ;
                idu_mem_wen   = 1'b0 ;
                idu_mem_wmask = 4'b0 ;
                idu_mem_ren   = 1'b0 ;
                idu_mem_rmask = 4'b0 ;
	        end
    //Load 
    7'b0000011: begin
        idu_reg_we = 1'b1 ;
        load_flag  = 1'b1 ;
        idu_mem_ren = 1'b1 ;
        case (funct3)
            3'h0: begin // lb
                alu_op = 6'd17;
                idu_mem_rmask = 4'b0001;
                sign_type = 1'b1;
            end
            3'h1: begin // lh
                alu_op = 6'd33;
                idu_mem_rmask = 4'b0011;
                sign_type = 1'b1;
            end
            3'h2: begin // lw
                alu_op = 6'd18;
                idu_mem_rmask = 4'b1111;
                sign_type = 1'b0;
            end
            3'h4: begin // lbu
                alu_op = 6'd19;
                idu_mem_rmask = 4'b0001;
                sign_type = 1'b0;
            end
            3'h5: begin // lhu
                alu_op = 6'd34;
                idu_mem_rmask = 4'b0011;
                sign_type = 1'b0;
            end
            default: inst_exce = 1'b1;
        endcase
    end

    //Store 
    7'b0100011: begin
        idu_mem_wen = 1'b1 ;
        case (funct3)
            3'h0: begin // sb
                alu_op = 6'd20;
                idu_mem_wmask = 4'b0001;
                sign_type = 1'b1;
            end
            3'h1: begin // sh
                alu_op = 6'd35;
                idu_mem_wmask = 4'b0011;
                sign_type = 1'b1;
            end
            3'h2: begin // sw
                alu_op = 6'd21;
                idu_mem_wmask = 4'b1111;
                sign_type = 1'b0;
            end
            default: inst_exce = 1'b1;
        endcase
    end	   
    //jal
    7'b1101111:begin
               inst_exce     = 1'b0 ;
               alu_op        = 6'd22;
	       idu_reg_we    = 1'b1 ;
               sign_type     = 1'b0 ;	       
               load_flag     = 1'b0 ;
               break_flag    = 1'b0 ;
               csr_wr_flag   = 1'b0 ;
	       csr_rd_flag   = 1'b0 ; 
	       mret_flag     = 1'b0 ;
	       ecall_flag    = 1'b0 ;
               idu_mem_wen   = 1'b0 ;
               idu_mem_wmask = 4'b0 ;
               idu_mem_ren   = 1'b0 ;
               idu_mem_rmask = 4'b0 ;
       end 
     //jalr
     7'b1100111:begin
               inst_exce     = 1'b0 ;
	       alu_op        = 6'd23;
	       idu_reg_we    = 1'b1 ;
               sign_type     = 1'b0 ;	       
               load_flag     = 1'b0 ;
               csr_wr_flag   = 1'b0 ;
	       csr_rd_flag   = 1'b0 ;
	       break_flag    = 1'b0 ;	
               mret_flag     = 1'b0 ; 
	       ecall_flag    = 1'b0 ;
               idu_mem_wen   = 1'b0 ;
               idu_mem_wmask = 4'b0 ;
               idu_mem_ren   = 1'b0 ;
               idu_mem_rmask = 4'b0 ;
        end
// CSR instructions
    7'b1110011: begin
        case (funct3)
            3'b0: begin // ecall/ebreak/mret 
                case (inst[31:20])
                    12'h0: begin // ecall
                        ecall_flag = 1'b1;
                        alu_op = 6'd40;
                    end
                    12'h1: begin // ebreak (good trap)
                        break_flag = 1'b1;
                        alu_op = 6'd24;
                    end
                    12'h2: begin // ebreak (bad trap) 
                        break_flag = 1'b1;
                        alu_op = 6'd24;
                    end
                    12'h302: begin // mret
                        mret_flag = 1'b1;
                        alu_op = 6'd41;
                    end
                    default: inst_exce = 1'b1;
                endcase
            end
            3'b001: begin // csrrw
                idu_reg_we  = 1'b1;
                csr_wr_flag = 1'b1;
		csr_rd_flag = 1'b1;
                alu_op = 6'd38;
            end
            3'b010: begin // csrrs
                idu_reg_we  = 1'b1;
                csr_wr_flag = (rs1_addr != 0) ? 1'b1 : 1'b0;
		csr_rd_flag = 1'b1;
                alu_op = 6'd39;
            end
	    3'b011: begin // csrrc
	        idu_reg_we  = 1'b1;
		csr_wr_flag = 1'b1;
                csr_rd_flag = 1'b1;
	        alu_op      = 6'd44;	
	    end
	    3'b101: begin // csrrwi
                idu_reg_we  = 1'b1;
                csr_wr_flag = 1'b1;   
                csr_rd_flag = 1'b1;
		alu_op      = 6'd42; 
	    end
	    3'b110: begin // csrrsi
               idu_reg_we   = 1'b1;
               csr_wr_flag  = 1'b1;
               csr_rd_flag  = 1'b1;
               alu_op       = 6'd43; 
	    end
	    3'b111: begin // csrrci
               idu_reg_we   = 1'b1;
               csr_wr_flag  = 1'b1;
	       csr_rd_flag  = 1'b1;
	       alu_op       = 6'd45;
	    end
            default: inst_exce = 1'b1;
        endcase
    end

    // B-type 
    7'b1100011: begin
        idu_reg_we = 1'b0 ;
        case (funct3)
            3'h0: alu_op = 6'd25; // beq
            3'h1: alu_op = 6'd26; // bne
            3'h4: alu_op = 6'd27; // blt
            3'h5: alu_op = 6'd28; // bge
            3'h6: alu_op = 6'd29; // bltu
            3'h7: alu_op = 6'd30; // bgeu
            default: inst_exce = 1'b1;
        endcase
       end   
    default: inst_exce = 1'b1; 
  endcase
end

endmodule

