#!/bin/bash

echo "Starting macOS setup..."

# 显示路径信息
echo "Current working directory: $(pwd)"
echo "Script path: ${BASH_SOURCE[0]}"
echo "Script directory: $( dirname "${BASH_SOURCE[0]}" )"

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "Absolute script directory: ${SCRIPT_DIR}"

# 导入工具函数
source "${SCRIPT_DIR}/../common/utils.sh"

# 设置超时时间（秒）
CURL_TIMEOUT=30
BREW_INSTALL_TIMEOUT=600  # 10分钟
BREW_CASK_TIMEOUT=600    # 10分钟

# 检查命令是否存在
check_cmd_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 带超时的 curl 下载
curl_with_timeout() {
    curl --connect-timeout $CURL_TIMEOUT --max-time $((CURL_TIMEOUT * 10)) "$@"
}

# 配置主机名
setup_hostname() {
    echo "Current hostname: $(scutil --get ComputerName)"
    read -p "Do you want to change hostname? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter new hostname: " hostname
        if [ -n "$hostname" ]; then
            sudo scutil --set ComputerName "$hostname"
            sudo scutil --set HostName "$hostname"
            sudo scutil --set LocalHostName "$hostname"
            log "INFO" "Hostname has been updated to: $hostname"
            log "INFO" "Please reboot for changes to take full effect."
        fi
    fi
}

# 安装 Homebrew
install_homebrew() {
    if ! check_cmd_exists brew; then
        log "INFO" "Installing Homebrew..."
        
        if [ "$EUID" -eq 0 ]; then
            log "ERROR" "Homebrew must not be run under sudo"
            return 1
        fi
        
        # 使用清华大学镜像源安装 Homebrew
        export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
        export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
        export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
        
        if ! /bin/bash -c "$(curl -fsSL https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/install/master/install.sh)"; then
            log "ERROR" "Failed to install Homebrew"
            return 1
        fi
        
        if ! check_cmd_exists brew; then
            log "ERROR" "Homebrew installation verification failed"
            return 1
        fi
    else
        log "INFO" "Homebrew is already installed, skipping..."
    fi
}

# 配置 Homebrew
setup_homebrew() {
    if check_cmd_exists brew; then
        log "INFO" "Configuring Homebrew mirrors..."
        git -C "$(brew --repo)" remote set-url origin https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git || true
        git -C "$(brew --repo homebrew/core)" remote set-url origin https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git || true
        git -C "$(brew --repo homebrew/cask)" remote set-url origin https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-cask.git || true
        
        log "INFO" "Updating Homebrew..."
        if ! timeout $BREW_INSTALL_TIMEOUT brew update; then
            log "ERROR" "Failed to update Homebrew"
            return 1
        fi
    fi
}

# 安装基础工具
install_basic_tools() {
    log "INFO" "Installing common tools..."
    local tools=(
        git wget curl tree jq ripgrep fd bat exa
        diff-so-fancy fzf lazydocker asciiquarium
        ffmpeg youtube-dl mkcert
    )
    
    for tool in "${tools[@]}"; do
        if ! check_cmd_exists "$tool"; then
            log "INFO" "Installing $tool..."
            if ! timeout $BREW_INSTALL_TIMEOUT brew install "$tool"; then
                log "ERROR" "Failed to install $tool"
            fi
        else
            log "INFO" "$tool is already installed, skipping..."
        fi
    done
}

# 安装开发工具
install_dev_tools() {
    log "INFO" "Installing development tools..."
    local tools=(go pyenv poetry)
    
    for tool in "${tools[@]}"; do
        if ! check_cmd_exists "$tool"; then
            log "INFO" "Installing $tool..."
            if ! timeout $BREW_INSTALL_TIMEOUT brew install "$tool"; then
                log "ERROR" "Failed to install $tool"
            fi
        else
            log "INFO" "$tool is already installed, skipping..."
        fi
    done
}

