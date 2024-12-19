#!/bin/bash

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
pip install -U pip
pip install \
    ipython \
    pytest \
    black \
    flake8 \
    mypy \
    poetry 