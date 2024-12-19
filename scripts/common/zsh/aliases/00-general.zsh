# 目录导航
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'

# ls 增强
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# 文件操作安全保护
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# 常用工具
alias c='code'
alias c.='code .'
alias v='vim'
alias g='git'

# 目录快捷方式
alias cdgo="cd ~/go/src"
alias cdcode="cd ~/code"
alias cddocs="cd ~/docs"
alias cdscripts="cd ~/scripts"

# 系统工具
alias ports='netstat -tulanp'
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias top='htop'

# 开发工具
alias gt="go mod tidy"
alias py="python3"
alias ipy="ipython"
alias pip="pip3" 