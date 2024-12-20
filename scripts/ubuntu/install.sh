#!/bin/bash

echo "Starting Ubuntu setup..."

# 导入工具函数
source ../common/utils.sh

# 设置超时时间（秒）
CURL_TIMEOUT=30
WGET_TIMEOUT=300
APT_TIMEOUT=600  # 10分钟

# 检查命令是否存在
check_cmd_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 带超时的 curl 下载
curl_with_timeout() { # max 5 minutes
    curl --connect-timeout $CURL_TIMEOUT --max-time $((CURL_TIMEOUT * 10)) "$@"
}

# 带超时的 wget 下载
wget_with_timeout() { # max 5 minutes
    wget --timeout=$WGET_TIMEOUT --tries=3 "$@"
}

# 配置主机名
setup_hostname() {
    echo "Current hostname: $(hostname)"
    read -p "Do you want to change hostname? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter new hostname: " hostname
        if [ -n "$hostname" ]; then
            echo "$hostname" | sudo tee /etc/hostname
            sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$hostname/g" /etc/hosts
            sudo hostnamectl set-hostname "$hostname"
            log "INFO" "Hostname has been updated to: $hostname"
            log "INFO" "Please reboot for changes to take full effect."
        fi
    fi
}

# 更新系统
update_system() {
    log "INFO" "Updating system..."
    if ! timeout $APT_TIMEOUT sudo apt update && timeout $APT_TIMEOUT sudo apt upgrade -y; then
        log "ERROR" "System update failed"
        return 1
    fi
}

# 安装基础工具
install_basic_tools() {
    log "INFO" "Installing basic tools..."
    local tools=(
        git curl wget tree jq ripgrep fd-find bat build-essential
        software-properties-common apt-transport-https ca-certificates
        gnupg lsb-release screen vim ffmpeg proxychains4
    )
    
    for tool in "${tools[@]}"; do
        if ! check_cmd_exists "$tool"; then
            log "INFO" "Installing $tool..."
            if ! timeout $APT_TIMEOUT sudo apt install -y "$tool"; then
                log "ERROR" "Failed to install $tool"
            fi
        else
            log "INFO" "$tool is already installed, skipping..."
        fi
    done
}

# 配置 proxychains4
setup_proxychains() {
    if [ ! -f /etc/proxychains4.conf.bak ]; then
        log "INFO" "Configuring proxychains4..."
        sudo cp /etc/proxychains4.conf /etc/proxychains4.conf.bak
        sudo tee /etc/proxychains4.conf > /dev/null << 'EOF'
# proxychains.conf  VER 4.x
strict_chain
proxy_dns
remote_dns_subnet 224
tcp_read_time_out 15000
tcp_connect_time_out 8000
localnet 127.0.0.0/255.0.0.0
localnet 10.0.0.0/255.0.0.0
localnet 172.16.0.0/255.240.0.0
localnet 192.168.0.0/255.255.0.0

[ProxyList]
socks5 127.0.0.1 7890
http 127.0.0.1 7890
EOF
    else
        log "INFO" "proxychains4 is already configured, skipping..."
    fi
}

# 安装 youtube-dl
install_youtube_dl() {
    if ! check_cmd_exists youtube-dl; then
        log "INFO" "Installing youtube-dl..."
        if ! curl_with_timeout -L https://yt-dl.org/downloads/latest/youtube-dl -o /tmp/youtube-dl; then
            log "ERROR" "Failed to download youtube-dl"
            return 1
        fi
        sudo mv /tmp/youtube-dl /usr/local/bin/
        sudo chmod a+rx /usr/local/bin/youtube-dl
    else
        log "INFO" "youtube-dl is already installed, skipping..."
    fi
}

# 安装 Linuxbrew
install_linuxbrew() {
    if ! check_cmd_exists brew; then
        log "INFO" "Installing Linuxbrew..."
        
        # 检查是否是 root 用户
        if [ "$EUID" -eq 0 ]; then
            log "ERROR" "Linuxbrew must not be run under sudo"
            return 1
        fi
        
        # 安装依赖
        log "INFO" "Installing Linuxbrew dependencies..."
        sudo apt-get install -y build-essential procps curl file git
        
        # 下载并安装 Linuxbrew
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # 检查安装结果
        if [ ! -d "/home/linuxbrew/.linuxbrew" ]; then
            log "ERROR" "Linuxbrew installation failed"
            return 1
        fi
        
        # 配置环境变量
        test -d ~/.linuxbrew && eval "$(~/.linuxbrew/bin/brew shellenv)"
        test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        
        # 添加到 shell 配置文件
        if [ -f ~/.zshrc ]; then
            echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.zshrc
        fi
        if [ -f ~/.bashrc ]; then
            echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
        fi
        if [ -f ~/.profile ]; then
            echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.profile
        fi
        
        # 刷新环境变量
        export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
        
        # 验证安装
        if ! check_cmd_exists brew; then
            log "ERROR" "Linuxbrew installation verification failed"
            return 1
        fi
        
        # 配置国内源
        log "INFO" "Configuring Homebrew mirrors..."
        git -C "$(brew --repo)" remote set-url origin https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git || true
        git -C "$(brew --repo homebrew/core)" remote set-url origin https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git || true
        
        # 更新 Homebrew
        log "INFO" "Updating Homebrew..."
        brew update || true
    else
        log "INFO" "Linuxbrew is already installed, skipping..."
    fi
}

