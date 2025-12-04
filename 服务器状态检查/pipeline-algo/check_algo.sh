#!/bin/bash
# check_algo.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

function check_port {
    if netstat -ntlp | grep -q ":$1 "; then
        echo -e "${GREEN}[OK] 端口 $1 (服务: $2) 正常监听${NC}"
    else
        echo -e "${RED}[ERROR] 端口 $1 (服务: $2) 未启动!${NC}"
    fi
}

function check_process {
    if pgrep -f "$1" > /dev/null; then
        echo -e "${GREEN}[OK] 进程 $1 正在运行${NC}"
    else
        echo -e "${RED}[ERROR] 进程 $1 未找到!${NC}"
    fi
}

function check_file_growth {
    local file=$1
    if [ ! -f "$file" ]; then
        echo -e "${RED}[ERROR] 文件 $file 不存在!${NC}"
        return
    fi
    local size1=$(stat -c%s "$file")
    sleep 2
    local size2=$(stat -c%s "$file")
    if [ "$size2" -gt "$size1" ]; then
        echo -e "${GREEN}[OK] 数据源 $file 正在写入 (Size: $size1 -> $size2)${NC}"
    else
        echo -e "${RED}[WARNING] 数据源 $file 大小未变化 (数据流可能断了)${NC}"
    fi
}

echo "=== Pipeline-Algo 节点健康检查 ==="

# 1. 检查端口
check_port 2181 "Zookeeper"
check_port 9092 "Kafka"
# Flink Web UI 端口通常是 8081
check_port 8081 "Flink Cluster"

# 2. 检查关键进程
check_process "file2kafka.conf" # Flume
check_process "simulate.py"     # 模拟脚本
check_process "TaskManager"     # Flink TaskManager

# 3. 检查数据流动性
check_file_growth "/var/log/traffic.log"

# 4. 检查 Flink 任务状态 (需要 Flink CLI)
if /usr/local/flink/bin/flink list 2>/dev/null | grep -q "RUNNING"; then
    echo -e "${GREEN}[OK] Flink 任务状态: RUNNING${NC}"
else
    echo -e "${RED}[ERROR] 未检测到运行中的 Flink 任务!${NC}"
fi

echo "=== 检查结束 ==="
