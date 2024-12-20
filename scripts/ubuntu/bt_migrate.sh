#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查命令是否存在
check_command() {
    if ! command -v $1 &> /dev/null; then
        log_error "$1 命令未找到，请先安装"
        exit 1
    fi
}

# 检查root权限
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        log_error "请使用root权限运行此脚本"
        exit 1
    fi
}

# 检查宝塔面板是否安装
check_bt_panel() {
    if [ ! -f "/www/server/panel/class/common.py" ]; then
        log_error "未检测到宝塔面板，请先安装宝塔面板"
        exit 1
    fi
}

# 获取宝塔面板版本
get_bt_version() {
    local version=$(cat /www/server/panel/class/common.py 2>/dev/null | grep "version = " | cut -d"'" -f2)
    echo $version
}

# 备份函数
do_backup() {
    local BACKUP_DIR="/tmp/btpanel_backup"
    local BT_VERSION=$(get_bt_version)
    
    log_info "开始备份宝塔面板数据..."
    
    # 创建备份目录结构
    mkdir -p $BACKUP_DIR/{www/wwwroot,database_backup,panel,vhost/cert,config}
    
    # 保存面板版本信息
    echo $BT_VERSION > $BACKUP_DIR/config/version.info
    
    # 备份网站数据
    log_info "正在备份网站数据..."
    cp -rf /www/wwwroot/* $BACKUP_DIR/www/wwwroot/ 2>/dev/null || true
    
    # 备份数据库
    log_info "正在备份数据库..."
    local MYSQL_ROOT_PWD=$(cat /www/server/panel/default.pl 2>/dev/null)
    if [ -n "$MYSQL_ROOT_PWD" ]; then
        for DB in $(mysql -uroot -p$MYSQL_ROOT_PWD -e "SHOW DATABASES;" 2>/dev/null | grep -Ev "(Database|information_schema|performance_schema|mysql|sys)"); do
            mysqldump -uroot -p$MYSQL_ROOT_PWD --databases $DB > $BACKUP_DIR/database_backup/$DB.sql 2>/dev/null || log_warn "数据库 $DB 备份失败"
        done
    else
        log_warn "未找到MySQL root密码，跳过数据库备份"
    fi
    
    # 备份面板配置，排除不必要的目录
    log_info "正在备份面板配置..."
    cp -rf /www/server/panel/* $BACKUP_DIR/panel/ 2>/dev/null || true
    
    # 清理不需要的目录和文件
    rm -rf $BACKUP_DIR/panel/pyenv
    rm -rf $BACKUP_DIR/panel/node
    rm -rf $BACKUP_DIR/panel/__pycache__
    rm -rf $BACKUP_DIR/panel/class/__pycache__
    rm -rf $BACKUP_DIR/panel/logs/*
    
    # 备份SSL证书
    log_info "正在备份SSL证书..."
    cp -rf /www/server/panel/vhost/cert/* $BACKUP_DIR/vhost/cert/ 2>/dev/null || true
    
    # 备份站点配置
    log_info "正在备份站点配置..."
    cp -rf /www/server/panel/vhost/nginx/* $BACKUP_DIR/config/nginx/ 2>/dev/null || true
    cp -rf /www/server/panel/vhost/apache/* $BACKUP_DIR/config/apache/ 2>/dev/null || true
    
    # 打包备份文件
    log_info "正在打包备份文件..."
    cd /tmp
    tar -czf btpanel_backup.tar.gz btpanel_backup/
    mv btpanel_backup.tar.gz /root/
    
    # 清理临时文件
    rm -rf $BACKUP_DIR
    
    log_info "备份完成！备份文件保存在: /root/btpanel_backup.tar.gz"
}

# 检测系统类型和版本
get_os_info() {
    if [ -f /etc/redhat-release ]; then
        OS="centos"
        OS_VERSION=$(grep -oE '[0-9]+\.[0-9]+' /etc/redhat-release | cut -d "." -f1)
    elif [ -f /etc/lsb-release ]; then
        OS="ubuntu"
        OS_VERSION=$(grep "DISTRIB_RELEASE" /etc/lsb-release | cut -d "=" -f2)
    elif [ -f /etc/debian_version ]; then
        OS="debian"
        OS_VERSION=$(cat /etc/debian_version | cut -d "." -f1)
    else
        log_error "不支持的操作系统"
        exit 1
    fi
}

# 安装宝塔面板
install_bt_panel() {
    log_info "开始安装宝塔面板..."
    
    # 检查是否已安装
    if [ -f "/www/server/panel/class/common.py" ]; then
        log_info "宝塔面板已安装，跳过安装步骤"
        return 0
    fi
    
    get_os_info
    
    # 安装必要的依赖
    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        apt-get update -y
        apt-get install -y wget curl
    elif [ "$OS" = "centos" ]; then
        yum install -y wget curl
    fi
    
    # 下载并执行宝塔安装脚本
    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        wget -O install.sh http://download.bt.cn/install/install-ubuntu.sh
    elif [ "$OS" = "centos" ]; then
        wget -O install.sh http://download.bt.cn/install/install_6.0.sh
    fi
    
    # 检查下载是否成功
    if [ ! -f "install.sh" ]; then
        log_error "下载安装脚本失败"
        exit 1
    fi
    
    # 执行安装
    chmod +x install.sh
    bash install.sh
    
    # 检查安装结果
    if [ ! -f "/www/server/panel/class/common.py" ]; then
        log_error "宝塔面板安装失败"
        exit 1
    fi
    
    log_info "宝塔面板安装完成"
    
    # 等待面板服务完全启动
    sleep 5
}

# 恢��函数
do_restore() {
    local TEMP_DIR="/tmp/btpanel_restore"
    local BACKUP_FILE="/root/btpanel_backup.tar.gz"
    
    # 检查并安装宝塔面板
    if [ ! -f "/www/server/panel/class/common.py" ]; then
        log_warn "未检测到宝塔面板，准备安装..."
        install_bt_panel
    fi
    
    # 检查备份文件
    if [ ! -f "$BACKUP_FILE" ]; then
        log_error "未找到备份文件: $BACKUP_FILE"
        exit 1
    fi
    
    # 解压并获取备份版本
    mkdir -p $TEMP_DIR
    tar -xzf $BACKUP_FILE -C $TEMP_DIR
    
    local BACKUP_VERSION=$(cat $TEMP_DIR/btpanel_backup/config/version.info)
    local CURRENT_VERSION=$(get_bt_version)
    
    # 如果版本不一致，尝试更新到对应版本
    if [ "$BACKUP_VERSION" != "$CURRENT_VERSION" ]; then
        log_warn "备份版本($BACKUP_VERSION)与当前版本($CURRENT_VERSION)不一致"
        read -p "是否尝试更新面板到备份版本？[y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "尝试更新面板版本..."
            bt update
            # 重新获取当前版本
            CURRENT_VERSION=$(get_bt_version)
            if [ "$BACKUP_VERSION" != "$CURRENT_VERSION" ]; then
                log_warn "无法更新到完全相同的版本，可能会有兼容性问题"
                read -p "是否继续恢复？[y/N] " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    log_info "取消恢复操作"
                    rm -rf $TEMP_DIR
                    exit 0
                fi
            fi
        fi
    fi
    
    # 停止面板服务
    log_info "停止宝塔面板服务..."
    bt stop
    
    # 恢复网站数据
    log_info "正在恢复网站数据..."
    cp -rf $TEMP_DIR/btpanel_backup/www/wwwroot/* /www/wwwroot/ 2>/dev/null || true
    
    # 恢复数据库
    log_info "正在恢复数据库..."
    local MYSQL_ROOT_PWD=$(cat /www/server/panel/default.pl 2>/dev/null)
    if [ -n "$MYSQL_ROOT_PWD" ]; then
        for SQL_FILE in $TEMP_DIR/btpanel_backup/database_backup/*.sql; do
            [ -f "$SQL_FILE" ] || continue
            DB_NAME=$(basename "$SQL_FILE" .sql)
            mysql -uroot -p$MYSQL_ROOT_PWD -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`;" 2>/dev/null
            mysql -uroot -p$MYSQL_ROOT_PWD $DB_NAME < $SQL_FILE 2>/dev/null || log_warn "数据库 $DB_NAME 恢复失败"
        done
    else
        log_warn "未找到MySQL root密码，跳过数据库恢复"
    fi
    
    # 恢复面板配置
    log_info "正在恢复面板配置..."
    cp -rf $TEMP_DIR/btpanel_backup/panel/* /www/server/panel/
    
    # 恢复SSL证书
    log_info "正在恢复SSL证书..."
    cp -rf $TEMP_DIR/btpanel_backup/vhost/cert/* /www/server/panel/vhost/cert/
    
    # 恢复站点配置
    log_info "正在恢复站点配置..."
    cp -rf $TEMP_DIR/btpanel_backup/config/nginx/* /www/server/panel/vhost/nginx/ 2>/dev/null || true
    cp -rf $TEMP_DIR/btpanel_backup/config/apache/* /www/server/panel/vhost/apache/ 2>/dev/null || true
    
    # 修复权限
    log_info "修复文件权限..."
    chown -R www:www /www/wwwroot/
    chmod -R 755 /www/wwwroot/
    chown -R root:root /www/server/panel
    chmod -R 600 /www/server/panel/default.pl
    
    # 清理临时文件
    rm -rf $TEMP_DIR
    
    # 重启面板服务
    log_info "重启宝塔面板服务..."
    bt restart
    
    log_info "恢复完成！"
}

# 主函数
main() {
    case "$1" in
        backup)
            check_root
            check_command tar
            check_command mysql
            check_command mysqldump
            check_bt_panel
            do_backup
            ;;
        restore)
            check_root
            check_command tar
            check_command mysql
            check_command mysqldump
            do_restore
            ;;
        version)
            if [ -f "/www/server/panel/class/common.py" ]; then
                echo "宝塔面板版本: $(get_bt_version)"
            else
                echo "宝塔面板未安装"
            fi
            ;;
        *)
            echo "用法: $0 {backup|restore|version}"
            echo "  backup  - 备份宝塔面板数据"
            echo "  restore - 恢复宝塔面板数据"
            echo "  version - 显示面板版本"
            exit 1
            ;;
    esac
}

main "$@" 