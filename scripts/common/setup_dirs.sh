#!/bin/bash

# 错误处理函数
handle_error() {
    echo "Error: $1" >&2
    exit 1
}

# 日志函数
log() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
}

# 定义目录结构
declare -A DIRECTORIES=(
    # 系统配置目录
    ["config"]="$HOME/.config/zsh/{exports,aliases,functions,paths,completions}"
    
    # dotfiles 相关目录
    ["dotfiles"]="$HOME/.dotfiles/logs
                  $HOME/.dotfiles/backups/$(date +%Y%m%d_%H%M%S)"
    
    # 本地应用目录
    ["local"]="$HOME/.local/bin
               $HOME/.local/share/mkcert"
    
    # 开发相关目录
    ["development"]="$HOME/code/{go,python,javascript,tools}
                    $HOME/scripts
                    $HOME/docs"
)

# 定义目录权限
declare -A PERMISSIONS=(
    ["$HOME/.dotfiles/backups"]="700"
    ["$HOME/.local/bin"]="755"
    ["$HOME/.local/share/mkcert"]="700"
    ["$HOME/scripts"]="755"
)

# 创建目录函数
create_directory() {
    local dir="$1"
    if mkdir -p "$dir"; then
        log "INFO" "Created directory: $dir"
    else
        handle_error "Failed to create directory: $dir"
    fi
}

# 设置权限函数
set_permissions() {
    local dir="$1"
    local perm="$2"
    if chmod "$perm" "$dir"; then
        log "INFO" "Set permissions $perm on: $dir"
    else
        handle_error "Failed to set permissions $perm on: $dir"
    fi
}

# 主函数
setup_directories() {
    log "INFO" "Starting directory setup..."
    
    # 创建所有目录
    for category in "${!DIRECTORIES[@]}"; do
        log "INFO" "Setting up $category directories..."
        # 使用 echo 和 tr 处理多行字符串
        echo "${DIRECTORIES[$category]}" | tr ' ' '\n' | while read -r dir; do
            # 跳过空行
            [ -z "$dir" ] && continue
            # 展开路径中的通配符
            eval "create_directory $dir"
        done
    done
    
    # 设置特定目录的权限
    log "INFO" "Setting directory permissions..."
    for dir in "${!PERMISSIONS[@]}"; do
        if [ -d "$dir" ]; then
            set_permissions "$dir" "${PERMISSIONS[$dir]}"
        else
            log "WARN" "Directory not found for permission setting: $dir"
        fi
    done
    
    log "INFO" "Directory setup completed successfully"
}

# 执行主函数
setup_directories