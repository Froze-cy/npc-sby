module rvfi_wrapper (
    input  wire clock,
    input  wire reset,
    `RVFI_OUTPUTS  //用于展开RVFI连接端口

);

    top top_inst (
        .clk  (clock),
        .rst_n(~reset),          
        //RVFI
        .rvfi_valid (rvfi_valid),
        .rvfi_order (rvfi_order),
        .rvfi_insn  (rvfi_insn),
        .rvfi_trap  (rvfi_trap),
        .rvfi_mode  (rvfi_mode),
        .rvfi_ixl   (rvfi_ixl),
        .rvfi_rs1_addr  (rvfi_rs1_addr),
        .rvfi_rs2_addr  (rvfi_rs2_addr),
        .rvfi_rs1_rdata (rvfi_rs1_rdata),
        .rvfi_rs2_rdata (rvfi_rs2_rdata),
        .rvfi_rd_addr   (rvfi_rd_addr),
        .rvfi_rd_wdata  (rvfi_rd_wdata),
        .rvfi_pc_rdata  (rvfi_pc_rdata),
        .rvfi_pc_wdata  (rvfi_pc_wdata),
        .rvfi_mem_addr  (rvfi_mem_addr),
        .rvfi_mem_rmask (rvfi_mem_rmask),
        .rvfi_mem_wmask (rvfi_mem_wmask),
        .rvfi_mem_rdata (rvfi_mem_rdata),
        .rvfi_mem_wdata (rvfi_mem_wdata),
        .rvfi_csr_mcycle_wdata (rvfi_csr_mcycle_wdata), 
        .rvfi_csr_mcycle_wmask (rvfi_csr_mcycle_wmask),
        .rvfi_csr_mcycle_rdata (rvfi_csr_mcycle_rdata),
        .rvfi_csr_mcycle_rmask (rvfi_csr_mcycle_rmask),                     
        .rvfi_csr_mepc_wdata (rvfi_csr_mepc_wdata),
        .rvfi_csr_mepc_wmask (rvfi_csr_mepc_wmask),
        .rvfi_csr_mepc_rdata (rvfi_csr_mepc_rdata),
        .rvfi_csr_mepc_rmask (rvfi_csr_mepc_rmask)
);



endmodule
