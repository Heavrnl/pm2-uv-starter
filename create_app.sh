#!/bin/bash
# 用法: 
# 1. new-pm2-app my-bot  (直接指定)
# 2. new-pm2-app         (不指定，脚本会问你)

APP_NAME=$1
BASE_DIR="/home/projects"

# --- 🟢 改进点：如果没有参数，改为交互式询问 ---
if [ -z "$APP_NAME" ]; then
  echo "🤔 你没有指定项目名称。"
  # read -p 会暂停脚本，等待你输入并按回车
  read -p "👉 请输入项目名称 (例如 my-bot): " APP_NAME
fi

# --- 二次检查：防止用户被问了之后还是只敲了个回车 ---
if [ -z "$APP_NAME" ]; then
  echo "❌ 错误: 必须提供项目名称才能继续！"
  exit 1
fi

TARGET_DIR="$BASE_DIR/$APP_NAME"

# 检查目录是否存在
if [ -d "$TARGET_DIR" ]; then
  echo "❌ 错误: 目录 $TARGET_DIR 已存在。"
  exit 1
fi

echo "🚀 正在初始化项目: $APP_NAME ..."

# 1. 初始化 uv 项目
/usr/local/bin/uv init "$TARGET_DIR" --name "$APP_NAME" --python 3.12

# 2. 进入目录
cd "$TARGET_DIR"

# 3. 把 hello.py 改名为 main.py
if [ -f "hello.py" ]; then
    mv hello.py main.py
    sed -i 's/Hello from/Monitor Service Started:/g' main.py
fi

# 4. 生成 ecosystem.config.js
echo "📝 生成 PM2 配置文件..."
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

# 5. 权限兜底
chown -R pm2:pm2 "$TARGET_DIR"

echo "✅ 项目 $APP_NAME 创建成功！"
echo "📂 位置: $TARGET_DIR"
echo "👉 下一步: cd $TARGET_DIR && uv add requests"
