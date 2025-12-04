#!/bin/bash
# check_db.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

function check_port {
    if netstat -ntlp | grep -q ":$1 "; then
        echo -e "${GREEN}[OK] 端口 $1 (服务: $2) 正常监听${NC}"
    else
        echo -e "${RED}[ERROR] 端口 $1 (服务: $2) 未启动!${NC}"
    fi
}

function check_mysql_docker {
    if docker ps | grep -q "$1"; then
        echo -e "${GREEN}[OK] Docker 容器 $1 正在运行${NC}"
    else
        echo -e "${RED}[ERROR] Docker 容器 $1 挂了!${NC}"
    fi
}

function check_api {
    # 请根据审计结果修改端口 5000 或 8088
    local port=$1
    local endpoint="http://127.0.0.1:$port/api/stats/kkmc_count"
    local http_code=$(curl -o /dev/null -s -w "%{http_code}\n" "$endpoint")
    if [ "$http_code" == "200" ]; then
        echo -e "${GREEN}[OK] Flask API ($port) 响应正常 (HTTP 200)${NC}"
    else
        echo -e "${RED}[ERROR] Flask API ($port) 响应异常 (HTTP $http_code)${NC}"
    fi
}

echo "=== DB-App 节点健康检查 ==="

# 1. 检查物理库容器
check_mysql_docker "mysql-n1"
check_mysql_docker "mysql-n2"

# 2. 检查 MyCat
check_port 8066 "MyCat"

# 3. 检查 Flask (注意确认是 5000 还是 8088)
# 这里假设先查 5000，如果之前审计发现是 8088 请自行修改
check_port 5000 "Flask API"
check_api 5000

# 4. 简单的数据库查询验证 (验证 MyCat 是否可读)
# 这一步需要 mysql 客户端
if command -v mysql &> /dev/null; then
    count=$(docker exec -i mysql-n1 mysql -h 172.17.0.1 -P 8066 -u root -p123456 -D MYETCDB -N -e "SELECT count(*) FROM traffic_data;" 2>/dev/null)
    if [[ "$count" =~ ^[0-9]+$ ]]; then
        echo -e "${GREEN}[OK] MyCat 查询成功，当前数据量: $count${NC}"
    else
        echo -e "${RED}[ERROR] MyCat 查询失败!${NC}"
    fi
fi

echo "=== 检查结束 ==="
