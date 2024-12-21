# 快速创建并进入临时目录
tmpd() {
    local dir
    dir=$(mktemp -d)
    echo "Created temp directory $dir"
    cd "$dir" || exit
}

# 快速查找大文件
bigfiles() {
    local dir=${1:-.}
    local limit=${2:-10}
    find "$dir" -type f -exec du -ah {} + | sort -rh | head -n "$limit"
}

# 快速查找大目录
bigdirs() {
    local dir=${1:-.}
    local limit=${2:-10}
    du -h "$dir"/* | sort -rh | head -n "$limit"
}

# Git 仓库状态检查
gitcheck() {
    local dir=${1:-.}
    for d in "$dir"/*/.git; do
        local repo=${d%/*}
        echo "Checking ${repo}..."
        (cd "$repo" && git status -s)
    done
}

# 快速设置代理
proxy() {
    local port="${1:-7890}"
    export http_proxy="socks5://127.0.0.1:$port"
    export https_proxy="socks5://127.0.0.1:$port"
    export all_proxy="socks5://127.0.0.1:$port"
    echo "Proxy set to socks5://127.0.0.1:$port"
}

# 取消代理
noproxy() {
    unset http_proxy
    unset https_proxy
    echo "Proxy settings removed"
}

# 快速查找并杀死进程
killp() {
    local pattern=$1
    local pid
    pid=$(ps aux | grep "$pattern" | grep -v grep | awk '{print $2}')
    if [ -n "$pid" ]; then
        echo "Killing process $pid ($pattern)"
        kill -9 "$pid"
    else
        echo "No process found matching pattern: $pattern"
    fi
}

# 快速创建 Go 项目结构
goproject() {
    local name=$1
    if [ -z "$name" ]; then
        echo "Please provide a project name"
        return 1
    fi
    mkdir -p "$name"/{cmd,internal,pkg,api,docs,scripts,test}
    cd "$name" || return
    go mod init "$name"
    cat > README.md << EOF
# $name

## Description

## Installation

## Usage

## License
EOF
    echo "Created Go project structure in $name"
}

# 快速创建 Python 项目结构
pyproject() {
    local name=$1
    if [ -z "$name" ]; then
        echo "Please provide a project name"
        return 1
    fi
    mkdir -p "$name"/{src,tests,docs,scripts}
    cd "$name" || return
    python -m venv venv
    cat > README.md << EOF
# $name

## Description

## Installation

## Usage

## License
EOF
    echo "Created Python project structure in $name"
}

# 快速查找文本
ft() {
    local pattern=$1
    local dir=${2:-.}
    rg --color=always --line-number --no-heading --smart-case "$pattern" "$dir" |
        fzf --ansi \
            --color "hl:-1:underline,hl+:-1:underline:reverse" \
            --delimiter : \
            --preview 'bat --color=always {1} --highlight-line {2}' \
            --preview-window 'up,60%,border-bottom,+{2}+3/3,~3'
}

# 快速查看 JSON 格式的日志
jsonlog() {
    local file=$1
    if [ -p /dev/stdin ]; then
        # 如果是管道输入
        jq -R 'fromjson? // .' | jq -r '.'
    else
        # 如果是文件
        jq -R 'fromjson? // .' "$file" | jq -r '.'
    fi
}

# 快速生成自签名证书
gencert() {
    local domain=${1:-localhost}
    local days=${2:-365}
    openssl req -x509 -newkey rsa:4096 -sha256 -days "$days" \
        -nodes -keyout "$domain.key" -out "$domain.crt" \
        -subj "/CN=$domain" \
        -addext "subjectAltName=DNS:$domain,DNS:*.$domain,IP:127.0.0.1"
    echo "Generated certificate for $domain (valid for $days days)"
}

# 快速查看 Markdown 文件
mdview() {
    local file=$1
    if [ -f "$file" ]; then
        pandoc "$file" | lynx -stdin
    else
        echo "File not found: $file"
    fi
}

# 快速查看 CSV 文件
csvview() {
    local file=$1
    if [ -f "$file" ]; then
        column -t -s, "$file" | less -S
    else
        echo "File not found: $file"
    fi
}

# 快速查看系统资源使用情况
sys() {
    echo "CPU Usage:"
    top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4"%"}'
    echo
    echo "Memory Usage:"
    free -h | awk 'NR==2{printf "%s/%s (%.2f%%)\n", $3,$2,$3/$2*100}'
    echo
    echo "Disk Usage:"
    df -h / | awk 'NR==2{printf "%s/%s (%.2f%%)\n", $3,$2,$5}'
    echo
    echo "Network:"
    netstat -an | grep ESTABLISHED | wc -l | xargs echo "ESTABLISHED connections:"
}

# 快速查看 Docker 资源使用情况
dstats() {
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
}

# 快速清理 Docker 资源
dclean() {
    echo "Cleaning Docker resources..."
    docker container prune -f
    docker image prune -f
    docker network prune -f
    docker volume prune -f
    echo "Done!"
}

# 快速启动开发环境
devenv() {
    tmux new-session -d -s dev
    tmux split-window -h
    tmux split-window -v
    tmux select-pane -t 0
    tmux send-keys 'vim' C-m
    tmux select-pane -t 1
    tmux send-keys 'git status' C-m
    tmux select-pane -t 2
    tmux attach-session -d
}

# 快速查看 Git 提交统计
gitstats() {
    echo "Commit count by author:"
    git shortlog -sn --all
    echo
    echo "File count by type:"
    git ls-files | sed 's/.*\.//' | sort | uniq -c | sort -nr
    echo
    echo "Commit count by month:"
    git log --format='%ai' | cut -d'-' -f1,2 | sort | uniq -c
} 