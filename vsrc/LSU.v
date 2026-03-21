module LSU
(
   input   wire        clk            ,
   input   wire        rst_n          ,
   //LSU<-->memory
   output  reg  [31:0] mem_waddr      ,
   output  reg  [31:0] mem_wdata      ,
   output  reg         mem_wen        ,
   output  reg  [3:0]  mem_wmask      ,
   output  reg  [31:0] mem_raddr      ,
   output  reg         mem_ren        ,
   output  reg  [3:0]  mem_rmask      , 
   input   wire [31:0] mem_rdata      ,
   input   wire [3:0]  rdata_offset   ,
   //EXU<-->LSU
   input   wire        ex_ls_valid    ,
   output  reg         ex_ls_ready    ,
   input   wire        exu_sign_type  ,
   input   wire [31:0] exu_mem_waddr  ,
   input   wire [31:0] exu_mem_wdata  ,
   input   wire        exu_mem_wen    ,
   input   wire [3:0]  exu_mem_wmask  ,
   input   wire [31:0] exu_mem_raddr  ,
   input   wire        exu_mem_ren    ,
   input   wire [3:0]  exu_mem_rmask  ,
   //LSU<-->WBU
   output  reg  [31:0] lsu_mem_rdata  ,
   output  reg         lsu_data_valid
);


/////////////////////////状态机////////////////////////////////
localparam IDLE = 2'd0, SEND = 2'd1, WAIT = 2'd2;
reg [1:0]  curr_state   ;
reg        mem_sign_type;
reg        mem_load_flag;


always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
           ex_ls_ready    <= 1'b1;
           lsu_data_valid <= 1'b0;
           curr_state     <= IDLE;
        end
        else case(curr_state)
             IDLE:begin
                   if(ex_ls_valid)begin
                    curr_state     <= SEND;
                    ex_ls_ready    <= 1'b0;
                   end
             end
             SEND:begin
                    lsu_data_valid <= mem_load_flag;
                    curr_state     <= WAIT;
             end
             WAIT:begin
                    ex_ls_ready    <= 1'b1;
                    lsu_data_valid <= 1'b0;
                    curr_state     <= IDLE;
             end
             default:begin
                    ex_ls_ready    <= 1'b1;
                    lsu_data_valid <= 1'b0;
                    curr_state     <= IDLE;
             end
     endcase
end

always @(posedge clk or negedge rst_n)begin
     if(!rst_n)begin
           mem_sign_type <= 1'b0 ;
	   mem_load_flag <= 1'b0 ;
           mem_waddr     <= 32'b0;
           mem_wdata     <= 32'b0;
           mem_wen       <= 1'b0 ;
           mem_wmask     <= 4'b0 ;
           mem_raddr     <= 32'b0;
           mem_ren       <= 1'b0 ;
           mem_rmask     <= 4'b0 ;
     end
     else if(ex_ls_valid&&ex_ls_ready)begin
           mem_sign_type <= exu_sign_type;
	   mem_load_flag <= exu_mem_ren  ;
           mem_waddr     <= exu_mem_waddr;
           mem_wdata     <= exu_mem_wdata;
           mem_wen       <= exu_mem_wen  ;
           mem_wmask     <= exu_mem_wmask;
           mem_raddr     <= exu_mem_raddr;
           mem_ren       <= exu_mem_ren  ;
           mem_rmask     <= exu_mem_rmask;
     end
     else if(curr_state==WAIT)begin 
	   mem_load_flag <= 1'b0 ;
           mem_wmask     <= 4'b0 ;
	   mem_waddr     <= 32'b0; 
           mem_wdata     <= 32'b0;
           mem_wen       <= 1'b0 ;
           mem_wmask     <= 4'b0 ;
           mem_raddr     <= 32'b0;
           mem_ren       <= 1'b0 ;
           mem_rmask     <= 4'b0 ;
     end
end

/////////////////////////////////////////////////////////////////////


always @(*)begin
   if(mem_ren&&rdata_offset==4'b1111)
           lsu_mem_rdata = mem_rdata;  //lw
   else if(!mem_sign_type&&mem_ren) begin  //lbu lhu
        case (rdata_offset)
            4'b0001: lsu_mem_rdata = {24'b0, mem_rdata[7:0]};
            4'b0010: lsu_mem_rdata = {24'b0, mem_rdata[15:8]};
            4'b0100: lsu_mem_rdata = {24'b0, mem_rdata[23:16]};
            4'b1000: lsu_mem_rdata = {24'b0, mem_rdata[31:24]};
            4'b0011: lsu_mem_rdata = {16'h0, mem_rdata[15:0]};
            4'b1100: lsu_mem_rdata = {16'h0, mem_rdata[31:16]};
            default: lsu_mem_rdata = 32'h0;
        endcase
   end
   else if(mem_sign_type&&mem_ren)begin//lb lh
         case (rdata_offset)
            4'b0001: lsu_mem_rdata = {{24{mem_rdata[7]}}, mem_rdata[7:0]};
            4'b0010: lsu_mem_rdata = {{24{mem_rdata[15]}}, mem_rdata[15:8]};
            4'b0100: lsu_mem_rdata = {{24{mem_rdata[23]}}, mem_rdata[23:16]};
            4'b1000: lsu_mem_rdata = {{24{mem_rdata[31]}}, mem_rdata[31:24]};
            4'b0011: lsu_mem_rdata = {{16{mem_rdata[15]}}, mem_rdata[15:0]};
            4'b1100: lsu_mem_rdata = {{16{mem_rdata[31]}}, mem_rdata[31:16]};
            default: lsu_mem_rdata = 32'h0;
         endcase
   end
   else
         lsu_mem_rdata = 32'h0;
end


endmodule


