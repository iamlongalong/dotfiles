#!/bin/bash

setup_v2ray() {
    echo "是否需要设置 V2Ray? (y/N)"
    read -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ./scripts/common/v2ray.sh
    fi
}

# 设置临时代理函数
setup_proxy() {
    local default_proxy="127.0.0.1:7890"
    
    echo "是否需要设置临时代理? (y/N)"
    read -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "请输入代理地址 (默认: $default_proxy):"
        read proxy_addr
        proxy_addr=${proxy_addr:-$default_proxy}
        
        # 设置当前会话的环境变量代理
        export http_proxy="socks5://$proxy_addr"
        export https_proxy="socks5://$proxy_addr"
        export all_proxy="socks5://$proxy_addr"
        export HTTP_PROXY="socks5://$proxy_addr"
        export HTTPS_PROXY="socks5://$proxy_addr"
        export ALL_PROXY="socks5://$proxy_addr"
        
        # 临时设置 Git 代理（只对当前仓库有效）
        git config http.proxy "socks5://$proxy_addr"
        git config https.proxy "socks5://$proxy_addr"
        
        echo "临时代理已设置为 socks5://$proxy_addr"
        echo "代理设置仅在本次安装过程中有效"
    fi
}

# 清理代理设置
cleanup_proxy() {
    if [ -n "$http_proxy" ] || [ -n "$https_proxy" ] || [ -n "$all_proxy" ]; then
        # 清除环境变量代理
        unset http_proxy https_proxy all_proxy
        unset HTTP_PROXY HTTPS_PROXY ALL_PROXY
        
        # 清除当前仓库的 Git 代理设置
        git config --unset http.proxy
        git config --unset https.proxy
        
        echo "临时代理设置已清除"
    fi
}

# 检测操作系统
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}


# 设置 V2Ray （如果需要）
OS=$(detect_os)
log "INFO" "Detected OS: $OS"
case $OS in
    "macos")
        ;;
    "ubuntu")
        setup_v2ray
        ;;
esac

# 设置临时代理（如果需要）
setup_proxy

# 确保在脚本退出时清理代理设置
trap cleanup_proxy EXIT

# 导入工具函数
source scripts/common/utils.sh


# 主安装函数
main() {
    log "INFO" "Starting installation process..."
    
    # 检查依赖
    log "INFO" "Checking dependencies..."
    check_dependencies || exit 1
    
    # 检查系统资源
    log "INFO" "Checking system resources..."
    check_system_resources || exit 1
    
    # 检查网络连接
    log "INFO" "Checking network connectivity..."
    # check_network || exit 1
    
    # 创建必要的目录
    log "INFO" "Setting up directories..."
    source scripts/common/setup_dirs.sh
    
    # 设置权限
    log "INFO" "Setting up permissions..."
    
    # 获取操作系统
    OS=$(detect_os)
    log "INFO" "Detected OS: $OS"
    
    # 运行相应的安装脚本
    case $OS in
        "macos")
            log "INFO" "Running macOS setup..."
            ./scripts/macos/install.sh
            ./scripts/common/setup_configs.sh
            ;;
        "ubuntu")
            log "INFO" "Running Ubuntu setup..."
            ./scripts/ubuntu/install.sh
            ./scripts/common/setup_configs.sh
            ;;
        *)
            log "ERROR" "Unsupported operating system: $OS"
            exit 1
            ;;
    esac
    
    # 安装 chezmoi
    if ! command -v chezmoi &> /dev/null; then
        log "INFO" "Installing chezmoi..."
        sh -c "$(curl -fsLS get.chezmoi.io)"
    fi
    
    # 初始化 chezmoi
    log "INFO" "Initializing chezmoi..."
    chezmoi init
    chezmoi apply
    
    log "INFO" "Installation completed successfully!"
    log "INFO" "Please restart your terminal for changes to take effect."
}

# 执行主函数
main