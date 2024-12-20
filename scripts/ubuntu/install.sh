#!/bin/bash

# 显示路径信息
echo "Current working directory: $(pwd)"
echo "Script path: ${BASH_SOURCE[0]}"
echo "Script directory: $( dirname "${BASH_SOURCE[0]}" )"

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "Absolute script directory: ${SCRIPT_DIR}"

# 导入工具函数
source "${SCRIPT_DIR}/../common/utils.sh"

# 导入共享函数
source "${SCRIPT_DIR}/../common/homebrew.sh"

# 设置超时时间（秒）
CURL_TIMEOUT=30
BREW_INSTALL_TIMEOUT=600  # 10分钟

# 检查命令是否存在
check_cmd_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 带超时的 curl 下载
curl_with_timeout() {
    if [ -z "$1" ]; then
        log "ERROR" "URL is required for curl_with_timeout"
        return 1
    fi
    curl --connect-timeout ${CURL_TIMEOUT} --max-time $((CURL_TIMEOUT * 10)) "$@"
}

# 获取普通用户名
get_normal_user() {
    # 获取第一个非 root 的用户常是主用户
    local user=$(who | grep -v root | head -n 1 | awk '{print $1}')
    if [ -z "$user" ]; then
        # 如果 who 命令没有结��，尝试从 /home 目录获取
        user=$(ls -ld /home/* | grep -v root | head -n 1 | awk '{print $3}')
    fi
    echo "$user"
}

# 以普通用户身份运行命令
run_as_normal_user() {
    if [ -z "$1" ]; then
        log "ERROR" "Command is required for run_as_normal_user"
        return 1
    fi
    local cmd="$1"
    local user=$(get_normal_user)
    
    if [ -z "$user" ]; then
        log "ERROR" "No normal user found to run command"
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
    
    # 更新软件源
    if ! sudo apt update; then
        log "ERROR" "Failed to update package list"
        return 1
    fi
    
    # 升级系统
    if ! sudo apt upgrade -y; then
        log "ERROR" "Failed to upgrade system packages"
        return 1
    fi
    
    return 0
}

# 安装基础工具
install_basic_tools() {
    log "INFO" "Installing basic tools..."
    local tools=(
        git curl wget tree jq ripgrep fd-find bat build-essential
        software-properties-common apt-transport-https ca-certificates
        gnupg lsb-release screen vim ffmpeg proxychains4
    )
    
    # 设置 trap 以确保清理工作
    trap 'exit 130' INT
    
    for tool in "${tools[@]}"; do
        if ! check_cmd_exists "$tool"; then
            log "INFO" "Installing $tool..."
            if ! sudo apt install -y "$tool"; then
                log "ERROR" "Failed to install $tool"
                continue
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
# http 127.0.0.1 7890
EOF
        
        # 验证代理配置
        if check_proxy; then
            log "INFO" "Proxy configuration verified successfully"
        else
            log "WARN" "Proxy is configured but seems not working"
        fi
    else
        log "INFO" "proxychains4 is already configured, skipping..."
        # 仍然验证代理是否工作
        if check_proxy; then
            log "INFO" "Existing proxy configuration is working"
        else
            log "WARN" "Existing proxy configuration seems not working"
        fi
    fi
}

# 以普通用户身份运行 brew 命令
brew_as_user() {
    local normal_user=$(get_normal_user)
    if [ -z "$normal_user" ]; then
        log "ERROR" "No normal user found to run brew command"
        return 1
    fi
    
    # 如果当前已经是目���用户，直接运行命令
    if [ "$USER" = "$normal_user" ]; then
        /home/linuxbrew/.linuxbrew/bin/brew "$@"
        return $?
    fi
    
    # 否则，使用 su 切换到目标用户运行命令
    log "INFO" "Running brew command as user: $normal_user"
    su - "$normal_user" -c "/home/linuxbrew/.linuxbrew/bin/brew $*"
    return $?
}

install_linuxbrew() {
    if check_cmd_exists brew; then
        log "INFO" "Linuxbrew is already installed, skipping..."
        return 0
    fi

    log "INFO" "Installing Linuxbrew..."
    
    # 准备安装命令
    local install_script=$(cat << 'EOF'
#!/bin/bash

# 设置环境变量
export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
export HOMEBREW_INSTALL_FROM_API=1
export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"

# 安装 Homebrew
cd /tmp
git clone --depth=1 https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/install.git brew-install
/bin/bash brew-install/install.sh
rm -rf brew-install

# 配置 Homebrew
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# 配置镜像源
brew_path="/home/linuxbrew/.linuxbrew"
git -C "$brew_path" remote set-url origin https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git
git -C "$brew_path/Library/Taps/homebrew/homebrew-core" remote set-url origin https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git 2>/dev/null || true

# 添加环境变量配置到 shell 配置文件
shell_config="# Homebrew
eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\"

# Homebrew Mirrors
export HOMEBREW_BREW_GIT_REMOTE=\"https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git\"
export HOMEBREW_CORE_GIT_REMOTE=\"https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git\"
export HOMEBREW_BOTTLE_DOMAIN=\"https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles\"
export HOMEBREW_API_DOMAIN=\"https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api\""

for config_file in ~/.bashrc ~/.zshrc; do
    if [ -f "$config_file" ] && ! grep -q "brew shellenv" "$config_file"; then
        echo "$shell_config" >> "$config_file"
    fi
done
EOF
)

    # 如果是 root 用户，切换到普通用户安装
    if [ "$EUID" -eq 0 ]; then
        local normal_user=$(get_normal_user)
        if [ -z "$normal_user" ]; then
            log "ERROR" "No normal user found to install Linuxbrew"
            return 1
        fi
        
        # 临时禁用代理
        local old_http_proxy="$http_proxy"
        local old_https_proxy="$https_proxy"
        unset http_proxy
        unset https_proxy
        
        # 安装依赖
        log "INFO" "Installing Linuxbrew dependencies..."
        if ! apt-get install -y build-essential procps curl file git gcc; then
            log "ERROR" "Failed to install dependencies"
            # 恢复代理设置
            export http_proxy="$old_http_proxy"
            export https_proxy="$old_https_proxy"
            return 1
        fi
        
        # 恢复代理设置
        export http_proxy="$old_http_proxy"
        export https_proxy="$old_https_proxy"

        # 创建临时脚本文件
        local temp_script="/tmp/install_homebrew_$normal_user.sh"
        echo "$install_script" > "$temp_script"
        chmod 755 "$temp_script"
        chown "$normal_user:$(id -gn $normal_user)" "$temp_script"

        # 以普通用户身份运行安装脚本
        log "INFO" "Installing Linuxbrew as user: $normal_user"
        if ! su - "$normal_user" -c "$temp_script"; then
            log "ERROR" "Failed to install Linuxbrew as user: $normal_user"
            rm -f "$temp_script"
            return 1
        fi
        rm -f "$temp_script"
    else
        # 当前已经是普通用户，直接安装
        log "INFO" "Installing Linuxbrew dependencies..."
        # 临时禁用代理
        local old_http_proxy="$http_proxy"
        local old_https_proxy="$https_proxy"
        unset http_proxy
        unset https_proxy
        
        if ! sudo apt-get install -y build-essential procps curl file git gcc; then
            log "ERROR" "Failed to install dependencies"
            # 恢复代理设置
            export http_proxy="$old_http_proxy"
            export https_proxy="$old_https_proxy"
            return 1
        fi
        
        # 恢复代理设置
        export http_proxy="$old_http_proxy"
        export https_proxy="$old_https_proxy"
        
        # 创建临时脚本文件并执行
        local temp_script="/tmp/install_homebrew_$USER.sh"
        echo "$install_script" > "$temp_script"
        chmod 755 "$temp_script"
        
        log "INFO" "Installing Linuxbrew as user: $USER"
        if ! bash "$temp_script"; then
            log "ERROR" "Failed to install Linuxbrew"
            rm -f "$temp_script"
            return 1
        fi
        rm -f "$temp_script"
    fi

    log "INFO" "Linuxbrew installation completed successfully"
    return 0
}

# 安装 Homebrew 工具
install_brew_tools() {
    # 如果 brew 命令不存在，跳过安装
    if [ ! -f "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
        log "WARN" "Homebrew is not installed, skipping brew tools installation"
        return 0
    fi
    
    log "INFO" "Installing additional tools with Homebrew..."
    local tools=(lazydocker asciiquarium pyenv mkcert)
    local failed=0
    
    for tool in "${tools[@]}"; do
        if ! check_cmd_exists "$tool"; then
            log "INFO" "Installing $tool..."
            if ! brew_as_user install "$tool"; then
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
        log "INFO" "Installing NVM using Homebrew..."
        
        # 设置环境变量以禁用清理提示
        export HOMEBREW_NO_INSTALL_CLEANUP=1
        export HOMEBREW_NO_ENV_HINTS=1
        
        # 使用 Homebrew 安装 nvm
        if ! brew_as_user install nvm; then
            log "ERROR" "Failed to install NVM"
            return 1
        fi
        
        # 创建 nvm 目录
        mkdir -p "$HOME/.nvm"
        
        # 添加 nvm 配置到 shell 配置文件
        local nvm_config='
# NVM configuration
export NVM_DIR="$HOME/.nvm"
[ -s "/home/linuxbrew/.linuxbrew/opt/nvm/nvm.sh" ] && \. "/home/linuxbrew/.linuxbrew/opt/nvm/nvm.sh" --no-use  # This loads nvm
[ -s "/home/linuxbrew/.linuxbrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/home/linuxbrew/.linuxbrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion'
        
        for config_file in ~/.bashrc ~/.zshrc; do
            if [ -f "$config_file" ] && ! grep -q "NVM configuration" "$config_file"; then
                echo "$nvm_config" >> "$config_file"
            fi
        done
        
        # 立即加载 nvm
        export NVM_DIR="$HOME/.nvm"
        [ -s "/home/linuxbrew/.linuxbrew/opt/nvm/nvm.sh" ] && \. "/home/linuxbrew/.linuxbrew/opt/nvm/nvm.sh" --no-use
        [ -s "/home/linuxbrew/.linuxbrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/home/linuxbrew/.linuxbrew/opt/nvm/etc/bash_completion.d/nvm"
        
        # 配置 npm 淘宝镜像
        if [ ! -f "$HOME/.npmrc" ]; then
            echo "registry=https://registry.npmmirror.com" > "$HOME/.npmrc"
        fi
        
        # 安装 Node.js LTS
        log "INFO" "Installing Node.js LTS version..."
        if ! nvm install --lts; then
            log "ERROR" "Failed to install Node.js LTS"
            return 1
        fi
        
        # 使用 LTS 版本
        if ! nvm use --lts; then
            log "ERROR" "Failed to use Node.js LTS"
            return 1
        fi
        
        # 安装全局包
        if command -v npm >/dev/null 2>&1; then
            log "INFO" "Installing global npm packages..."
            npm install -g yarn pm2 --registry=https://registry.npmmirror.com
        else
            log "ERROR" "npm not found after Node.js installation"
            return 1
        fi
    else
        log "INFO" "NVM is already installed, skipping..."
    fi
    
    return 0
}

# 安装 Go
install_go() {
    if ! check_cmd_exists go; then
        log "INFO" "Installing Go..."
        local go_file="go1.21.5.linux-amd64.tar.gz"
        local go_url="https://go.dev/dl/$go_file"
        
        # 下载 Go
        if ! curl_with_timeout "$go_url" -L -o "/tmp/$go_file"; then
            log "ERROR" "Failed to download Go"
            return 1
        fi
        
        # 安装 Go
        sudo rm -rf /usr/local/go
        sudo tar -C /usr/local -xzf "/tmp/$go_file"
        rm "/tmp/$go_file"
        
        # 配置环境变量
        if ! grep -q "export PATH=\$PATH:/usr/local/go/bin" ~/.profile; then
            echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.profile
        fi
        
        # 立即生效环境变量
        export PATH=$PATH:/usr/local/go/bin
        
        log "INFO" "Go installation completed"
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
            if ! pyenv install 3.11.4; then
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
        
        # 先停止可能存在的 Docker 服务
        log "INFO" "Stopping any existing Docker service..."
        sudo systemctl stop docker || true
        
        # 清理可能存在的旧安装
        log "INFO" "Removing any existing Docker installations..."
        sudo apt remove --purge -y docker.io docker-engine docker containerd runc || true
        sudo rm -rf /var/lib/docker /etc/docker
        
        # 安装 Docker
        log "INFO" "Installing Docker using apt..."
        if ! sudo apt install -y docker.io containerd; then
            log "ERROR" "Failed to install Docker"
            return 1
        fi
        
        # 检查安装结果
        log "INFO" "Verifying Docker installation..."
        if ! dpkg -l | grep -q docker.io; then
            log "ERROR" "Docker package not found after installation"
            return 1
        fi
        
        # 启动 Docker 服务前检查系统状态
        log "INFO" "Checking system status before starting Docker..."
        sudo systemctl status containerd || true
        
        # 启动 Docker 服务，增加详细日志
        log "INFO" "Starting Docker service..."
        if ! sudo systemctl start docker; then
            log "ERROR" "Failed to start Docker service"
            log "INFO" "Checking Docker service status..."
            sudo systemctl status docker || true
            log "INFO" "Checking Docker logs..."
            sudo journalctl -u docker --no-pager -n 50 || true
            return 1
        fi
        
        # 验证 Docker 服务是否正常运行
        log "INFO" "Verifying Docker service..."
        if ! sudo docker info >/dev/null 2>&1; then
            log "ERROR" "Docker service is not responding"
            sudo systemctl status docker || true
            return 1
        fi
        
        # 启用 Docker 服务开机自启
        log "INFO" "Enabling Docker service..."
        if ! sudo systemctl enable docker; then
            log "ERROR" "Failed to enable Docker service"
            return 1
        fi
        
        # 获取当前用户
        local current_user=$USER
        if [ "$EUID" -eq 0 ]; then
            current_user=$(get_normal_user)
        fi
        
        # 将用户添加到 docker 组
        log "INFO" "Adding user $current_user to docker group..."
        if ! sudo usermod -aG docker "$current_user"; then
            log "ERROR" "Failed to add user to docker group"
            return 1
        fi
        
        log "INFO" "Docker installation completed"
        log "INFO" "Please log out and log back in for docker group changes to take effect"
        log "INFO" "You can verify the installation by running: docker --version"
    else
        log "INFO" "Docker is already installed, skipping..."
        
        # 检查 Docker 服务状态
        if ! sudo systemctl is-active docker >/dev/null 2>&1; then
            log "WARN" "Docker service is not running, attempting to start..."
            if ! sudo systemctl start docker; then
                log "ERROR" "Failed to start existing Docker service"
                sudo systemctl status docker || true
                return 1
            fi
        fi
    fi
    
    return 0
}

# 安装 VS Code
install_vscode() {
    if ! check_cmd_exists code; then
        log "INFO" "Installing Visual Studio Code..."
        
        # 下载并安装 GPG key
        if ! curl_with_timeout https://packages.microsoft.com/keys/microsoft.asc -fsSL | gpg --dearmor > /tmp/packages.microsoft.gpg; then
            log "ERROR" "Failed to download VS Code GPG key"
            return 1
        fi
        
        sudo install -o root -g root -m 644 /tmp/packages.microsoft.gpg /etc/apt/trusted.gpg.d/
        echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
        rm -f /tmp/packages.microsoft.gpg
        
        # 更新软件源
        if ! sudo apt update; then
            log "ERROR" "Failed to update package list"
            return 1
        fi
        
        # 安装 VS Code
        if ! sudo apt install -y code; then
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
        if ! sudo apt install -y zsh; then
            log "ERROR" "Failed to install Zsh"
            return 1
        fi
    else
        log "INFO" "Zsh is already installed, skipping..."
    fi

    setup_zsh
}

# 配置 Git
setup_git() {
    log "INFO" "Configuring Git..."
    cp "${SCRIPT_DIR}/../common/gitconfig" ~/.gitconfig
    # set git user name and email
    read -p "Enter your Git user name(empty to skip): " git_user_name
    read -p "Enter your Git email(empty to skip): " git_user_email
    if [ -n "$git_user_name" ] && [ -n "$git_user_email" ]; then
        git config --global user.name "$git_user_name"
        git config --global user.email "$git_user_email"
    fi
}

# 设置 mkcert
setup_mkcert() {
    if check_cmd_exists mkcert; then
        log "INFO" "Setting up mkcert..."
        if ! "${SCRIPT_DIR}/../common/setup_mkcert.sh"; then
            log "ERROR" "Failed to setup mkcert"
            return 1
        fi
    fi
}

# setup zsh
setup_zsh() {
    if ! "${SCRIPT_DIR}/../common/setup_zsh.sh"; then
        log "ERROR" "Failed to setup zsh"
        return 1
    fi
}

# 安装 NPS
install_nps() {
    if ! check_cmd_exists nps; then
        log "INFO" "Installing NPS..."
        
        # 创建安装目录
        sudo mkdir -p /usr/local/nps
        cd /usr/local/nps || return 1
        
        # 下载最新版本的 NPS
        local nps_version="v0.26.10"
        local nps_file="linux_amd64_server.tar.gz"
        
        # 定义多个下载源
        local download_urls=(
            "https://gitee.com/mirrors/nps/releases/download/${nps_version}/${nps_file}"  # Gitee镜像
            "https://hub.gitmirror.com/https://github.com/ehang-io/nps/releases/download/${nps_version}/${nps_file}"  # GitMirror镜像
            "https://github.com/ehang-io/nps/releases/download/${nps_version}/${nps_file}"  # GitHub源
        )
        
        # 尝试从不同源下载
        local download_success=false
        for url in "${download_urls[@]}"; do
            log "INFO" "Trying to download from: $url"
            if curl_with_timeout "$url" -L -o "$nps_file"; then
                download_success=true
                break
            else
                log "WARN" "Failed to download from: $url, trying next source..."
            fi
        done
        
        if [ "$download_success" = false ]; then
            log "ERROR" "Failed to download NPS from all sources"
            return 1
        fi
        
        # 解压文件
        if ! tar xzf "$nps_file"; then
            log "ERROR" "Failed to extract NPS"
            return 1
        fi
        
        # 清理下载文件
        rm -f "$nps_file"
        
        # 创建配置文件目录
        sudo mkdir -p /etc/nps
        
        # 创建基础配置文件
        sudo tee /etc/nps/conf/nps.conf > /dev/null << EOF
appname = nps
#Boot mode(dev|pro)
runmode = pro

#HTTP(S) proxy port, no startup if empty
http_proxy_ip=0.0.0.0
http_proxy_port=80
https_proxy_port=443
https_just_proxy=true
#default https certificate setting
https_default_cert_file=/etc/nps/conf/server.pem
https_default_key_file=/etc/nps/conf/server.key

##bridge
bridge_type=tcp
bridge_port=8024
bridge_ip=0.0.0.0

# Public password, which clients can use to connect to the server
# After the connection, the server will be able to open relevant ports and parse related domain names according to its own configuration file.
public_vkey=123

#Traffic data persistence interval(minute)
web_username=admin
web_password=123
web_port = 8080
web_ip=0.0.0.0
web_base_url=
web_open_ssl=false
web_cert_file=conf/server.pem
web_key_file=conf/server.key
EOF
        
        # 创建服务文件
        sudo tee /etc/systemd/system/nps.service > /dev/null << EOF
[Unit]
Description=NPS Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/nps/nps
WorkingDirectory=/etc/nps
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
        
        # 复制配置文件到正确位置
        sudo cp -r /usr/local/nps/conf /etc/nps/
        
        # 重新加载 systemd
        sudo systemctl daemon-reload
        
        # 启动 NPS 服务
        if ! sudo systemctl start nps; then
            log "ERROR" "Failed to start NPS service"
            return 1
        fi
        
        # 设置开机自启
        if ! sudo systemctl enable nps; then
            log "ERROR" "Failed to enable NPS service"
            return 1
        fi
        
        log "INFO" "NPS installation completed"
        log "INFO" "Web dashboard is available at http://localhost:8080"
        log "INFO" "Default username: admin"
        log "INFO" "Default password: 123"
        log "INFO" "Default public vkey: 123"
        log "INFO" "Please change these default values in /etc/nps/conf/nps.conf for security"
    else
        log "INFO" "NPS is already installed, skipping..."
        
        # 检查服务状态
        if ! sudo systemctl is-active nps >/dev/null 2>&1; then
            log "WARN" "NPS service is not running, attempting to start..."
            if ! sudo systemctl start nps; then
                log "ERROR" "Failed to start existing NPS service"
                sudo systemctl status nps || true
                return 1
            fi
        fi
    fi
    
    return 0
}

# 主函数
main() {
    # 系统关键组件，失败需退出
    setup_hostname || log "ERROR" "Hostname setup failed but continuing..."
    # update_system || { log "ERROR" "System update failed, installation may be incomplete"; }
    install_basic_tools || log "ERROR" "Some basic tools installation failed but continuing..."
    
    # 非关键组件，败可以继续
    setup_proxychains || log "WARN" "Proxychains setup failed but continuing..."
    
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
    install_nps || log "WARN" "NPS installation failed but continuing..."
    install_vscode || log "WARN" "VS Code installation failed but continuing..."
    install_zsh || log "WARN" "Zsh installation failed but continuing..."
    setup_git || log "WARN" "Git setup failed but continuing..."
    setup_mkcert || log "WARN" "mkcert setup failed but continuing..."
    
    log "INFO" "Ubuntu setup completed! Some components might have failed to install, please check the logs for details."
}

# 执行主函数
main 