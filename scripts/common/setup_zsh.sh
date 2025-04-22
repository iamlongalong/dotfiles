#!/bin/bash

echo "Setting up Zsh configuration..."

# 创建配置目录
mkdir -p ~/.config/zsh/{exports,aliases,functions,themes,paths,completions}

# 复制配置文件
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cp -r "${SCRIPT_DIR}/zsh/main.zsh" ~/.zshrc
cp -r "${SCRIPT_DIR}/zsh/paths/"* ~/.config/zsh/paths/
cp -r "${SCRIPT_DIR}/zsh/aliases/"* ~/.config/zsh/aliases/
cp -r "${SCRIPT_DIR}/zsh/exports/"* ~/.config/zsh/exports/
cp -r "${SCRIPT_DIR}/zsh/themes/"* ~/.config/zsh/themes/

# 安装 Oh My Zsh（如果未安装）
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing Oh My Zsh..."
    cd /tmp
    git clone https://mirrors.tuna.tsinghua.edu.cn/git/ohmyzsh.git
    cd ohmyzsh/tools
    # 使用环境变量跳过交互式提示
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes REMOTE=https://mirrors.tuna.tsinghua.edu.cn/git/ohmyzsh.git sh install.sh
    cd -
    rm -rf /tmp/ohmyzsh
fi

# 安装插件
echo "Installing Zsh plugins..."
ZSH_CUSTOM=${ZSH_CUSTOM:-~/.oh-my-zsh/custom}

# zsh-autosuggestions
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    echo "Installing zsh-autosuggestions..."
    timeout 30 git clone https://github.com/zsh-users/zsh-autosuggestions.git ${ZSH_CUSTOM}/plugins/zsh-autosuggestions
fi

# zsh-syntax-highlighting
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    echo "Installing zsh-syntax-highlighting..."
    timeout 30 git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting
fi

# 安装 oh-my-zsh-custom-theme
for theme in $(ls ~/.config/zsh/themes/); do
    if [ ! -d "$ZSH_CUSTOM/themes/$theme" ]; then
        echo "Installing oh-my-zsh-custom-theme: $theme..."
        cp ~/.config/zsh/themes/$theme ~/.oh-my-zsh/custom/themes/
    fi
done

echo "Zsh configuration completed!" 