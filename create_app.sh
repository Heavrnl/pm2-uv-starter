#!/bin/bash
# 用法: new-pm2-app <项目名>

APP_NAME=$1
BASE_DIR="/home/projects"

if [ -z "$APP_NAME" ]; then
  echo "请提供项目名称"
  exit 1
fi

TARGET_DIR="$BASE_DIR/$APP_NAME"

# 1. 创建目录 (因为配置了 ACL，权限会自动正确)
mkdir -p "$TARGET_DIR"

# 2. 进入目录
cd "$TARGET_DIR"

# 3. 初始化 uv
/usr/local/bin/uv init

# 4. 生成标准化的 ecosystem.config.js
cat > ecosystem.config.js <<EOF
module.exports = {
  apps : [{
    name: "${APP_NAME}",
    cwd: "${TARGET_DIR}",
    user: "pm2",
    script: "/usr/local/bin/uv",
    args: "run main.py",
    interpreter: "none",
    env: { "PYTHONUNBUFFERED": "1" }
  }]
}
EOF

echo "✅ 项目 $APP_NAME 创建完成！"
echo "位置: $TARGET_DIR"
