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
        
        # 检查是否是 root 用户
        if [ "$EUID" -eq 0 ]; then
            log "ERROR" "Homebrew must not be run under sudo"
            return 1
        fi
        
        # 下载并安装 Homebrew
        if ! curl_with_timeout -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | bash; then
            log "ERROR" "Failed to install Homebrew"
            return 1
        fi
        
        # 验证安装
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

# 安装可���应用
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
        if ! curl_with_timeout -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | bash; then
            log "ERROR" "Failed to install Oh My Zsh"
            return 1
        fi
        
        # 安装插件
        log "INFO" "Installing Zsh plugins..."
        local plugins_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
        if [ ! -d "$plugins_dir/zsh-autosuggestions" ]; then
            git clone https://github.com/zsh-users/zsh-autosuggestions "$plugins_dir/zsh-autosuggestions"
        fi
        if [ ! -d "$plugins_dir/zsh-syntax-highlighting" ]; then
            git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$plugins_dir/zsh-syntax-highlighting"
        fi
    else
        log "INFO" "Oh My Zsh is already installed, skipping..."
    fi
}

# 安装 Vim 插件管理器
install_vim_plug() {
    if [ ! -f ~/.vim/autoload/plug.vim ]; then
        log "INFO" "Installing Vim-Plug..."
        if ! curl_with_timeout -fLo ~/.vim/autoload/plug.vim --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim; then
            log "ERROR" "Failed to install Vim-Plug"
            return 1
        fi
    else
        log "INFO" "Vim-Plug is already installed, skipping..."
    fi
}

# 安装 NVM
install_nvm() {
    if [ ! -d "$HOME/.nvm" ]; then
        log "INFO" "Installing NVM..."
        if ! curl_with_timeout -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash; then
            log "ERROR" "Failed to install NVM"
            return 1
        fi
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        
        # 安装 Node.js LTS
        if ! timeout $((CURL_TIMEOUT * 2)) nvm install --lts; then
            log "ERROR" "Failed to install Node.js LTS"
            return 1
        fi
        nvm use --lts
        
        # 安装全局包
        if check_cmd_exists npm; then
            npm install -g yarn
        fi
    else
        log "INFO" "NVM is already installed, skipping..."
    fi
}

# 配置 Git
setup_git() {
    log "INFO" "Configuring Git..."
    cp "${SCRIPT_DIR}/../common/gitconfig" ~/.gitconfig
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

# 主函数
main() {
    # 系统关键组件，失败需要退出
    setup_hostname || log "ERROR" "Hostname setup failed but continuing..."
    install_homebrew || { log "ERROR" "Homebrew installation failed, cannot continue"; exit 1; }
    setup_homebrew || log "ERROR" "Homebrew setup failed but continuing..."
    
    # 非关键组件，失败可以继续
    install_basic_tools || log "WARN" "Some basic tools installation failed but continuing..."
    install_dev_tools || log "WARN" "Some development tools installation failed but continuing..."
    install_pm2 || log "WARN" "PM2 installation failed but continuing..."
    install_basic_casks || log "WARN" "Some basic applications installation failed but continuing..."
    install_optional_apps || log "WARN" "Some optional applications installation failed but continuing..."
    install_oh_my_zsh || log "WARN" "Oh My Zsh installation failed but continuing..."
    install_vim_plug || log "WARN" "Vim-plug installation failed but continuing..."
    install_nvm || log "WARN" "NVM installation failed but continuing..."
    setup_git || log "WARN" "Git setup failed but continuing..."
    setup_mkcert || log "WARN" "mkcert setup failed but continuing..."
    
    log "INFO" "macOS setup completed! Some components might have failed to install, please check the logs for details."
}

# 执行主函数
main