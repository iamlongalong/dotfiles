#!/bin/bash

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "Setting up configurations..."

# 创建配置目录
mkdir -p ~/.config
mkdir -p ~/.vim

# 复制 Vim 配置
echo "Setting up Vim configuration..."
cp "${SCRIPT_DIR}/vimrc" ~/.vimrc

# 复制 Shell 函数和别名
echo "Setting up Shell functions and aliases..."
mkdir -p ~/.shell/aliases
cp "${SCRIPT_DIR}/functions.sh" ~/.shell/
cp "${SCRIPT_DIR}/functions_extra.sh" ~/.shell/
cp "${SCRIPT_DIR}/aliases/kubernetes.sh" ~/.shell/aliases/
echo "source ~/.shell/functions.sh" >> ~/.zshrc
echo "source ~/.shell/functions_extra.sh" >> ~/.zshrc
echo "source ~/.shell/aliases/kubernetes.sh" >> ~/.zshrc

# 安装 Vim 插件
echo "Installing Vim plugins..."
vim +PlugInstall +qall

# 设置 Node.js 环境
echo "Setting up Node.js environment..."
./node_setup.sh

# 设置 Python 环境
echo "Setting up Python environment..."
./python_setup.sh

# 创建常用目录
echo "Creating common directories..."
mkdir -p ~/code/{python,javascript}
mkdir -p ~/.scripts
mkdir -p ~/go/src/{gay,long}

echo "Configuration setup completed!" 