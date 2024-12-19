#!/bin/bash

# 日志文件路径
INSTALL_LOG=~/.dotfiles/logs/install.log
ERROR_LOG=~/.dotfiles/logs/error.log

# 确保日志目录存在
mkdir -p ~/.dotfiles/logs

# 日志函数
log() {
    local level=$1
    shift
    local message=$*
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a $INSTALL_LOG
    
    # 错误日志也写入错误日志文件
    if [[ "$level" == "ERROR" ]]; then
        echo "[$timestamp] $message" >> $ERROR_LOG
    fi
}

# 错误处理函数
handle_error() {
    local exit_code=$?
    local line_number=$1
    log "ERROR" "Error occurred in ${BASH_SOURCE[1]} at line $line_number. Exit code: $exit_code"
}

# 检查命令是否存在
check_command() {
    if ! command -v $1 &> /dev/null; then
        log "ERROR" "Command not found: $1"
        return 1
    fi
}

# 检查系统资源
check_system_resources() {
    # 检查磁盘空间
    local required_space=5  # GB
    local available_space=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')
    
    if [ "$available_space" -lt "$required_space" ]; then
        log "ERROR" "Insufficient disk space. Required: ${required_space}GB, Available: ${available_space}GB"
        return 1
    fi
    
    # 检查内存
    local available_mem=$(free -g | awk 'NR==2 {print $7}')
    if [ "$available_mem" -lt 2 ]; then
        log "WARNING" "Low memory available: ${available_mem}GB"
    fi
    
    log "INFO" "System resources check passed"
    return 0
}

# 检查网络连接
check_network() {
    local urls=(
        "https://github.com"
        "https://registry.npmjs.org"
        "https://pypi.org"
    )
    
    local failed=0
    for url in "${urls[@]}"; do
        if ! curl --silent --head --fail "$url" &>/dev/null; then
            log "WARNING" "Cannot access $url"
            failed=$((failed + 1))
        fi
    done
    
    if [ $failed -eq ${#urls[@]} ]; then
        log "ERROR" "No network connectivity to required services"
        return 1
    fi
    
    if [ $failed -gt 0 ]; then
        log "WARNING" "Some services are not accessible"
    else
        log "INFO" "Network connectivity check passed"
    fi
    
    return 0
}

# 检查依赖
check_dependencies() {
    local deps=(git curl wget sudo)
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v $dep &> /dev/null; then
            missing+=($dep)
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        log "ERROR" "Missing dependencies: ${missing[*]}"
        return 1
    fi
    
    log "INFO" "All dependencies are installed"
    return 0
}

# 检查版本
check_version() {
    if ! command -v $1 &> /dev/null; then
        log "ERROR" "$1 is not installed"
        return 1
    fi
    local version=$($1 --version 2>&1 | head -n1)
    log "INFO" "$1 version: $version"
    return 0
}

# 备份函数
backup_file() {
    local file=$1
    if [ -f "$file" ]; then
        local backup_dir=~/.dotfiles/backups/$(date +%Y%m%d_%H%M%S)
        mkdir -p "$backup_dir"
        cp "$file" "$backup_dir/"
        log "INFO" "Backed up $file to $backup_dir"
    fi
}

# 设置错误处理
set -e  # 遇到错误立即退出
set -u  # 使用未定义的变量时报错
trap 'handle_error $LINENO' ERR 