# 安装 PM2
install_pm2() {
    if ! check_cmd_exists pm2; then
        log "INFO" "Installing PM2..."
        if ! timeout $BREW_INSTALL_TIMEOUT npm install -g pm2; then
            log "ERROR" "Failed to install PM2"
            return 1
        fi
    else
        log "INFO" "PM2 is already installed, skipping..."
    fi
}

# 安装基础 Cask 应用
install_basic_casks() {
    log "INFO" "Installing basic applications..."
    local casks=(
        visual-studio-code iterm2 docker postman
        rectangle google-chrome arc utools keka balenaetcher
    )
    
    for cask in "${casks[@]}"; do
        if ! brew list --cask "$cask" &>/dev/null; then
            log "INFO" "Installing $cask..."
            if ! timeout $BREW_CASK_TIMEOUT brew install --cask "$cask"; then
                log "ERROR" "Failed to install $cask"
            fi
        else
            log "INFO" "$cask is already installed, skipping..."
        fi
    done
}

# 安装可选应用
install_optional_app() {
    local app_name=$1
    local cask_name=$2
    
    if ! brew list --cask "$cask_name" &>/dev/null; then
        read -p "Do you want to install $app_name? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "INFO" "Installing $app_name..."
            if ! timeout $BREW_CASK_TIMEOUT brew install --cask "$cask_name"; then
                log "ERROR" "Failed to install $app_name"
                return 1
            fi
        fi
    else
        log "INFO" "$app_name is already installed, skipping..."
    fi
}

# 安装可选应用
install_optional_apps() {
    log "INFO" "Installing optional applications..."
    install_optional_app "Feishu" "feishu"
    install_optional_app "WeChat" "wechat"
    install_optional_app "PicGo" "picgo"
    install_optional_app "Obsidian" "obsidian"
}

# 安装 Oh My Zsh
install_oh_my_zsh() {
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        log "INFO" "Installing Oh My Zsh..."
        if ! brew install zsh; then
            log "ERROR" "Failed to install Zsh"
            return 1
        fi
        
        # 使用 brew 安装 oh-my-zsh
        if ! brew install oh-my-zsh; then
            log "ERROR" "Failed to install Oh My Zsh"
            return 1
        fi
        
        # 安装插件
        log "INFO" "Installing Zsh plugins..."
        brew install zsh-autosuggestions
        brew install zsh-syntax-highlighting
    else
        log "INFO" "Oh My Zsh is already installed, skipping..."
    fi
}

# 安装 Vim 插件管理器
install_vim_plug() {
    if ! check_cmd_exists vim; then
        brew install vim
    fi
    
    if [ ! -f ~/.vim/autoload/plug.vim ]; then
        log "INFO" "Installing Vim-Plug..."
        brew install vim-plug
    else
        log "INFO" "Vim-Plug is already installed, skipping..."
    fi
}

# 安装 NVM
install_nvm() {
    if [ ! -d "$HOME/.nvm" ]; then
        log "INFO" "Installing NVM..."
        if ! brew install nvm; then
            log "ERROR" "Failed to install NVM"
            return 1
        fi
        
        # 加载 NVM
        export NVM_DIR="$HOME/.nvm"
        [ -s "$(brew --prefix nvm)/nvm.sh" ] && \. "$(brew --prefix nvm)/nvm.sh"
        
        # 安装 Node.js LTS
        if ! timeout $((CURL_TIMEOUT * 2)) nvm install --lts; then
            log "ERROR" "Failed to install Node.js LTS"
            return 1
        fi
        nvm use --lts
        
        # 使用 brew 安装 yarn
        if check_cmd_exists npm; then
            brew install yarn
        fi
    else
        log "INFO" "NVM is already installed, skipping..."
    fi
}

