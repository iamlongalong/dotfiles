# 代理相关的别名和函数

# 代理地址环境变量（默认值）
: ${PROXY_HOST:=127.0.0.1}
: ${PROXY_PORT:=7890}
: ${PROXY_PROTOCOL:=http}
: ${PROXY_SOCKS_PORT:=7890}  # socks 代理端口

# 设置代理的函数
set_proxy() {
    local host=${1:-$PROXY_HOST}
    local port=${2:-$PROXY_PORT}
    local protocol=${3:-$PROXY_PROTOCOL}
    
    export http_proxy="${protocol}://${host}:${port}"
    export https_proxy="${protocol}://${host}:${port}"
    export all_proxy="socks5://${host}:${PROXY_SOCKS_PORT}"  # 使用 socks5 端口
    export HTTP_PROXY="${protocol}://${host}:${port}"
    export HTTPS_PROXY="${protocol}://${host}:${port}"
    export ALL_PROXY="socks5://${host}:${PROXY_SOCKS_PORT}"  # 使用 socks5 端口
    
    # 为 Git 设置代理
    git config --global http.proxy "${protocol}://${host}:${port}"
    git config --global https.proxy "${protocol}://${host}:${port}"
    
    # 为 npm 设置代理
    if command -v npm &> /dev/null; then
        npm config set proxy "${protocol}://${host}:${port}"
        npm config set https-proxy "${protocol}://${host}:${port}"
    fi
    
    echo "Proxy set to ${protocol}://${host}:${port}"
    echo "Socks5 proxy set to socks5://${host}:${PROXY_SOCKS_PORT}"
}

# 取消代理的函数
unset_proxy() {
    unset http_proxy https_proxy all_proxy
    unset HTTP_PROXY HTTPS_PROXY ALL_PROXY
    
    # 取消 Git 代理
    git config --global --unset http.proxy
    git config --global --unset https.proxy
    
    # 取消 npm 代理
    if command -v npm &> /dev/null; then
        npm config delete proxy
        npm config delete https-proxy
    fi
    
    echo "All proxy settings removed"
}

# 检查代理状态
check_proxy() {
    echo "Current proxy settings:"
    echo "http_proxy: $http_proxy"
    echo "https_proxy: $https_proxy"
    echo "all_proxy: $all_proxy"
    echo
    echo "Git proxy settings:"
    echo "http.proxy: $(git config --global http.proxy)"
    echo "https.proxy: $(git config --global https.proxy)"
    echo
    if command -v npm &> /dev/null; then
        echo "npm proxy settings:"
        echo "proxy: $(npm config get proxy)"
        echo "https-proxy: $(npm config get https-proxy)"
        echo
    fi
    echo "Testing proxy with curl:"
    curl -s ip.gs
}

# proxyterm 命令 - 打开一个新的带代理的终端
proxyterm() {
    # 在新终端中设置代理并运行 zsh
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS
        osascript -e "tell application \"Terminal\" to do script \"source ~/.zshrc && set_proxy && echo 'Terminal started with proxy settings' && zsh\""
    else
        # Linux (Ubuntu)
        if command -v gnome-terminal &> /dev/null; then
            gnome-terminal -- zsh -c "source ~/.zshrc && set_proxy && echo 'Terminal started with proxy settings' && zsh"
        else
            echo "Unsupported terminal. Please install gnome-terminal or modify this script for your terminal."
        fi
    fi
}

# proxychains 别名和函数 (仅在 Linux 上)
if [[ "$(uname)" == "Linux" ]]; then
    if command -v proxychains4 &> /dev/null; then
        alias pc='proxychains4'
        # 在新终端中使用 proxychains4
        pcterm() {
            gnome-terminal -- zsh -c "pc zsh"
        }
    fi
fi

# 快捷命令
alias proxy='set_proxy'
alias unproxy='unset_proxy'
alias checkproxy='check_proxy'

# 测试代理连接
testproxy() {
    local urls=(
        "https://www.google.com"
        "https://github.com"
        "https://www.youtube.com"
    )
    
    echo "Testing proxy connectivity..."
    echo "Current IP: $(curl -s ip.gs)"
    echo
    
    for url in "${urls[@]}"; do
        echo "Testing $url:"
        curl -s -o /dev/null -w "Status: %{http_code}, Time: %{time_total}s\n" "$url"
    done
} 