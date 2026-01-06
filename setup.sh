#!/bin/bash

# 遇到错误立即停止
set -e

# 定义颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}>>> 开始自动化环境配置...${NC}"

# 1. 检查是否为 Root 用户
if [ "$EUID" -ne 0 ]; then
  echo "请以 Root 权限运行此脚本 (sudo bash setup_env.sh)"
  exit 1
fi

# 2. 更新软件源并安装依赖 (包含 ACL, Node.js, git, curl)
echo -e "${GREEN}1. 安装系统依赖 (ACL, Node.js, PM2)...${NC}"
apt-get update
apt-get install -y acl nodejs npm curl git

# 3. 安装 PM2
if ! command -v pm2 &> /dev/null; then
    npm install -g pm2
    echo "PM2 安装完成"
else
    echo "PM2 已安装，跳过"
fi

# 4. 安装 uv (并移动到公共目录)
echo -e "${GREEN}2. 安装 uv (Python 管理工具)...${NC}"
if [ ! -f "/usr/local/bin/uv" ]; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    # 将 uv 移动到 /usr/local/bin 以便所有用户可用
    mv /root/.local/bin/uv /usr/local/bin/uv 2>/dev/null || true
    mv /root/.local/bin/uvx /usr/local/bin/uvx 2>/dev/null || true
    echo "uv 安装并移动完成"
else
    echo "uv 已在公共目录，跳过"
fi

# 5. 创建专用用户 'pm2'
echo -e "${GREEN}3. 创建用户 'pm2'...${NC}"
if id "pm2" &>/dev/null; then
    echo "用户 'pm2' 已存在，跳过"
else
    useradd -m -s /bin/bash pm2
    echo "用户 'pm2' 创建成功"
fi

# 6. 创建项目目录 /home/projects
echo -e "${GREEN}4. 配置 /home/projects 目录与 ACL 权限...${NC}"
mkdir -p /home/projects

# 先把目录归属权给 pm2
chown -R pm2:pm2 /home/projects
chmod 770 /home/projects

# --- 核心魔法：配置 ACL ---
# -R : 递归应用
# -m : 修改权限
# u:pm2:rwx : 明确给 pm2 用户读写执行权限
setfacl -R -m u:pm2:rwx /home/projects

# -d : 设定 Default (默认) 权限
# 这意味着：未来在这个目录下创建的任何新文件/文件夹，
# 都会自动继承 u:pm2:rwx 这条规则！
setfacl -R -d -m u:pm2:rwx /home/projects

echo "ACL 权限规则已应用：无论谁在 /home/projects 创建文件，pm2 用户都拥有完全控制权。"

# 7. 配置 PM2 开机自启
echo -e "${GREEN}5. 配置 PM2 开机自启系统...${NC}"
# 生成 systemd 配置文件
pm2 startup systemd -u pm2 --hp /home/pm2 || true
# 注意：这里我们只是生成了配置，实际保存列表需要在你有项目运行后执行 pm2 save

echo -e "${BLUE}==============================================${NC}"
echo -e "${GREEN}✅ 环境配置全部完成！${NC}"
echo -e "${BLUE}==============================================${NC}"
echo -e "你可以开始部署了："
echo -e "1. 进入目录: cd /home/projects"
echo -e "2. 创建项目: mkdir my-bot (哪怕用 root 创建，pm2 用户也能读写)"
echo -e "3. 以后 PM2 配置文件(ecosystem.config.js) 请务必加上: ${GREEN}user: 'pm2'${NC}"
echo -e "${BLUE}==============================================${NC}"

# 测试 ACL (可选)
echo -e "正在进行权限测试..."
touch /home/projects/root_created_file.txt
if getfacl /home/projects/root_created_file.txt | grep -q "user:pm2:rwx"; then
    echo -e "${GREEN}测试通过：Root 创建的文件已自动赋予 pm2 权限。${NC}"
else
    echo -e "\033[0;31m测试警告：ACL 似乎未正确生效，请检查文件系统是否支持 ACL。${NC}"
fi
rm /home/projects/root_created_file.txt
