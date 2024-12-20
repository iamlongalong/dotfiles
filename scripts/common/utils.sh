#!/bin/bash

# 日志级别
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3

# 当前日志级别
CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO

# 日志颜色
COLOR_DEBUG="\033[36m"  # Cyan
COLOR_INFO="\033[32m"   # Green
COLOR_WARN="\033[33m"   # Yellow
COLOR_ERROR="\033[31m"  # Red
COLOR_RESET="\033[0m"   # Reset

# 日志目录
LOG_DIR="${HOME}/.dotfiles/logs"
INSTALL_LOG="${LOG_DIR}/install.log"
ERROR_LOG="${LOG_DIR}/error.log"

# 确保日志目录存在
mkdir -p "${LOG_DIR}"

# 日志函数
log() {
    local level=$1
    local message=$2
    local color=""
    local level_name=""
    
    case $level in
        "DEBUG")
            [ $CURRENT_LOG_LEVEL -gt $LOG_LEVEL_DEBUG ] && return
            color=$COLOR_DEBUG
            level_name="DEBUG"
            ;;
        "INFO")
            [ $CURRENT_LOG_LEVEL -gt $LOG_LEVEL_INFO ] && return
            color=$COLOR_INFO
            level_name="INFO"
            ;;
        "WARN")
            [ $CURRENT_LOG_LEVEL -gt $LOG_LEVEL_WARN ] && return
            color=$COLOR_WARN
            level_name="WARN"
            ;;
        "ERROR")
            [ $CURRENT_LOG_LEVEL -gt $LOG_LEVEL_ERROR ] && return
            color=$COLOR_ERROR
            level_name="ERROR"
            ;;
        *)
            return
            ;;
    esac
    
    # 获取时间戳
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # 输出到终端
    echo -e "${color}[${timestamp}] [${level_name}] ${message}${COLOR_RESET}"
    
    # 写入日志文件
    echo "[${timestamp}] [${level_name}] ${message}" >> "${INSTALL_LOG}"
    
    # 错误日志也写入错误日志文件
    if [[ "$level" == "ERROR" ]]; then
        echo "[${timestamp}] ${message}" >> "${ERROR_LOG}"
    fi
}

# 错误处理函数
handle_error() {
    local exit_code=$?
    local line_number=$1
    local source_file=${BASH_SOURCE[1]:-unknown}
    log "ERROR" "Error occurred in ${source_file} at line ${line_number}. Exit code: ${exit_code}"
}

# 检查命令是否存在
check_command() {
    command -v "$1" >/dev/null 2>&1
}

# 检查系统类型
get_os_type() {
    case "$(uname -s)" in
        Linux*)     echo "Linux";;
        Darwin*)    echo "macOS";;
        *)         echo "Unknown";;
    esac
}

# 检查 Linux 发行版
get_linux_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

# 检查是否为 root 用户
is_root() {
    [ "$EUID" -eq 0 ]
}

# 检查是否有 sudo 权限
has_sudo() {
    sudo -n true 2>/dev/null
}

# 检查系统资源
check_system_resources() {
    log "INFO" "Checking system resources..."
    
    # 检查磁盘空间
    local required_space=5  # GB
    local available_space
    if [ "$(get_os_type)" = "Darwin" ]; then
        available_space=$(df -g / | awk 'NR==2 {print $4}')
    else
        available_space=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')
    fi
    
    if [ "$available_space" -lt "$required_space" ]; then
        log "ERROR" "Insufficient disk space. Required: ${required_space}GB, Available: ${available_space}GB"
        return 1
    fi
    
    # 检查内存
    local available_mem
    if [ "$(get_os_type)" = "Darwin" ]; then
        available_mem=$(vm_stat | awk '/free/ {gsub(/\./, "", $3); print int($3)*4096/1024/1024/1024}')
    else
        available_mem=$(free -g | awk 'NR==2 {print $7}')
    fi
    
    if [ "$available_mem" -lt 2 ]; then
        log "WARN" "Low memory available: ${available_mem}GB"
    fi
    
    log "INFO" "System resources check passed"
    return 0
}

# 检查网络连接
check_network() {
    log "INFO" "Checking network connectivity..."
    local urls=(
        "https://github.com"
        "https://registry.npmjs.org"
        "https://pypi.org"
    )
    
    local failed=0
    for url in "${urls[@]}"; do
        if ! curl --silent --head --fail "$url" &>/dev/null; then
            log "WARN" "Cannot access $url"
            failed=$((failed + 1))
        fi
    done
    
    if [ $failed -eq ${#urls[@]} ]; then
        log "ERROR" "No network connectivity to required services"
        return 1
    fi
    
    if [ $failed -gt 0 ]; then
        log "WARN" "Some services are not accessible"
    else
        log "INFO" "Network connectivity check passed"
    fi
    
    return 0
}

# 检查依赖
check_dependencies() {
    log "INFO" "Checking dependencies..."
    local deps=("$@")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! check_command "$dep"; then
            missing+=("$dep")
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
    local cmd=$1
    if ! check_command "$cmd"; then
        log "ERROR" "$cmd is not installed"
        return 1
    fi
    local version
    version=$("$cmd" --version 2>&1 | head -n1)
    log "INFO" "$cmd version: $version"
    return 0
}

# 备份函数
backup_file() {
    local file=$1
    if [ -f "$file" ]; then
        local backup_dir="${HOME}/.dotfiles/backups/$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$backup_dir"
        cp "$file" "$backup_dir/"
        log "INFO" "Backed up $file to $backup_dir"
    fi
}

# 设置日志级别
set_log_level() {
    case $1 in
        "DEBUG") CURRENT_LOG_LEVEL=$LOG_LEVEL_DEBUG;;
        "INFO")  CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO;;
        "WARN")  CURRENT_LOG_LEVEL=$LOG_LEVEL_WARN;;
        "ERROR") CURRENT_LOG_LEVEL=$LOG_LEVEL_ERROR;;
    esac
}

# 导出函数
export -f log
export -f handle_error
export -f check_command
export -f get_os_type
export -f get_linux_distro
export -f is_root
export -f has_sudo
export -f check_system_resources
export -f check_network
export -f check_dependencies
export -f check_version
export -f backup_file
export -f set_log_level

# 设置错误处理
set -e  # 遇到错误立即退出
set -u  # 使用未定义的变量时报错
trap 'handle_error $LINENO' ERR