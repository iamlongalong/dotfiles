#!/bin/bash

echo "Setting up Zsh configuration..."

# 创建配置目录
mkdir -p ~/.config/zsh/{exports,aliases,functions,paths,completions}

# 复制配置文件
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cp -r "${SCRIPT_DIR}/zsh/main.zsh" ~/.zshrc
cp -r "${SCRIPT_DIR}/zsh/paths/"* ~/.config/zsh/paths/
cp -r "${SCRIPT_DIR}/zsh/aliases/"* ~/.config/zsh/aliases/
cp -r "${SCRIPT_DIR}/zsh/exports/"* ~/.config/zsh/exports/

# 安装 Oh My Zsh（如果未安装）
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing Oh My Zsh..."
    cd /tmp
    git clone https://mirrors.tuna.tsinghua.edu.cn/git/ohmyzsh.git
    cd ohmyzsh/tools
    REMOTE=https://mirrors.tuna.tsinghua.edu.cn/git/ohmyzsh.git sh install.sh
    cd -
    rm -rf /tmp/ohmyzsh
fi

# 安装插件
echo "Installing Zsh plugins..."
ZSH_CUSTOM=${ZSH_CUSTOM:-~/.oh-my-zsh/custom}

# zsh-autosuggestions
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    echo "Installing zsh-autosuggestions..."
    git clone https://mirrors.tuna.tsinghua.edu.cn/git/zsh-users/zsh-autosuggestions.git ${ZSH_CUSTOM}/plugins/zsh-autosuggestions
fi

# zsh-syntax-highlighting
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    echo "Installing zsh-syntax-highlighting..."
    git clone https://mirrors.tuna.tsinghua.edu.cn/git/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting
fi

echo "Zsh configuration completed!" 