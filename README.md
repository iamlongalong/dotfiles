# Dotfiles Manager

一个强大的跨平台（macOS/Ubuntu）dotfiles 管理工具，提供自动化的开发环境配置和管理功能。

## 功能特点

- 🚀 自动化安装和配置
- 🔄 跨平台支持 (macOS & Ubuntu)
- 🛠 模块化配置管理
- 🔒 安全的敏感信息处理
- 🌐 智能代理配置
- 📦 常用开发工具集成

## 系统要求

- macOS 10.15+ 或 Ubuntu 20.04+
- 4GB+ RAM
- 5GB+ 可用磁盘空间
- 基础开发工具 (git, curl, wget)

## 快速开始

```bash
# 克隆仓库
git clone https://github.com/yourusername/dotfiles.git
cd dotfiles

# 运行安装脚本
./install.sh
```

## 详细功能

### 基础工具安装
- Git 配置和别名
- Zsh + Oh My Zsh
- Vim + 插件
- tmux 配置
- 常用命令行工具

### 开发环境配置
- Node.js (通过 nvm)
- Python (通过 pyenv)
- Go
- Docker
- VS Code

### 代理配置
- HTTP/SOCKS5 代理支持
- proxychains4 集成
- 智能代理终端
- Git/npm 代理配置

### 证书管理
- mkcert 自动配置
- 本地 CA 证书管理

## 配置说明

### 代理设置
```bash
# 设置代理
proxy                      # 使用默认配置
proxy 192.168.1.100 8080  # 指定地址和端口

# 代理终端
proxyterm                 # 打开新的代理终端
pcterm                    # 打开 proxychains 终端

# 测试代理
testproxy                 # 测试代理连接
checkproxy                # 检查代理状态
```

### 开发工具配置
- Git 配置位于 `~/.gitconfig`
- Zsh 配置位于 `~/.zshrc` 和 `~/.config/zsh/`
- Vim 配置位于 `~/.vimrc`

## 目录结构

```
.
├── install.sh           # 主安装脚本
├── scripts/
│   ├── macos/          # macOS 特定脚本
│   ├── ubuntu/         # Ubuntu 特定脚本
│   └── common/         # 通用配置脚本
├── chezmoi.yaml        # chezmoi 配置
└── README.md           # 文档
```

## 故障排除

### 常见问题

1. 安装失败
   - 检查系统要求
   - 确保网络连接
   - 查看详细日志

2. 代理问题
   - 确认代理服务器可用
   - 检查端口配置
   - 使用 `testproxy` 诊断

3. 权限问题
   - 确保用户有 sudo 权限
   - 检查文件权限

### 日志位置
- 安装日志: `~/.dotfiles/logs/install.log`
- 错误日志: `~/.dotfiles/logs/error.log`

## 更新和维护

```bash
# 检查更新
./scripts/common/update.sh

# 备份配置
./scripts/common/backup.sh

# 卸载
./scripts/common/uninstall.sh
```

## 安全说明

- 敏感信息通过 chezmoi 模板管理
- API 密钥存储在加密配置中
- 证书安全存储在用户目录

## 贡献指南

1. Fork 本仓库
2. 创建特性分支
3. 提交更改
4. 发起 Pull Request

## 许可证

MIT License 