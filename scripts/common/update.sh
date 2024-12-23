#!/bin/bash

# 导入工具函数
source $(dirname "$0")/utils.sh

# 定义更新检查器
declare -A UPDATE_CHECKERS=(
    ["system"]="check_system_updates"
    ["homebrew"]="check_brew_updates"
    ["npm"]="check_npm_updates"
    ["python"]="check_python_updates"
    ["go"]="check_go_updates"
    ["vim"]="check_vim_updates"
    ["omz"]="check_omz_updates"
)

# 系统更新检查
check_system_updates() {
    log "INFO" "Checking system updates..."
    local os_type=$(get_os_type)
    
    case "$os_type" in
        "macOS")
            softwareupdate -l
            ;;
        "Linux")
            if check_command "apt"; then
                sudo apt update -qq
                apt list --upgradable
            elif check_command "yum"; then
                sudo yum check-update
            fi
            ;;
        *)
            log "WARN" "Unsupported operating system: $os_type"
            return 1
            ;;
    esac
}

# Homebrew 更新检查
check_brew_updates() {
    if ! check_command "brew"; then
        log "DEBUG" "Homebrew is not installed"
        return 0
    fi
    
    log "INFO" "Checking Homebrew updates..."
    brew update
    local outdated=$(brew outdated)
    if [ -n "$outdated" ]; then
        log "INFO" "Outdated Homebrew packages:\n$outdated"
    fi
}

# NPM 包更新检查
check_npm_updates() {
    if ! check_command "npm"; then
        log "DEBUG" "npm is not installed"
        return 0
    fi
    
    log "INFO" "Checking npm global package updates..."
    local outdated=$(npm outdated -g)
    if [ -n "$outdated" ]; then
        log "INFO" "Outdated npm packages:\n$outdated"
    fi
}

# Python 包更新检查
check_python_updates() {
    if ! check_command "pip"; then
        log "DEBUG" "pip is not installed"
        return 0
    fi
    
    log "INFO" "Checking Python package updates..."
    local outdated=$(pip list --outdated)
    if [ -n "$outdated" ]; then
        log "INFO" "Outdated Python packages:\n$outdated"
    fi
}

# Go 包更新检查
check_go_updates() {
    if ! check_command "go"; then
        log "DEBUG" "Go is not installed"
        return 0
    fi
    
    log "INFO" "Checking Go package updates..."
    local outdated=$(go list -u -m all | grep '\[' || true)
    if [ -n "$outdated" ]; then
        log "INFO" "Outdated Go packages:\n$outdated"
    fi
}

# Vim 插件更新检查
check_vim_updates() {
    if [ ! -f ~/.vimrc ]; then
        log "DEBUG" "Vim configuration not found"
        return 0
    fi
    
    log "INFO" "Checking Vim plugin updates..."
    # 使用非交互模式更新插件
    vim -es -u ~/.vimrc -i NONE -c "PlugUpdate" -c "PlugUpgrade" -c "qa"
}

# Oh My Zsh 更新检查
check_omz_updates() {
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        log "DEBUG" "Oh My Zsh is not installed"
        return 0
    fi
    
    log "INFO" "Checking Oh My Zsh updates..."
    # 使用非交互模式更新 Oh My Zsh
    env ZSH=$HOME/.oh-my-zsh sh -c 'source $ZSH/oh-my-zsh.sh && omz update --unattended'
}

# 运行指定的更新检查
run_update_check() {
    local checker_name=$1
    local checker_func=${UPDATE_CHECKERS[$checker_name]}
    
    if [ -n "$checker_func" ]; then
        $checker_func
    else
        log "ERROR" "Unknown update checker: $checker_name"
        return 1
    fi
}

# 主更新函数
main() {
    local specific_checks=("$@")
    
    log "INFO" "Starting update checks..."
    
    if [ ${#specific_checks[@]} -eq 0 ]; then
        # 如果没有指定特定检查，运行所有检查
        for checker in "${!UPDATE_CHECKERS[@]}"; do
            run_update_check "$checker"
        done
    else
        # 运行指定的检查
        for checker in "${specific_checks[@]}"; do
            run_update_check "$checker"
        done
    fi
    
    log "INFO" "Update checks completed"
}

# 如果直接运行此脚本（不是被导入），则执行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 