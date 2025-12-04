#!/bin/bash
# 保存为 audit_server.sh
# 运行方式: chmod +x audit_server.sh && ./audit_server.sh

# 尝试主动加载环境变量（解决非交互式 Shell 读不到变量的问题）
[ -f /etc/profile ] && source /etc/profile
[ -f ~/.bashrc ] && source ~/.bashrc
[ -f ~/.bash_profile ] && source ~/.bash_profile

echo "========== 服务器深度审计报告 V2.0: $(hostname) =========="
echo "时间: $(date)"
echo "IP地址: $(hostname -I)"

echo -e "\n[1] 环境变量深度检查 (Environment)"
# 1. 输出当前加载的变量
echo "JAVA_HOME (Current): $JAVA_HOME"
echo "CLASSPATH (Current): $CLASSPATH"
# 2. 如果为空，尝试自动探测 Java 路径
if [ -z "$JAVA_HOME" ]; then
    java_path=$(readlink -f $(which java) 2>/dev/null | sed "s:bin/java::")
    if [ -n "$java_path" ]; then
        echo "JAVA_HOME (Detected): $java_path (自动探测)"
    else
        echo "JAVA_HOME (Detected): 未找到 Java 安装路径！"
    fi
else
    echo "JAVA_HOME 状态: 已配置"
fi

echo -e "\n[2] 核心组件版本检查 (Version Check)"

# --- Java & Python ---
echo -n "Java 版本: "
java -version 2>&1 | head -n 1 | awk -F '"' '{print $2}' || echo "未安装"

echo -n "Python3 版本: "
python3 --version 2>&1 | awk '{print $2}' || echo "未安装"

# --- Zookeeper & Kafka ---
# Kafka 没有简单的 version 命令，通常看 Jar 包名字最准
if [ -d "/usr/local/kafka/libs" ]; then
    echo -n "Kafka (Jar包推断): "
    ls /usr/local/kafka/libs/kafka_*.jar 2>/dev/null | head -n 1 | grep -o "kafka_.*.jar" || echo "Jar包未找到"
    
    echo -n "Zookeeper (Jar包推断): "
    ls /usr/local/kafka/libs/zookeeper*.jar 2>/dev/null | head -n 1 | grep -o "zookeeper.*.jar" || echo "Jar包未找到"
else
    echo "Kafka/ZK 目录不存在 (/usr/local/kafka)"
fi

# --- Flume (仅 pipeline-algo) ---
if [ -x "/usr/local/flume/bin/flume-ng" ]; then
    echo -n "Flume 版本: "
    /usr/local/flume/bin/flume-ng version 2>&1 | grep "Flume" | head -n 1 || echo "获取失败"
fi

# --- Flink (仅 pipeline-algo) ---
if [ -x "/usr/local/flink/bin/flink" ]; then
    echo -n "Flink 版本: "
    /usr/local/flink/bin/flink --version 2>&1 | grep "Version" || echo "获取失败"
fi

# --- MyCat (仅 db-app) ---
# MyCat 很难直接看版本，尝试看 wrapper.log 的启动日志
if [ -f "/usr/local/mycat/logs/wrapper.log" ]; then
    echo -n "MyCat (日志推断): "
    grep -i "MyCat Server" /usr/local/mycat/logs/wrapper.log | tail -n 1 | grep -o "MyCat Server .*" || echo "日志中未找到版本信息"
elif [ -d "/usr/local/mycat" ]; then
    echo "MyCat 已安装 (但日志为空，可能未启动过)"
fi

# --- MySQL (Docker) ---
if command -v docker &> /dev/null; then
    echo "Docker MySQL 版本:"
    # 检查正在运行的容器镜像版本
    docker ps --format "{{.Names}}: {{.Image}}" | grep mysql
else
    echo "Docker: 未安装"
fi

echo -e "\n[3] Python 关键依赖版本 (Pip Freeze)"
# 检查 Flask 及其相关库
if command -v pip3 &> /dev/null; then
    pip3 freeze | grep -E "Flask|pymysql|redis|pyspark|kafka-python" || echo "未找到关键 Python 包"
else
    echo "pip3 未安装"
fi

echo -e "\n[4] 核心端口监听复查"
netstat -ntlp | grep -E '2181|9092|8066|3306|3307|5000|8088|6379'

echo -e "\n========== 审计 V2.0 结束 =========="
