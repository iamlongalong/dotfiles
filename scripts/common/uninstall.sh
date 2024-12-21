#!/bin/bash

# 导入工具函数
source $(dirname "$0")/utils.sh

# 卸载函数
uninstall() {
    log "INFO" "Starting uninstallation process..."
    
    # 确认卸载
    read -p "This will remove all configurations. Are you sure? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "INFO" "Uninstallation cancelled"
        exit 0
    fi
    
    # 备份当前配置
    log "INFO" "Backing up current configurations..."
    local backup_dir=~/.dotfiles/backups/pre_uninstall_$(date +%Y%m%d_%H%M%S)
    mkdir -p "$backup_dir"
    
    # 备份重要配置文件
    local configs=(
        ~/.zshrc
        ~/.gitconfig
        ~/.config/zsh
    )
    
    for config in "${configs[@]}"; do
        if [ -e "$config" ]; then
            cp -r "$config" "$backup_dir/"
            log "INFO" "Backed up $config"
        fi
    done
    
    # 移除配置文件
    log "INFO" "Removing configuration files..."
    rm -f ~/.zshrc ~/.gitconfig
    rm -rf ~/.config/zsh
    
    # 清理 Homebrew 包（如果存在）
    if command -v brew &>/dev/null; then
        log "INFO" "Cleaning up Homebrew packages..."
        read -p "Do you want to remove Homebrew packages? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            brew remove lazydocker asciiquarium pyenv mkcert
        fi
    fi
    
    # 清理 npm 全局包（如果存在）
    if command -v npm &>/dev/null; then
        log "INFO" "Cleaning up npm global packages..."
        read -p "Do you want to remove npm global packages? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            npm uninstall -g pm2 yarn
        fi
    fi
    
    # 清理 Python 包（如果存在）
    if command -v pip &>/dev/null; then
        log "INFO" "Cleaning up Python packages..."
        read -p "Do you want to remove Python packages? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            pip uninstall -y poetry
        fi
    fi
    
    # 移除代理配置
    log "INFO" "Removing proxy configurations..."
    unset http_proxy https_proxy all_proxy
    unset HTTP_PROXY HTTPS_PROXY ALL_PROXY
    git config --global --unset http.proxy
    git config --global --unset https.proxy
    
    # 清理日志和备份（可选）
    read -p "Do you want to remove all logs and backups? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "INFO" "Removing logs and backups..."
        rm -rf ~/.dotfiles/logs/*
        # 保留最后一次备份
        find ~/.dotfiles/backups -maxdepth 1 -type d -not -name "$(ls -t ~/.dotfiles/backups | head -1)" -exec rm -rf {} +
    fi
    
    log "INFO" "Uninstallation completed"
    log "INFO" "Your original configurations have been backed up to: $backup_dir"
    log "INFO" "Please restart your terminal for changes to take effect"
}

# 执行卸载
uninstall 