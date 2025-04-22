#!/bin/bash

# 设置默认的虚拟环境路径
DEFAULT_VENV_PATH="$HOME/.python_env"

apt-get install -y python3.10-venv

# 检查是否已存在虚拟环境
if [ -d "$DEFAULT_VENV_PATH" ]; then
    echo "Virtual environment already exists at $DEFAULT_VENV_PATH"
    read -p "Do you want to remove and recreate it? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$DEFAULT_VENV_PATH"
    else
        echo "Using existing virtual environment"
        source "$DEFAULT_VENV_PATH/bin/activate"
        exit 0
    fi
fi

# 创建虚拟环境
echo "Creating virtual environment at $DEFAULT_VENV_PATH..."
python3 -m venv "$DEFAULT_VENV_PATH"

# 激活虚拟环境
echo "Activating virtual environment..."
source "$DEFAULT_VENV_PATH/bin/activate"

# 配置 pip 源
echo "Configuring pip mirror..."
mkdir -p ~/.pip
cat > ~/.pip/pip.conf << EOF
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
trusted-host = pypi.tuna.tsinghua.edu.cn
EOF

# 安装常用包
echo "Installing common Python packages..."
python3 -m pip install --upgrade pip
python3 -m pip install \
    ipython \
    pytest \
    black \
    flake8 \
    mypy \
    poetry

# 添加虚拟环境激活到 shell rc 文件
echo "Adding virtual environment activation to shell rc files..."

# 检查并添加到 .bashrc
if ! grep -q "source $DEFAULT_VENV_PATH/bin/activate" ~/.bashrc; then
    echo "source $DEFAULT_VENV_PATH/bin/activate" >> ~/.bashrc
fi

# 如果存在 .zshrc，也添加到其中
if [ -f ~/.zshrc ]; then
    if ! grep -q "source $DEFAULT_VENV_PATH/bin/activate" ~/.zshrc; then
        echo "source $DEFAULT_VENV_PATH/bin/activate" >> ~/.zshrc
    fi
fi

echo "Python environment setup completed!"
