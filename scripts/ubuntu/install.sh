#!/bin/bash

echo "Starting Ubuntu setup..."

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

# 配�� proxychains4
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
            log "WARN" "Skipping youtube-dl installation"
            return 0  # 返回 0 表示不中断整体安装流程
        fi
        sudo mv /tmp/youtube-dl /usr/local/bin/
        sudo chmod a+rx /usr/local/bin/youtube-dl
    else
        log "INFO" "youtube-dl is already installed, skipping..."
    fi
}

# 获取普通用户名
get_normal_user() {
    # 获取第一个非 root 的用户，通常是主用户
    local user=$(who | grep -v root | head -n 1 | awk '{print $1}')
    if [ -z "$user" ]; then
        # 如果 who 命令没有结果，尝试从 /home 目录获取
        user=$(ls -ld /home/* | grep -v root | head -n 1 | awk '{print $3}')
    fi
    echo "$user"
}

# 以普通用户身份运行命令
run_as_normal_user() {
    local cmd="$1"
    local user=$(get_normal_user)
    
    if [ -z "$user" ]; then
        log "ERROR" "No normal user found to run Linuxbrew installation"
        return 1
    fi
    
    # 如果当前已经是目标用户，直接运行命令
    if [ "$USER" = "$user" ]; then
        eval "$cmd"
        return $?
    fi
    
    # 否则，使用 su 切换到目标用户运行命令
    log "INFO" "Running command as user: $user"
    su - "$user" -c "$cmd"
    return $?
}

# 安装 Linuxbrew
install_linuxbrew() {
    if ! check_cmd_exists brew; then
        log "INFO" "Installing Linuxbrew..."
        
        # 如果是 root 用户，切换到普通用户安装
        if [ "$EUID" -eq 0 ]; then
            local normal_user=$(get_normal_user)
            if [ -z "$normal_user" ]; then
                log "ERROR" "No normal user found to install Linuxbrew"
                return 1
            fi
            
            # 安装依赖
            log "INFO" "Installing Linuxbrew dependencies..."
            apt-get install -y build-essential procps curl file git
            
            # 准备安装命令
            local install_cmd='NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
            
            # 以普通用户身份运行安装命令
            log "INFO" "Installing Linuxbrew as user: $normal_user"
            if ! run_as_normal_user "$install_cmd"; then
                log "ERROR" "Failed to install Linuxbrew as user: $normal_user"
                return 1
            fi
            
            # 配置环境变量
            local config_cmd='test -d ~/.linuxbrew && eval "$(~/.linuxbrew/bin/brew shellenv)"; test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
            run_as_normal_user "$config_cmd"
            
            # 添加到用户的 shell 配置文件
            local shell_config='
if [ -d "/home/linuxbrew/.linuxbrew" ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi'
            run_as_normal_user "echo '$shell_config' >> ~/.bashrc"
            run_as_normal_user "echo '$shell_config' >> ~/.zshrc"
            run_as_normal_user "echo '$shell_config' >> ~/.profile"
            
            # 配置国内源
            local mirror_cmd='
git -C "$(brew --repo)" remote set-url origin https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git || true
git -C "$(brew --repo homebrew/core)" remote set-url origin https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git || true'
            run_as_normal_user "$mirror_cmd"
            
            # 更新 Homebrew
            run_as_normal_user "brew update || true"
            
            log "INFO" "Linuxbrew installation completed successfully"
            return 0
        else
            # 当前已经是普通用户，直接安装
            # 安装依赖
            log "INFO" "Installing Linuxbrew dependencies..."
            sudo apt-get install -y build-essential procps curl file git
            
            # 下载并安装 Linuxbrew
            NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
                log "ERROR" "Failed to install Linuxbrew"
                return 1
            }
            
            # 检查安装结果
            if [ ! -d "/home/linuxbrew/.linuxbrew" ]; then
                log "ERROR" "Linuxbrew installation failed - directory not found"
                return 1
            fi
            
            # 配置环境变量
            test -d ~/.linuxbrew && eval "$(~/.linuxbrew/bin/brew shellenv)"
            test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
            
            # 添加到 shell 配置文件
            local shell_config='
if [ -d "/home/linuxbrew/.linuxbrew" ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi'
            echo "$shell_config" >> ~/.bashrc
            echo "$shell_config" >> ~/.zshrc
            echo "$shell_config" >> ~/.profile
            
            # 配置国内源
            log "INFO" "Configuring Homebrew mirrors..."
            git -C "$(brew --repo)" remote set-url origin https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git || true
            git -C "$(brew --repo homebrew/core)" remote set-url origin https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git || true
            
            # 更新 Homebrew
            log "INFO" "Updating Homebrew..."
            brew update || true
            
            log "INFO" "Linuxbrew installation completed successfully"
            return 0
        fi
    else
        log "INFO" "Linuxbrew is already installed, skipping..."
        return 0
    fi
}

# 安装 Homebrew 工具
install_brew_tools() {
    # 如果 brew 命令不存在，跳过安装
    if ! check_cmd_exists brew; then
        log "WARN" "Homebrew is not installed, skipping brew tools installation"
        return 0
    fi
    
    log "INFO" "Installing additional tools with Homebrew..."
    local tools=(lazydocker asciiquarium pyenv mkcert)
    local failed=0
    
    for tool in "${tools[@]}"; do
        if ! check_cmd_exists "$tool"; then
            log "INFO" "Installing $tool..."
            if ! timeout $((CURL_TIMEOUT * 2)) brew install "$tool"; then
                log "ERROR" "Failed to install $tool"
                failed=$((failed + 1))
            fi
        else
            log "INFO" "$tool is already installed, skipping..."
        fi
    done
    
    if [ $failed -gt 0 ]; then
        log "WARN" "Failed to install $failed brew tool(s)"
        return 1
    fi
    
    return 0
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
    # 系统关键组件，失败需要退出
    setup_hostname || log "ERROR" "Hostname setup failed but continuing..."
    update_system || { log "ERROR" "System update failed, installation may be incomplete"; }
    install_basic_tools || log "ERROR" "Some basic tools installation failed but continuing..."
    
    # 非关键组件，失败可以继续
    setup_proxychains || log "WARN" "Proxychains setup failed but continuing..."
    install_youtube_dl || log "WARN" "Youtube-dl installation failed but continuing..."
    
    # Linuxbrew 和相关工具
    if install_linuxbrew; then
        install_brew_tools || log "WARN" "Some brew tools installation failed but continuing..."
    else
        log "WARN" "Skipping brew tools installation due to Linuxbrew installation failure"
    fi
    
    # 其他非关键组件
    install_nvm || log "WARN" "NVM installation failed but continuing..."
    install_go || log "WARN" "Go installation failed but continuing..."
    setup_python || log "WARN" "Python setup failed but continuing..."
    install_docker || log "WARN" "Docker installation failed but continuing..."
    install_vscode || log "WARN" "VS Code installation failed but continuing..."
    install_zsh || log "WARN" "Zsh installation failed but continuing..."
    install_vim_plug || log "WARN" "Vim-plug installation failed but continuing..."
    setup_git || log "WARN" "Git setup failed but continuing..."
    setup_mkcert || log "WARN" "mkcert setup failed but continuing..."
    
    log "INFO" "Ubuntu setup completed! Some components might have failed to install, please check the logs for details."
}

# 执行主函数
main 