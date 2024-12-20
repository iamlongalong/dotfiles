#!/bin/bash

# 安装 nrm
echo "Installing nrm..."
npm install -g nrm

# 切换到淘宝源
echo "Switching to taobao registry..."
nrm use taobao

# 常用的全局包
npm install -g \
    pm2 \
    http-server \
    typescript \
    yarn 