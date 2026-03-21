1、生成checks目录：在npc目录下执行 python3 ../../checks/genchecks.py

2、在checks目录下开始运行检查：make -j$(nproc) -k

3、列出所有已完成的检查及其状态
在 checks 目录下执行：for d in */; do tail -1 "$d/logfile.txt"; done


