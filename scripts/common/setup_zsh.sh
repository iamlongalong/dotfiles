#!/bin/bash

echo "Setting up Zsh configuration..."

# 创建配置目录
mkdir -p ~/.config/zsh/{exports,aliases,functions,paths,completions}

# 复制配置文件
cp zsh/main.zsh ~/.zshrc
cp zsh/paths/* ~/.config/zsh/paths/
cp zsh/aliases/* ~/.config/zsh/aliases/
cp zsh/exports/* ~/.config/zsh/exports/

# 安装 Oh My Zsh（如果未安装）
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# 安装插件
echo "Installing Zsh plugins..."
ZSH_CUSTOM=${ZSH_CUSTOM:-~/.oh-my-zsh/custom}

# zsh-autosuggestions
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM}/plugins/zsh-autosuggestions
fi

# zsh-syntax-highlighting
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting
fi

echo "Zsh configuration completed!" 