#!/bin/bash

echo "Starting macOS setup..."

# 配置主机名
setup_hostname() {
    echo "Current hostname: $(scutil --get ComputerName)"
    read -p "Do you want to change hostname? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter new hostname: " hostname
        if [ -n "$hostname" ]; then
            # 设置三种主机名
            sudo scutil --set ComputerName "$hostname"
            sudo scutil --set HostName "$hostname"
            sudo scutil --set LocalHostName "$hostname"
            echo "Hostname has been updated to: $hostname"
        fi
    fi
}

# 执行主机名设置
setup_hostname

# 检查是否已安装 Homebrew
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# 配置 Homebrew 国内源
echo "Configuring Homebrew mirrors..."
git -C "$(brew --repo)" remote set-url origin https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git
git -C "$(brew --repo homebrew/core)" remote set-url origin https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git
git -C "$(brew --repo homebrew/cask)" remote set-url origin https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-cask.git
brew update

# 安装常用工具
echo "Installing common tools..."
brew install \
    git \
    wget \
    curl \
    tree \
    jq \
    ripgrep \
    fd \
    bat \
    exa \
    diff-so-fancy \
    fzf \
    lazydocker \
    asciiquarium \
    ffmpeg \
    youtube-dl \
    mkcert

# 安装开发工具
echo "Installing development tools..."
brew install \
    go \
    pyenv \
    poetry

# 安装 PM2
echo "Installing PM2..."
npm install -g pm2

# 安装基础 Cask 应用
echo "Installing basic applications..."
brew install --cask \
    visual-studio-code \
    iterm2 \
    docker \
    postman \
    rectangle \
    google-chrome \
    arc \
    utools \
    keka \
    balenaetcher

# 可选应用安装
install_optional_apps() {
    local app_name=$1
    local cask_name=$2
    read -p "Do you want to install $app_name? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Installing $app_name..."
        brew install --cask "$cask_name"
    fi
}

echo "Optional applications installation..."
install_optional_apps "Feishu" "feishu"
install_optional_apps "WeChat" "wechat"
install_optional_apps "PicGo" "picgo"
install_optional_apps "Obsidian" "obsidian"

# 安装 Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# 安装 Zsh 插件
echo "Installing Zsh plugins..."
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# 安装 Vim 插件管理器
echo "Installing Vim-Plug..."
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# 安装 NVM
echo "Installing NVM..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install --lts
nvm use --lts
npm install -g yarn

# 配置 Python 环境
echo "Configuring Python environment..."
pyenv install 3.11.4
pyenv global 3.11.4
pip install --upgrade pip

# 配置 Git
echo "Configuring Git..."
cp ../common/gitconfig ~/.gitconfig

# 设置 mkcert
echo "Setting up mkcert..."
chmod +x ../common/setup_mkcert.sh
../common/setup_mkcert.sh

echo "macOS setup completed!" 