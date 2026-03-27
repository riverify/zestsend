# 🔒 ZestSend 安全修复版本

**原仓库**: https://github.com/RavelloH/zestsend  
**修复版本**: riverify/zestsend (security-hardened)  
**修复日期**: 2026-03-27

---

## 📋 修复内容

### 1️⃣ 依赖升级（CVE 修复）

| 依赖 | 原版本 | 修复版本 | 修复的 CVE |
|------|--------|----------|-----------|
| **Next.js** | 14.2.35 | **14.2.35** | ⚠️ 最新版，CVE 待官方修复 |
| **React** | ^18 | **18.3.1** | ✅ 安全更新 |
| **React-DOM** | ^18 | **18.3.1** | ✅ 安全更新 |
| **eslint-config-next** | 14.0.4 | **14.2.35** | ✅ 匹配 Next.js 版本 |
| **Redis** | 7.2 | **7.2.10** | ✅ CVE-2025-49844, CVE-2025-21605 |

**注意**: Next.js 14.2.35 是当前最新稳定版（截至 2026-03-27）。CVE 问题已上报，等待官方修复。临时缓解措施：
- 通过 Nginx 限制访问频率
- 启用 WAF 规则
- 限制请求大小

### 2️⃣ Docker 安全加固

#### ✅ 已实施的安全措施：

1. **非 root 用户运行**
   ```dockerfile
   RUN adduser --system --uid 1001 nextjs
   USER nextjs
   ```

2. **只读文件系统**
   ```yaml
   read_only: true
   tmpfs:
     - /tmp:size=128M
   ```

3. **权限限制**
   ```yaml
   security_opt:
     - no-new-privileges:true
   ```

4. **资源限制**
   ```yaml
   deploy:
     resources:
       limits:
         cpus: '1.0'
         memory: 512M
   ```

5. **Redis 认证**
   ```bash
   --requirepass zestsend_secure_redis_2026
   --protected-mode yes
   ```

6. **网络隔离**
   - Redis 仅内网访问
   - 独立 Docker 网络
   - 自定义子网隔离

---

## 🚀 部署步骤

### 前置要求
- Docker 20.10+
- Docker Compose 2.0+
- 至少 1GB 可用内存
- 至少 500MB 磁盘空间

### 快速部署

```bash
# 1. 进入项目目录
cd /home/raken/code/zestsend

# 2. 创建数据目录
sudo mkdir -p /opt/docker-data/zestsend/redis-data

# 3. （可选）自定义 Redis 密码
cp .env.example .env.production
# 编辑 .env.production，修改 REDIS_PASSWORD

# 4. 构建并启动
docker compose up -d --build

# 5. 查看日志
docker compose logs -f

# 6. 验证服务
curl http://localhost:18850
```

### 停止服务

```bash
docker compose down
# 或者保留数据
docker compose down -v
```

---

## 🔐 安全配置建议

### 1. 修改默认密码

**必须修改！** 编辑 `.env.production`：

```bash
REDIS_PASSWORD=你的强密码_至少 16 字符
```

### 2. 配置 Nginx 反向代理（推荐）

创建 `/etc/nginx/sites-available/zestsend`：

```nginx
server {
    listen 18850 ssl http2;
    server_name your-domain.com;

    # SSL 证书
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

    # 安全配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;

    # 安全头
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    location / {
        proxy_pass http://localhost:18850;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;

        # 限制请求大小（防止大文件攻击）
        client_max_body_size 100M;
        
        # 速率限制（可选）
        # limit_req zone=one burst=10 nodelay;
    }
}
```

启用配置：

```bash
sudo ln -s /etc/nginx/sites-available/zestsend /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 3. 防火墙配置

```bash
# 只允许必要端口
sudo ufw allow 18850/tcp
sudo ufw allow 443/tcp  # HTTPS
sudo ufw deny 6379/tcp  # Redis 不对外

# 启用防火墙
sudo ufw enable
```

### 4. 监控日志

```bash
# 应用日志
docker compose logs -f zestsend-app

# Redis 日志
docker compose logs -f zestsend-redis

# Nginx 访问日志
sudo tail -f /var/log/nginx/access.log
```

---

## 📊 资源使用监控

### 查看容器资源

```bash
docker stats zestsend-app zestsend-redis
```

### 预期资源使用

| 组件 | CPU | 内存 | 磁盘 |
|------|-----|------|------|
| Next.js | 0.1-0.5 核 | 200-400 MB | ~200 MB |
| Redis | 0.05-0.2 核 | 50-150 MB | ~50 MB |
| **合计** | **0.2-0.7 核** | **250-550 MB** | **~300 MB** |

---

## 🧪 验证部署

### 1. 健康检查

```bash
# 应用健康
curl http://localhost:18850/

# Redis 健康
docker exec zestsend-redis redis-cli -a zestsend_secure_redis_2026 ping
```

### 2. 功能测试

1. 访问 `http://your-server-ip:18850`
2. 输入 4 位数字创建房间
3. 在另一个浏览器/设备输入相同数字
4. 测试文件传输、消息、视频通话

### 3. 安全测试

```bash
# 检查 Redis 是否对外暴露
nmap -p 6379 your-server-ip
# 应该显示 filtered 或 closed

# 检查应用响应
curl -I http://localhost:18850
# 应该返回 200 OK
```

---

## ⚠️ 已知限制

1. **无用户认证** - 任何人都可以访问（建议通过 Nginx 限制 IP）
2. **无内容审核** - P2P 传输无法监控内容
3. **单线程 Node.js** - 并发用户有限（~100-200）

---

## 📝 更新计划

- [ ] 添加用户认证（可选）
- [ ] 添加房间密码功能
- [ ] 添加访问日志审计
- [ ] 添加速率限制
- [ ] 添加 TURN 服务器配置

---

## 🆘 故障排除

### 问题 1：容器无法启动

```bash
# 查看日志
docker compose logs zestsend-app

# 常见原因：端口被占用
sudo lsof -i :18850
```

### 问题 2：Redis 连接失败

```bash
# 检查 Redis 状态
docker compose ps zestsend-redis

# 测试连接
docker exec zestsend-redis redis-cli -a zestsend_secure_redis_2026 ping
```

### 问题 3：P2P 连接失败

- 检查防火墙是否允许 WebRTC 流量
- 考虑配置 TURN 服务器（用于严格 NAT）
- 检查浏览器是否支持 WebRTC

---

## 📞 联系方式

- 原项目：https://github.com/RavelloH/zestsend
- 安全问题：提交 Issue 或联系 River

---

**最后更新**: 2026-03-27  
**维护者**: River's IT Department 👾
