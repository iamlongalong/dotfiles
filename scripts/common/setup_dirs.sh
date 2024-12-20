#!/bin/bash

# 创建必要的目录结构
setup_directories() {
    # 日志目录
    mkdir -p ~/.dotfiles/logs
    
    # 备份目录
    mkdir -p ~/.dotfiles/backups/$(date +%Y%m%d_%H%M%S)
    
    # 配置目录
    mkdir -p ~/.config/zsh/{exports,aliases,functions,paths,completions}
    
    # 本地二进制目录
    mkdir -p ~/.local/bin
    
    # 证书目录
    mkdir -p ~/.local/share/mkcert
    
    # 开发目录
    mkdir -p ~/code/{go,python,javascript,tools}
    mkdir -p ~/scripts
    mkdir -p ~/docs
    
    # 设置权限
    chmod 700 ~/.dotfiles/backups
    chmod 755 ~/.local/bin
}

# 执行目录设置
setup_directories 