# Dotfiles Manager

一个强大的跨平台（macOS/Ubuntu）dotfiles 管理工具，提供自动化的开发环境配置和管理功能。采用模块化脚本设计，支持智能代理配置。

## 功能特点

- 🚀 自动化安装和配置
- 🔄 跨平台支持 (macOS & Ubuntu)
- 🛠 模块化的配置管理
- 🔒 安全的敏感信息处理
- 🌐 智能代理配置 (支持 V2Ray)
- 📦 常用开发工具集成

## 系统要求

### 基础要求
- macOS 10.15+ 或 Ubuntu 20.04+
- 4GB+ RAM
- 5GB+ 可用磁盘空间

### 必需工具
- git
- curl 或 wget
- sudo 权限

## 快速开始

1. 克隆仓库：
```bash
git clone https://github.com/iamlongalong/dotfiles.git
cd dotfiles
```

2. 运行基础安装脚本：
```bash
chmod +x install.sh
./install.sh
```

3. 根据提示进行配置：
   - 设置主机名（可选）
   - 选择是否配置 V2Ray（仅 Ubuntu）
   - 配置代理设置（可选）
   - 选择安装可选应用（Feishu, WeChat等）

4. 设置开发环境：
```bash
# 设置 ZSH 环境（必需）
./scripts/common/setup_zsh.sh

```

5. 重新打开终端以使所有配置生效

## 自动安装的组件

### 基础工具
- Git 配置和别名
- 常用命令行工具（wget, curl, tree, jq, ripgrep, fd, bat, exa等）

### 开发环境
- Node.js（通过 NVM，自动安装 LTS 版本）
- Python（通过 pyenv + poetry）
- Go
- Docker
- VS Code

### 应用程序
#### 自动安装
- Visual Studio Code
- Docker Desktop
- Google Chrome
- iTerm2 (macOS)
- Postman
- Rectangle (macOS)
- Arc Browser
- uTools
- Keka (macOS)
- balenaEtcher

#### 可选安装
- Feishu
- WeChat
- PicGo
- Obsidian

### 需要手动设置的组件
1. setup config
```bash

```

## 配置说明

### 代理设置
```bash
# 设置代理
proxy                      # 使用默认配置 (127.0.0.1:7890)
proxy 192.168.1.100 8080  # 指定地址和端口

# 代理终端
proxyterm                 # 打开新的代理终端
pcterm                    # 打开 proxychains 终端

# 测试代理
testproxy                 # 测试代理连接
checkproxy                # 检查代理状态
```

### 配置文件位置
- Git 配置: `~/.gitconfig`
- Zsh 配置: `~/.zshrc` 和 `~/.config/zsh/`
- V2Ray 配置: `~/.config/v2ray/config.json`
- NVM 配置: `~/.nvm/`

## 目录结构

```
.
├── install.sh           # 主安装脚本
├── scripts/
│   ├── macos/          # macOS 特定脚本
│   │   └── install.sh  # macOS 安装脚本
│   ├── ubuntu/         # Ubuntu 特定脚本
│   │   └── install.sh  # Ubuntu 安装脚本
│   └── common/         # 通用配置脚本
│       ├── aliases/    # 常用别名配置
│       ├── zsh/        # ZSH 相关配置
│       ├── utils.sh    # 工具函数
│       ├── v2ray.sh    # V2Ray 安装脚本
│       ├── gitconfig   # Git 默认配置
│       ├── functions.sh     # 基础函数
│       └── functions_extra.sh # 扩展函数
└── README.md           # 文档
```

## 故障排除

### 常见问题

1. 安装失败
   - 检查系统要求和必需工具
   - 确保网络连接正常
   - 查看安装日志 (`~/.dotfiles/logs/install.log`)
   - 确认是否有足够的磁盘空间

2. 代理问题
   - 确认代理服务器可用性
   - 检查端口是否被占用
   - V2Ray 配置是否正确
   - 使用 `testproxy` 进行诊断

3. 环境变量问题
   - NVM: 重新打开终端或运行 `source ~/.zshrc`
   - Python: 确认 pyenv 和 poetry 在 PATH 中
   - Zsh: 确认插件已正确安装并在 ~/.zshrc 中启用

### 日志位置
- 安装日志: `~/.dotfiles/logs/install.log`
- 错误日志: `~/.dotfiles/logs/error.log`
- V2Ray 日志: `~/.dotfiles/logs/v2ray.log`

## 更新和维护

```bash
# 检查更新
./scripts/common/update.sh

# 卸载
./scripts/common/uninstall.sh
```

## 安全说明

- 配置文件存储在用户目录下的对应位置
- API 密钥和证书安全存储在用户目录
- 代理配置仅在会话期间有效
- V2Ray 配置文件权限受限

## 贡献指南

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 发起 Pull Request

## 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件