# 安装 Homebrew 工具
install_brew_tools() {
    # 确保 brew 命令可用
    if ! check_cmd_exists brew; then
        if [ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
            eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        else
            log "ERROR" "Homebrew is not properly installed"
            return 1
        fi
    fi
    
    if check_cmd_exists brew; then
        log "INFO" "Installing additional tools with Homebrew..."
        local tools=(lazydocker asciiquarium pyenv mkcert)
        for tool in "${tools[@]}"; do
            if ! check_cmd_exists "$tool"; then
                log "INFO" "Installing $tool..."
                if ! timeout $((CURL_TIMEOUT * 2)) brew install "$tool"; then
                    log "ERROR" "Failed to install $tool"
                fi
            else
                log "INFO" "$tool is already installed, skipping..."
            fi
        done
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
            npm install -g yarn pm2
        fi
    else
        log "INFO" "NVM is already installed, skipping..."
    fi
}

# 安装 Go
install_go() {
    if ! check_cmd_exists go; then
        log "INFO" "Installing Go..."
        local go_file="go1.21.5.linux-amd64.tar.gz"
        if ! wget_with_timeout https://go.dev/dl/$go_file -O /tmp/$go_file; then
            log "ERROR" "Failed to download Go"
            return 1
        fi
        sudo rm -rf /usr/local/go
        sudo tar -C /usr/local -xzf /tmp/$go_file
        rm /tmp/$go_file
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.profile
    else
        log "INFO" "Go is already installed, skipping..."
    fi
}

# 配置 Python 环境
setup_python() {
    if check_cmd_exists pyenv; then
        log "INFO" "Configuring Python environment..."
        eval "$(pyenv init -)"
        if ! pyenv versions | grep -q "3.11.4"; then
            if ! timeout $((CURL_TIMEOUT * 4)) pyenv install 3.11.4; then
                log "ERROR" "Failed to install Python 3.11.4"
                return 1
            fi
        fi
        pyenv global 3.11.4
        
        if check_cmd_exists pip; then
            pip install --upgrade pip
            if ! check_cmd_exists poetry; then
                pip install poetry
            fi
        fi
    fi
}

# 安装 Docker
install_docker() {
    if ! check_cmd_exists docker; then
        log "INFO" "Installing Docker..."
        if ! curl_with_timeout -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg; then
            log "ERROR" "Failed to download Docker GPG key"
            return 1
        fi
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        if ! timeout $APT_TIMEOUT sudo apt update && timeout $APT_TIMEOUT sudo apt install -y docker-ce docker-ce-cli containerd.io; then
            log "ERROR" "Failed to install Docker"
            return 1
        fi
        sudo usermod -aG docker $USER
    else
        log "INFO" "Docker is already installed, skipping..."
    fi
}

# 安装 VS Code
install_vscode() {
    if ! check_cmd_exists code; then
        log "INFO" "Installing Visual Studio Code..."
        if ! wget_with_timeout -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/packages.microsoft.gpg; then
            log "ERROR" "Failed to download VS Code GPG key"
            return 1
        fi
        sudo install -o root -g root -m 644 /tmp/packages.microsoft.gpg /etc/apt/trusted.gpg.d/
        echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
        rm -f /tmp/packages.microsoft.gpg
        
        if ! timeout $APT_TIMEOUT sudo apt update && timeout $APT_TIMEOUT sudo apt install -y code; then
            log "ERROR" "Failed to install VS Code"
            return 1
        fi
    else
        log "INFO" "VS Code is already installed, skipping..."
    fi
}

# 安装 Zsh 和 Oh My Zsh
install_zsh() {
    if ! check_cmd_exists zsh; then
        log "INFO" "Installing Zsh..."
        if ! timeout $APT_TIMEOUT sudo apt install -y zsh; then
            log "ERROR" "Failed to install Zsh"
            return 1
        fi
    fi
    
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

# 配置 Git
setup_git() {
    log "INFO" "Configuring Git..."
    cp ../common/gitconfig ~/.gitconfig
}

# 设置 mkcert
setup_mkcert() {
    if check_cmd_exists mkcert; then
        log "INFO" "Setting up mkcert..."
        chmod +x ../common/setup_mkcert.sh
        if ! timeout $((CURL_TIMEOUT * 2)) ../common/setup_mkcert.sh; then
            log "ERROR" "Failed to setup mkcert"
            return 1
        fi
    fi
}

# 主函数
main() {
    setup_hostname
    update_system
    install_basic_tools
    setup_proxychains
    install_youtube_dl
    install_linuxbrew
    install_brew_tools
    install_nvm
    install_go
    setup_python
    install_docker
    install_vscode
    install_zsh
    install_vim_plug
    setup_git
    setup_mkcert
    
    log "INFO" "Ubuntu setup completed!"
}

# 执行主函数
main 