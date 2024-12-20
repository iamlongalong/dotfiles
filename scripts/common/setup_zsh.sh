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
    REMOTE=https://mirrors.tuna.tsinghua.edu.cn/git/oh-my-zsh/raw/master/tools/install.sh
    
    sh -c "$(curl -fsSL $REMOTE)" || {
        echo "curl failed, trying wget..."
        sh -c "$(wget -O- $REMOTE)"
    }
    
    # 安装完成后，修改 Oh My Zsh 的更新源
    sed -i 's|https://github.com/ohmyzsh/ohmyzsh.git|https://mirrors.tuna.tsinghua.edu.cn/git/oh-my-zsh.git|g' ~/.oh-my-zsh/tools/upgrade.sh
fi

# 使用清华源安装插件
echo "Installing Zsh plugins..."
ZSH_CUSTOM=${ZSH_CUSTOM:-~/.oh-my-zsh/custom}

# zsh-autosuggestions
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    git clone https://mirrors.tuna.tsinghua.edu.cn/git/zsh-autosuggestions ${ZSH_CUSTOM}/plugins/zsh-autosuggestions
fi

# zsh-syntax-highlighting
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    git clone https://mirrors.tuna.tsinghua.edu.cn/git/zsh-syntax-highlighting ${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting
fi

echo "Zsh configuration completed!" 