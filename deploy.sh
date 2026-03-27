#!/bin/bash
# ZestSend 一键部署脚本（安全加固版）
# 使用方法：./deploy.sh

set -e

echo "🚀 ZestSend 部署脚本（安全加固版）"
echo "=================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 配置变量
PROJECT_DIR="/home/raken/code/zestsend"
DATA_DIR="/opt/docker-data/zestsend"
REDIS_PASSWORD="zestsend_secure_$(openssl rand -hex 16)"
PORT=18850

echo ""
echo "📋 配置信息:"
echo "  项目目录：$PROJECT_DIR"
echo "  数据目录：$DATA_DIR"
echo "  访问端口：$PORT"
echo "  Redis 密码：自动生成（随机）"
echo ""

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker 未安装${NC}"
    exit 1
fi

if ! command -v docker compose &> /dev/null; then
    echo -e "${RED}❌ Docker Compose 未安装${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Docker 检查通过${NC}"

# 创建目录
echo ""
echo "📁 创建目录..."
mkdir -p "$DATA_DIR/redis-data"
echo -e "${GREEN}✅ 目录创建完成${NC}"

# 生成环境配置文件
echo ""
echo "⚙️  生成环境配置文件..."
cat > "$PROJECT_DIR/.env.production" <<EOF
# ZestSend Production Configuration
# Generated: $(date)

# Redis Configuration
REDIS_URL=redis://:$REDIS_PASSWORD@zestsend-redis:6379
REDIS_PASSWORD=$REDIS_PASSWORD

# Next.js Configuration
NODE_ENV=production
NEXT_TELEMETRY_DISABLED=1
PORT=3000
EOF

echo -e "${GREEN}✅ 配置文件生成完成${NC}"
echo -e "${YELLOW}⚠️  重要：Redis 密码已保存到 .env.production${NC}"

# 构建并启动
echo ""
echo "🐳 构建 Docker 镜像..."
cd "$PROJECT_DIR"
docker compose build

echo ""
echo "🚀 启动服务..."
docker compose up -d

# 等待服务启动
echo ""
echo "⏳ 等待服务启动..."
sleep 10

# 健康检查
echo ""
echo "🏥 健康检查..."

if docker compose ps zestsend-redis | grep -q "healthy"; then
    echo -e "${GREEN}✅ Redis 健康${NC}"
else
    echo -e "${YELLOW}⚠️  Redis 状态检查中...${NC}"
fi

if docker compose ps zestsend-app | grep -q "healthy\|Up"; then
    echo -e "${GREEN}✅ 应用运行中${NC}"
else
    echo -e "${RED}❌ 应用启动失败${NC}"
    docker compose logs zestsend-app
    exit 1
fi

# 显示访问信息
echo ""
echo "=================================="
echo -e "${GREEN}✅ 部署成功！${NC}"
echo "=================================="
echo ""
echo "🌐 访问地址：http://your-server-ip:$PORT"
echo ""
echo "📝 重要文件:"
echo "  配置文件：$PROJECT_DIR/.env.production"
echo "  安全文档：$PROJECT_DIR/SECURITY_FIXES.md"
echo "  部署日志：docker compose logs"
echo ""
echo "🔧 常用命令:"
echo "  查看日志：docker compose logs -f"
echo "  停止服务：docker compose down"
echo "  重启服务：docker compose restart"
echo "  查看状态：docker compose ps"
echo ""
echo "🛡️  安全建议:"
echo "  1. 配置 Nginx 反向代理 + HTTPS"
echo "  2. 修改防火墙规则"
echo "  3. 定期更新依赖"
echo ""
echo "=================================="
