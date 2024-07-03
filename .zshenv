# 检查 $HOME/.cargo/env 文件是否存在
if [ -f "$HOME/.cargo/env" ]; then
  # 检查 cargo 命令是否可用
  if command -v cargo > /dev/null 2>&1; then
    . "$HOME/.cargo/env"
    echo "Cargo environment loaded."
  else
    echo "Cargo command not found. Skipping environment load."
  fi
else
  echo "$HOME/.cargo/env not found. Skipping environment load."
fi

