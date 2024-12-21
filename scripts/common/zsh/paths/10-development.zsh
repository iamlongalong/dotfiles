# Golang
export GOROOT='/usr/local/go'
export GOPATH="$HOME/go"
export PATH="$GOROOT/bin:$GOPATH/bin:$PATH"

# Node.js
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

if command -v yarn &> /dev/null; then
    export PATH="$(yarn global bin):$PATH"
fi

# Python
if command -v pyenv &> /dev/null; then
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)" 
fi

# 获取普通用户名
get_normal_user() {
    # 获取第一个非 root 的用户常是主用户
    local user=$(who | grep -v root | head -n 1 | awk '{print $1}')
    if [ -z "$user" ]; then
        # 如果 who 命令没有结��，尝试从 /home 目录获取
        user=$(ls -ld /home/* | grep -v root | head -n 1 | awk '{print $3}')
    fi
    echo "$user"
}

brew() {
    echo -e "INFO: this is a brew wrapper\n"
    cmd="/home/linuxbrew/.linuxbrew/bin/brew $@"
    echo "$cmd"
    su - $(get_normal_user) -c "$cmd"

    echo -e "\nINFO: finish wrap brew"
}
