#!/bin/bash

# Homebrew 安装和配置的共享函数

# 配置 Homebrew 环境变量
setup_brew_env() {
    export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
    export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
    export HOMEBREW_INSTALL_FROM_API=1
    export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
    export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
}

# 获取 Homebrew 配置内容
get_brew_config() {
    echo '# Homebrew
eval "$('$1'/bin/brew shellenv)"

# Homebrew Mirrors
export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"'
}

# 添加 Homebrew 配置到 shell 配置文件
add_brew_config_to_shell() {
    local brew_path="$1"
    local shell_config=$(get_brew_config "$brew_path")
    
    for config_file in ~/.bashrc ~/.zshrc ~/.profile; do
        if [ -f "$config_file" ] && ! grep -q "brew shellenv" "$config_file"; then
            echo "$shell_config" >> "$config_file"
        fi
    done
}

# 配置 Homebrew 镜像源
setup_brew_mirrors() {
    git -C "$(brew --repo)" remote set-url origin https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git
    git -C "$(brew --repo homebrew/core)" remote set-url origin https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git 2>/dev/null || true
}

# 安装基础工具
install_brew_basic_tools() {
    log "INFO" "Installing common tools..."
    local tools=(
        git wget curl tree jq ripgrep fd bat exa
        diff-so-fancy fzf lazydocker asciiquarium
        ffmpeg youtube-dl mkcert
    )
    
    for tool in "${tools[@]}"; do
        if ! check_cmd_exists "$tool"; then
            log "INFO" "Installing $tool..."
            if ! timeout ${BREW_INSTALL_TIMEOUT:-600} brew install "$tool"; then
                log "ERROR" "Failed to install $tool"
            fi
        else
            log "INFO" "$tool is already installed, skipping..."
        fi
    done
} 