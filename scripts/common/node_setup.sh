#!/bin/bash

# 安装 nrm
if command -v npm &> /dev/null; then
    echo "Installing nrm..."
    npm install -g nrm
fi

# 切换到淘宝源
if command -v nrm &> /dev/null; then
    echo "Switching to taobao registry..."
    nrm use taobao
fi

# 常用的全局包
if command -v npm &> /dev/null; then
    npm install -g \
        pm2 \
        http-server \
        typescript \
        yarn 
fi