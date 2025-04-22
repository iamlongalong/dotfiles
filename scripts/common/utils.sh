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
    local level="$1"  # 添加引号确保变量值被正确保留
    local message="$2"
    
    # 使用 case 语句替代关联数组
    local level_num
    local color
    
    case "${level}" in  # 使用 ${} 和引号包裹变量
        "DEBUG")
            level_num=$LOG_LEVEL_DEBUG
            color=$COLOR_DEBUG
            ;;
        "INFO")
            level_num=$LOG_LEVEL_INFO
            color=$COLOR_INFO
            ;;
        "WARN")
            level_num=$LOG_LEVEL_WARN
            color=$COLOR_WARN
            ;;
        "ERROR")
            level_num=$LOG_LEVEL_ERROR
            color=$COLOR_ERROR
            ;;
        *)
            return
            ;;
    esac
    
    [ $CURRENT_LOG_LEVEL -gt $level_num ] && return
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="[${timestamp}] [${level}] ${message}"
    
    # 输出到终端
    echo -e "${color}${log_entry}${COLOR_RESET}"
    
    # 写入日志文件
    echo "${log_entry}" >> "${INSTALL_LOG}"
    
    # 错误日志单独写入 - 使用更明确的字符串比较
    if [ "${level}" = "ERROR" ]; then
        echo "${log_entry}" >> "${ERROR_LOG}"
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
    
    local os_type=$(get_os_type)
    
    # 获取可用磁盘空间
    get_available_space() {
        if [ "$os_type" = "Darwin" ]; then
            df -g / | awk 'NR==2 {print $4}'
        else
            df -BG / | awk 'NR==2 {print $4}' | tr -d 'G'
        fi
    }
    
    # 获取可用内存
    get_available_memory() {
        if [ "$os_type" = "Darwin" ]; then
            vm_stat | awk '/free/ {gsub(/\./, "", $3); print int($3)*4096/1024/1024/1024}'
        else
            free -g | awk 'NR==2 {print $7}'
        fi
    }
    
    local required_space=5
    local available_space=$(get_available_space)
    local available_mem=$(get_available_memory)
    
    # 检查磁盘空间
    if [ "$available_space" -lt "$required_space" ]; then
        log "ERROR" "Insufficient disk space. Required: ${required_space}GB, Available: ${available_space}GB"
        return 1
    fi
    
    # 检查内存
    if [ "$available_mem" -lt 2 ]; then
        log "WARN" "Low memory available: ${available_mem}GB"
    fi
    
    log "INFO" "System resources check passed"
    return 0
}

# 检查网络连接
check_network() {
    log "INFO" "Checking network connectivity..."
    
    check_url() {
        local url=$1
        local timeout=5
        curl --silent --head --fail --max-time "$timeout" "$url" &>/dev/null
    }
    
    local -A urls=(
        ["GitHub"]="https://github.com"
        ["NPM"]="https://registry.npmjs.org"
        ["PyPI"]="https://pypi.org"
    )
    
    local failed=0
    local total=${#urls[@]}
    local results=()
    
    for name in "${!urls[@]}"; do
        if ! check_url "${urls[$name]}"; then
            failed=$((failed + 1))
            results+=("$name: ❌")
            log "WARN" "Cannot access $name (${urls[$name]})"
        else
            results+=("$name: ✓")
        fi
    done
    
    if [ $failed -eq $total ]; then
        log "ERROR" "No network connectivity to required services"
        return 1
    fi
    
    log "INFO" "Network check results: ${results[*]}"
    return $(( failed > 0 ))
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
# set -u  # 使用未定义的变量时报错
trap 'handle_error $LINENO' ERR

# 添加版本控制函数
version_compare() {
    local v1=$1
    local v2=$2
    
    # 规范化版本号
    local norm_v1=$(echo "$v1" | sed 's/[^0-9.]/./g' | tr -s '.')
    local norm_v2=$(echo "$v2" | sed 's/[^0-9.]/./g' | tr -s '.')
    
    if [ "$norm_v1" = "$norm_v2" ]; then
        echo "="
    else
        local IFS=.
        local i v1_array=($norm_v1) v2_array=($norm_v2)
        for ((i=0; i<${#v1_array[@]} || i<${#v2_array[@]}; i++)); do
            local v1_part=${v1_array[i]:-0}
            local v2_part=${v2_array[i]:-0}
            if ((v1_part > v2_part)); then
                echo ">"
                return
            elif ((v1_part < v2_part)); then
                echo "<"
                return
            fi
        done
    fi
}

# 添加清理日志函数
cleanup_logs() {
    local max_days=${1:-30}  # 默认保留30天的日志
    local log_files=("$INSTALL_LOG" "$ERROR_LOG")
    
    for log_file in "${log_files[@]}"; do
        if [ -f "$log_file" ]; then
            find "$(dirname "$log_file")" -name "$(basename "$log_file")*" -mtime +"$max_days" -delete
            log "INFO" "Cleaned up logs older than $max_days days from $log_file"
        fi
    done
}