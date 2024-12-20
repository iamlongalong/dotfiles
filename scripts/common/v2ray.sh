#!/bin/bash

gen_v2ray_config() {
    # 检查是否提供了 Base64 编码的连接串作为参数
    if [ $# -ne 1 ]; then
    echo "Usage: $0 <base64_encoded_string>"
    exit 1
    fi

    encoded_string=$1

    # 去掉 vmess:// 前缀
    encoded_string=${encoded_string#vmess://}

    # 修复 Base64 填充问题
    encoded_string=$(echo "${encoded_string}" | tr -d '\n' | sed 's/=*$//')
    padding_len=$((4 - ${#encoded_string} % 4))
    if [ $padding_len -ne 4 ]; then
        encoded_string="${encoded_string}$(printf '=%.0s' $(seq 1 $padding_len))"
    fi

    # 添加调试输出
    echo "解码前的字符串: ${encoded_string}"
    
    # 解码 Base64 编码的字符串
    decoded_string=$(echo "${encoded_string}" | base64 -d 2>/dev/null)
    
    # 添加调试输出
    echo "解码后的 JSON: ${decoded_string}"

    # 检查解码是否成功
    if [ $? -ne 0 ]; then
        echo "Base64 解码失败，请检查连接串是否正确。"
        exit 1
    fi

    # 验证解码后的字符串是否为有效的 JSON
    if ! echo "${decoded_string}" | jq empty 2>/dev/null; then
        echo "解码后的内容不是有效的 JSON 格式"
        exit 1
    fi

    # 先测试 JSON 转换
    echo "正在测试 JSON 转换..."
    echo "${decoded_string}" | jq '.' || echo "JSON 解析失败"
    
    # 格式化 JSON 输出
    echo "开始生成配置..."
    config=$(echo "${decoded_string}" | jq -r '
    {
        "inbounds": [
            {
                "port": 7890,
                "listen": "127.0.0.1",
                "protocol": "socks",
                "settings": {
                    "auth": "noauth",
                    "udp": false
                }
            }
        ],
        "outbounds": [
            {
                "protocol": "vmess",
                "settings": {
                    "vnext": [
                        {
                            "address": .add,
                            "port": (.port | tonumber),
                            "users": [
                                {
                                    "id": .id,
                                    "alterId": (.aid | tonumber),
                                    "security": "auto"
                                }
                            ]
                        }
                    ]
                },
                "streamSettings": {
                    "network": .net,
                    "security": (if .tls == "tls" then "tls" else "none" end),
                    "wsSettings": {
                        "path": .path,
                        "headers": {"Host": (.host // .add)}
                    },
                    "tlsSettings": {
                        "allowInsecure": false,
                        "serverName": (.host // .add)
                    }
                }
            }
        ]
    }')

    # 检查 jq 命令的返回值
    jq_exit_code=$?
    echo "jq 命令返回值: ${jq_exit_code}"

    # 显示生成的配置
    echo "生成的配置:"
    echo "${config}"

    # 增强错误检查
    if [ -z "${config}" ] || [ ${jq_exit_code} -ne 0 ]; then
        echo "配置生成失败，请检查连接串格式是否正确"
        exit 1
    fi

    # 使用 apt 安装的默认配置文件位置
    config_file="/etc/v2ray/config.json"
    
    # 确保目录存在并设置正确的权限
    sudo mkdir -p /etc/v2ray
    # back up old config
    sudo mv ${config_file} ${config_file}.bak
    # write new config
    echo "${config}" | sudo tee ${config_file} > /dev/null
    sudo chmod 644 ${config_file}

    echo "配置文件已生成：${config_file}"
    
    # 重启 V2Ray 服务
    echo "重启 V2Ray 服务..."
    sudo systemctl restart v2ray
    
    # 检查服务状态
    echo "检查 V2Ray 服务状态..."
    sudo systemctl status v2ray --no-pager
}

install_v2ray() {
    # 检查是否已安装
    if ! command -v v2ray &> /dev/null; then
        echo "正在安装 V2Ray..."
        # 添加 V2Ray 官方软件源
        sudo apt update
        sudo apt install -y curl gnupg
        curl https://apt.v2fly.org/pub.gpg | sudo apt-key add -
        echo "deb https://apt.v2fly.org/ stable main" | sudo tee /etc/apt/sources.list.d/v2ray.list
        
        # 更新软件源并安装
        sudo apt update
        sudo apt install -y v2ray
    else
        echo "V2Ray 已经安装"
    fi
}

main() {
    # 检查是否以 root 权限运行
    if [ "$EUID" -ne 0 ]; then 
        echo "请使用 sudo 运行此脚本"
        exit 1
    fi

    install_v2ray
    read -p "请输入 Base64 编码的连接串: " encoded_string
    gen_v2ray_config "$encoded_string"
}

main