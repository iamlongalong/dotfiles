# Oh My Zsh 配置
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="long-theme"

# 插件配置
plugins=(
    git
    z
    extract
    docker
    kubectl
    pyenv
    npm
    yarn
    zsh-autosuggestions
    zsh-syntax-highlighting
)

# 加载 Oh My Zsh
source $ZSH/oh-my-zsh.sh

# 加载其他配置
for config_dir in exports aliases functions paths completions; do
    if [ -d "$HOME/.config/zsh/$config_dir" ]; then
        for config_file in "$HOME/.config/zsh/$config_dir"/*.zsh(N); do
            [ -f "$config_file" ] && source "$config_file"
        done
    fi
done

# 加载本地配置（如果存在）
[ -f ~/.zshrc.local ] && source ~/.zshrc.local 
