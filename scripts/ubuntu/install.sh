#!/bin/bash

echo "Starting Ubuntu setup..."

# 配置主机名
setup_hostname() {
    echo "Current hostname: $(hostname)"
    read -p "Do you want to change hostname? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter new hostname: " hostname
        if [ -n "$hostname" ]; then
            # 修改 hostname 文件
            echo "$hostname" | sudo tee /etc/hostname
            # 更新 hosts 文件
            sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$hostname/g" /etc/hosts
            # 立即生效
            sudo hostnamectl set-hostname "$hostname"
            echo "Hostname has been updated to: $hostname"
            echo "Please reboot for changes to take full effect."
        fi
    fi
}

# 执行主机名设置
setup_hostname

# 更新系统
echo "Updating system..."
sudo apt update && sudo apt upgrade -y

# 安装基础工具
echo "Installing basic tools..."
sudo apt install -y \
    git \
    curl \
    wget \
    tree \
    jq \
    ripgrep \
    fd-find \
    bat \
    build-essential \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    screen \
    vim \
    ffmpeg \
    proxychains4

# 配置 proxychains4
echo "Configuring proxychains4..."
sudo cp /etc/proxychains4.conf /etc/proxychains4.conf.bak
sudo tee /etc/proxychains4.conf > /dev/null << 'EOF'
# proxychains.conf  VER 4.x
strict_chain
proxy_dns
remote_dns_subnet 224
tcp_read_time_out 15000
tcp_connect_time_out 8000
localnet 127.0.0.0/255.0.0.0
localnet 10.0.0.0/255.0.0.0
localnet 172.16.0.0/255.240.0.0
localnet 192.168.0.0/255.255.0.0

[ProxyList]
socks5 127.0.0.1 7890
http 127.0.0.1 7890
EOF

# 安装 youtube-dl
sudo curl -L https://yt-dl.org/downloads/latest/youtube-dl -o /usr/local/bin/youtube-dl
sudo chmod a+rx /usr/local/bin/youtube-dl

# 安装 Linuxbrew
echo "Installing Linuxbrew..."
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.profile
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# 配置 Homebrew 国内源
echo "Configuring Homebrew mirrors..."
git -C "$(brew --repo)" remote set-url origin https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git
git -C "$(brew --repo homebrew/core)" remote set-url origin https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git
brew update

# 使用 Homebrew 安装额外工具
echo "Installing additional tools with Homebrew..."
brew install \
    lazydocker \
    asciiquarium \
    pyenv \
    mkcert

# 安装 NVM
echo "Installing NVM..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install --lts
nvm use --lts
npm install -g yarn

# 安装 PM2
echo "Installing PM2..."
npm install -g pm2

# 安装 Go
echo "Installing Go..."
wget https://go.dev/dl/go1.21.5.linux-amd64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz
rm go1.21.5.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.profile

# 配置 Python 环境
echo "Configuring Python environment..."
eval "$(pyenv init -)"
pyenv install 3.11.4
pyenv global 3.11.4
pip install --upgrade pip
pip install poetry

# 安装 Docker
echo "Installing Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io
sudo usermod -aG docker $USER

# 安装 VS Code
echo "Installing Visual Studio Code..."
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
rm -f packages.microsoft.gpg
sudo apt update
sudo apt install -y code

# 安装 Oh My Zsh
echo "Installing Zsh and Oh My Zsh..."
sudo apt install -y zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# 安装 Zsh 插件
echo "Installing Zsh plugins..."
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# 安装 Vim 插件管理器
echo "Installing Vim-Plug..."
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# 配置 Git
echo "Configuring Git..."
cp ../common/gitconfig ~/.gitconfig

# 设置 mkcert
echo "Setting up mkcert..."
chmod +x ../common/setup_mkcert.sh
../common/setup_mkcert.sh

echo "Ubuntu setup completed!" 