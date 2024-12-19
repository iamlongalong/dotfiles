# 基础设置
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export EDITOR='vim'
export VISUAL='vim'
export PAGER='less'

# 历史记录设置
export HISTSIZE=50000
export HISTFILE="$HOME/.zsh_history"
export SAVEHIST=10000
export HISTCONTROL=ignoreboth:erasedups

# 代理设置
export PROXY_HOST=127.0.0.1
export PROXY_PORT=7890
export PROXY_PROTOCOL=http

# 开发环境设置
export GOSUMDB='sum.golang.google.cn'
export GOPROXY='https://goproxy.cn,direct'

# 证书设置
export CAROOT="$HOME/.local/share/mkcert"
# 确保证书目录存在
[ ! -d "$CAROOT" ] && mkdir -p "$CAROOT"

# 注意：敏感配置（如 API keys、服务地址等）应该从安全的配置源加载
# 例如：~/.config/secrets/env 或系统的密钥管理服务