#include <stdio.h>
#include <stdint.h>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vtop.h"
#include "Vtop___024root.h"
#include <fstream>
#include <vector>
#include <cstring>

// 存储器深度（16位地址 = 64KB）
#define MEM_SIZE 65536
// Intel Hex 记录类型
#define IHEX_DATA    0x00
#define IHEX_EOF     0x01
#define IHEX_EXT_SEG 0x02
#define IHEX_EXT_LIN 0x04


Vtop *dut;  // 改为指针，便于动态分配
VerilatedVcdC *tfp = nullptr;
uint64_t sim_time = 0;
int cycle = 0;
int exit_code = 0;

//---------- 加载二进制文件到内部存储器 ----------
void load_image(const char *filename, uint32_t base_addr) {
    printf("Attempting to open file: %s\n", filename);
    std::ifstream file(filename);
    if (!file.is_open()) {
        perror("fopen failed");
        exit(1);
    }

    // 存储器访问路径
    auto &mem = dut->rootp->top__DOT__memory_inst__DOT__memory;

    size_t total_bytes = 0;
    std::string line;
    uint32_t current_addr = base_addr;
    int line_count = 0;

    while (std::getline(file, line)) {
        line_count++;
        // 去除首尾空白
        size_t start = line.find_first_not_of(" \t\r\n");
        size_t end = line.find_last_not_of(" \t\r\n");
        if (start == std::string::npos) continue;  // 空行跳过
        std::string trimmed = line.substr(start, end - start + 1);
        if (trimmed.length() < 8) continue;        // 不足8字符跳过

        // 检查存储器是否已满（防止越界）
        if (current_addr + 3 >= MEM_SIZE) {
            printf("WARNING: memory full (addr 0x%04x), stop loading.\n", current_addr);
            break;
        }
        uint32_t word = std::stoul(trimmed.substr(0, 8), nullptr, 16);
        // 按小端序写入 4 个字节
        for (int i = 0; i < 4; i++) {
            uint8_t byte = (word >> (i * 8)) & 0xFF;
            uint32_t target_addr = current_addr + i;
            mem[target_addr] = byte;
            total_bytes++;
        }
        current_addr += 4;
    }

    printf("Loaded %zu bytes from %s at base 0x%04x\n", total_bytes, filename, base_addr);
    if (total_bytes == 0) {
        fprintf(stderr, "WARNING: No data loaded from file!\n");
    }
}

// ---------- 单周期 ----------
static void single_cycle() {
  dut->clk = 0; dut->eval();Verilated::timeInc(5);
  if(tfp) tfp->dump(Verilated::time());
  dut->clk = 1; dut->eval();Verilated::timeInc(5);
  if(tfp) tfp->dump(Verilated::time());

}

// ---------- 复位 ----------
void reset(int n) {
    dut->rst_n = 0;
    while (n--) single_cycle();
    dut->rst_n = 1;
}

// ---------- 主函数 ----------
int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);

    const char *image_file = nullptr;
    bool trace_enabled = false;

    // 解析命令行参数
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--trace") == 0) {
            trace_enabled = true;
        } else if (image_file == nullptr) {
            image_file = argv[i];
        }
    }
    if (!image_file) {
        fprintf(stderr, "Usage: %s [--trace] <binary_file>\n", argv[0]);
        return 1;
    }    
       
    // 或者直接操作 context
    VerilatedContext* contextp = Verilated::threadContextp();
    contextp->timeprecision(12);  // 设置精度为 1ps
    // 初始化波形
    if (trace_enabled) {
        Verilated::traceEverOn(true);
        tfp = new VerilatedVcdC;
        dut = new Vtop;                         // 先分配 dut
        dut->trace(tfp, 99);
	tfp->set_time_unit("1 ns");
        tfp->open("wave.vcd");
    } else {
        dut = new Vtop;
    }

    // 加载程序（基址 0x0000，根据你的链接地址调整）
    load_image(image_file, 0x0000);

    reset(5);

    uint32_t last_pc = 0, last_inst = 0;

    while (!Verilated::gotFinish()) {
        last_pc = dut->curr_pc;
        last_inst = dut->inst;

        single_cycle();
        cycle++;
        if (cycle % 1000 == 0) {
            printf("Cycle %d: PC=0x%08x, inst=0x%08x\n", cycle, dut->curr_pc, dut->inst);
        }
        // 检测陷阱信号（假设顶层有 good_trap / bad_trap 输出）
        if (dut->good_trap) {
            printf("\n\033[1;32mGOOD TRAP at cycle %d\033[0m\n", cycle);
            break;
        }
        if (dut->bad_trap) {
            printf("\n\033[1;31mBAD TRAP at cycle %d\033[0m\n", cycle);
            exit_code = 1;
            break;
        }

        // 简单 PC 停滞检测
        static uint32_t prev_pc = 0;
        static int stuck = 0;
        if (dut->curr_pc == prev_pc) {
            stuck++;
            if (stuck > 100) {
                printf("PC stuck at 0x%04x\n", dut->curr_pc);
                exit_code = 1;
                break;
            }
        } else {
            stuck = 0;
            prev_pc = dut->curr_pc;
        }
       if (cycle > 100000) {
        printf("\nTimeout after %d cycles, stopping.\n", cycle);
        break;
       }
    }

    // 清理
    if (tfp) {
        tfp->close();
        delete tfp;
    }
    delete dut;

    printf("\n========================================\n");
    printf("Simulation ended after %d cycles\n", cycle);
    return exit_code;
}
