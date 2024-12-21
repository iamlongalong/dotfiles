# 创建目录并进入
mkd() {
    mkdir -p "$@" && cd "$_"
}

# 提取压缩文件
extract() {
    if [ -f $1 ]; then
        case $1 in
            *.tar.bz2)   tar xjf $1     ;;
            *.tar.gz)    tar xzf $1     ;;
            *.bz2)       bunzip2 $1     ;;
            *.rar)       unrar e $1     ;;
            *.gz)        gunzip $1      ;;
            *.tar)       tar xf $1      ;;
            *.tbz2)      tar xjf $1     ;;
            *.tgz)       tar xzf $1     ;;
            *.zip)       unzip $1       ;;
            *.Z)         uncompress $1  ;;
            *.7z)        7z x $1        ;;
            *)          echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# 显示目录大小
duf() {
    du -sk "$@" | sort -n | while read size fname; do
        for unit in k M G T P E Z Y; do
            if [ $size -lt 1024 ]; then
                echo -e "${size}${unit}\t${fname}"
                break
            fi
            size=$((size/1024))
        done
    done
}

# 快速查找文件
ff() { find . -type f -iname "*$@*" 2>/dev/null; }
fd() { find . -type d -iname "*$@*" 2>/dev/null; }

# 历史命令搜索
hs() { history | grep "$@"; }

# 进程查找
psg() { ps aux | grep "$@" | grep -v grep; }

# 快速备份文件
backup() { cp "$1"{,.bak}; }

# 快速HTTP服务器
serve() {
    local port="${1:-8000}"
    python3 -m http.server "$port"
}

# 快速查看 JSON
json() {
    if [ -p /dev/stdin ]; then
        # 如果有管道输入
        cat - | python3 -m json.tool
    else
        # 如果是文件
        cat "$1" | python3 -m json.tool
    fi
}

# Git 相关函数
gdiff() {
    preview="git diff $@ --color=always -- {-1}"
    git diff $@ --name-only | fzf -m --ansi --preview $preview
}

# 快速切换目录
j() {
    [ $# -gt 0 ] && z "$*" && return
    cd "$(z -l 2>&1 | fzf --height 40% --nth 2.. --reverse --inline-info +s --tac --query "${*##-* }" | sed 's/^[0-9,.]* *//')"
}

# Docker 相关函数
dstop() { docker stop $(docker ps -a -q); }
dri() { docker rmi $(docker images -q); }
dex() { docker exec -it "$@" /bin/bash; }
dlog() { docker logs -f "$@"; }

# 快速编辑配置文件
zshconfig() { $EDITOR ~/.zshrc; }
vimconfig() { $EDITOR ~/.vimrc; }
tmuxconfig() { $EDITOR ~/.tmux.conf; }

# 快速查看天气
weather() {
    local city="${1:-beijing}"
    curl "wttr.in/$city?format=v2"
}

# 快速生成密码
genpass() {
    local length="${1:-16}"
    openssl rand -base64 48 | cut -c1-$length
}

# 快速查看 IP
myip() {
    echo "Public IP: $(curl -s ifconfig.me)"
    echo "Local IP: $(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}')"
}

# 快速计算 MD5
md5() {
    echo -n "$1" | md5sum | cut -d' ' -f1
}

# 快速计算 SHA256
sha256() {
    echo -n "$1" | sha256sum | cut -d' ' -f1
}

# 快速查看端口占用
port() {
    lsof -i ":$1"
}

# 快速查看系统信息
sysinfo() {
    echo "OS: $(uname -s)"
    echo "Kernel: $(uname -r)"
    echo "Memory: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
    echo "Disk: $(df -h / | awk 'NR==2 {print $3 "/" $2}')"
    echo "CPU: $(grep "model name" /proc/cpuinfo | head -n1 | cut -d: -f2)"
    echo "Load: $(uptime | awk -F'load average:' '{print $2}')"
} 