# 配置 Git
setup_git() {
    log "INFO" "Setting up basic Git configuration..."
    
    # 如果用户名和邮箱未设置，提示用户输入
    if ! git config --global user.name > /dev/null; then
        read -p "Enter your Git user name: " git_user_name
        git config --global user.name "$git_user_name"
    fi
    
    if ! git config --global user.email > /dev/null; then
        read -p "Enter your Git email: " git_user_email
        git config --global user.email "$git_user_email"
    fi
    
    log "INFO" "Basic Git configuration completed"
    log "INFO" "Note: Detailed Git configuration will be managed by chezmoi"
}

# 设置 mkcert
setup_mkcert() {
    if check_cmd_exists mkcert; then
        log "INFO" "Setting up mkcert..."
        chmod +x "${SCRIPT_DIR}/../common/setup_mkcert.sh"
        if ! timeout $((CURL_TIMEOUT * 2)) "${SCRIPT_DIR}/../common/setup_mkcert.sh"; then
            log "ERROR" "Failed to setup mkcert"
            return 1
        fi
    fi
}

# 添加缺失的函数
install_xcode_cli() {
    if ! xcode-select -p &>/dev/null; then
        log "INFO" "Installing Xcode Command Line Tools..."
        if ! xcode-select --install; then
            log "ERROR" "Failed to install Xcode Command Line Tools"
            return 1
        fi
    else
        log "INFO" "Xcode Command Line Tools already installed"
    fi
}

install_brew_tools() {
    install_basic_tools
    install_dev_tools
    install_basic_casks
    install_optional_apps
}

install_go() {
    if ! check_cmd_exists go; then
        log "INFO" "Installing Go..."
        if ! brew install go; then
            log "ERROR" "Failed to install Go"
            return 1
        fi
    fi
}

setup_python() {
    if ! check_cmd_exists python3; then
        log "INFO" "Installing Python..."
        if ! brew install python; then
            log "ERROR" "Failed to install Python"
            return 1
        fi
    fi
}

install_docker() {
    if ! check_cmd_exists docker; then
        log "INFO" "Installing Docker..."
        if ! brew install --cask docker; then
            log "ERROR" "Failed to install Docker"
            return 1
        fi
    fi
}

install_vscode() {
    if ! brew list --cask visual-studio-code &>/dev/null; then
        log "INFO" "Installing Visual Studio Code..."
        if ! brew install --cask visual-studio-code; then
            log "ERROR" "Failed to install Visual Studio Code"
            return 1
        fi
    fi
}

install_zsh() {
    if ! check_cmd_exists zsh; then
        log "INFO" "Installing Zsh..."
        if ! brew install zsh; then
            log "ERROR" "Failed to install Zsh"
            return 1
        fi
    fi
}

# 主函数
main() {
    # 系统关键组件，失败需要退出
    setup_hostname || log "ERROR" "Hostname setup failed but continuing..."
    install_xcode_cli || { log "ERROR" "XCode CLI tools installation failed"; exit 1; }
    install_homebrew || { log "ERROR" "Homebrew installation failed"; exit 1; }
    
    # 非关键组件，失败可以继续
    install_brew_tools || log "WARN" "Some brew tools installation failed but continuing..."
    install_nvm || log "WARN" "NVM installation failed but continuing..."
    install_go || log "WARN" "Go installation failed but continuing..."
    setup_python || log "WARN" "Python setup failed but continuing..."
    install_docker || log "WARN" "Docker installation failed but continuing..."
    install_vscode || log "WARN" "VS Code installation failed but continuing..."
    install_zsh || log "WARN" "Zsh installation failed but continuing..."
    install_vim_plug || log "WARN" "Vim-plug installation failed but continuing..."
    setup_git || log "WARN" "Git setup failed but continuing..."
    
    log "INFO" "macOS setup completed!"
    log "INFO" "Please use chezmoi to manage your dotfiles:"
    log "INFO" "1. Initialize: chezmoi init <your-dotfiles-repo>"
    log "INFO" "2. Apply: chezmoi apply"
}

# 执行主函数
main