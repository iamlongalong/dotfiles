#!/bin/bash

# 导入工具函数
source $(dirname "$0")/utils.sh

# 检查系统更新
check_system_updates() {
    log "INFO" "Checking system updates..."
    
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS
        softwareupdate -l
    else
        # Ubuntu
        sudo apt update -qq
        apt list --upgradable
    fi
}

# 检查 Homebrew 更新
check_brew_updates() {
    if command -v brew &>/dev/null; then
        log "INFO" "Checking Homebrew updates..."
        brew update
        brew outdated
    fi
}

# 检查 npm 包更新
check_npm_updates() {
    if command -v npm &>/dev/null; then
        log "INFO" "Checking npm global package updates..."
        npm outdated -g
    fi
}

# 检查 Python 包更新
check_python_updates() {
    if command -v pip &>/dev/null; then
        log "INFO" "Checking Python package updates..."
        pip list --outdated
    fi
}

# 检查 Go 包更新
check_go_updates() {
    if command -v go &>/dev/null; then
        log "INFO" "Checking Go package updates..."
        go list -u -m all
    fi
}

# 检查 Vim 插件更新
check_vim_updates() {
    if [ -f ~/.vimrc ]; then
        log "INFO" "Checking Vim plugin updates..."
        vim +PlugUpdate +PlugUpgrade +qall
    fi
}

# 检查 Oh My Zsh 更新
check_omz_updates() {
    if [ -d "$HOME/.oh-my-zsh" ]; then
        log "INFO" "Checking Oh My Zsh updates..."
        omz update
    fi
}

# 主更新函数
main() {
    log "INFO" "Starting update checks..."
    
    check_system_updates
    check_brew_updates
    check_npm_updates
    check_python_updates
    check_go_updates
    check_vim_updates
    check_omz_updates
    
    log "INFO" "Update checks completed"
}

# 执行更新检查
main 