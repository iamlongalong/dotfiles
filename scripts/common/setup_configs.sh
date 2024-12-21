#!/bin/bash

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# 定义配置目录
CONFIG_DIRS=(
    ~/.config
    ~/.config/zsh/{functions,aliases}
    ~/.vim
    ~/.shell/aliases
    ~/.scripts
    ~/code/{python,javascript}
    ~/go/src/{gay,long}
)

# 定义配置文件映射
declare -A CONFIG_FILES=(
    ["${SCRIPT_DIR}/functions.sh"]="$HOME/.config/zsh/functions/common.zsh"
    ["${SCRIPT_DIR}/functions_extra.sh"]="$HOME/.config/zsh/functions/extra.zsh"
    ["${SCRIPT_DIR}/aliases/kubernetes.sh"]="$HOME/.config/zsh/aliases/kubernetes.zsh"
)

# 错误处理函数
handle_error() {
    echo "Error: $1" >&2
    exit 1
}

# 创建必要的目录
echo "Creating configuration directories..."
for dir in "${CONFIG_DIRS[@]}"; do
    mkdir -p "$dir" || handle_error "Failed to create directory: $dir"
done

# 复制配置文件
echo "Copying configuration files..."
for src in "${!CONFIG_FILES[@]}"; do
    dst="${CONFIG_FILES[$src]}"
    if [ -f "$src" ]; then
        cp "$src" "$dst" || handle_error "Failed to copy: $src -> $dst"
        echo "Copied: $src -> $dst"
    else
        echo "Warning: Source file not found: $src"
    fi
done

sudo apt-get install -y python3 python3-pip || handle_error "Failed to install Python3"

# 设置 Node.js 环境
echo "Setting up Node.js environment..."
if [ -f "${SCRIPT_DIR}/node_setup.sh" ]; then
    bash ${SCRIPT_DIR}/node_setup.sh || handle_error "Node.js setup failed"
else
    handle_error "node_setup.sh not found"
fi

# 设置 Python 环境
echo "Setting up Python environment..."
if [ -f "${SCRIPT_DIR}/python_setup.sh" ]; then
    bash ${SCRIPT_DIR}/python_setup.sh || handle_error "Python setup failed"
else
    handle_error "python_setup.sh not found"
fi

echo "Configuration setup completed!" 