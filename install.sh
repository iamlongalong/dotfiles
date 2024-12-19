#!/bin/bash

# 导入工具函数
source scripts/common/utils.sh

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
    check_network || exit 1
    
    # 创建必要的目录
    log "INFO" "Setting up directories..."
    source scripts/common/setup_dirs.sh
    
    # 设置权限
    log "INFO" "Setting up permissions..."
    chmod +x scripts/macos/install.sh
    chmod +x scripts/ubuntu/install.sh
    
    # 获取操作系统
    OS=$(detect_os)
    log "INFO" "Detected OS: $OS"
    
    # 运行相应的安装脚本
    case $OS in
        "macos")
            log "INFO" "Running macOS setup..."
            ./scripts/macos/install.sh
            ;;
        "ubuntu")
            log "INFO" "Running Ubuntu setup..."
            ./scripts/ubuntu/install.sh
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