#!/bin/bash

# 设置颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 清屏
clear

# 显示标题
echo -e "${BLUE}=====================================================${NC}"
echo -e "${GREEN}       Proxmox VE OS Template Creator 安装脚本       ${NC}"
echo -e "${BLUE}=====================================================${NC}"
echo ""

# 检查是否为 root 用户运行
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}错误: 请使用 root 权限运行此脚本${NC}"
    echo -e "${YELLOW}使用 sudo 重新运行脚本${NC}"
    exit 1
fi

# 检查依赖
echo -e "${CYAN}检查依赖项...${NC}"
for pkg in wget jq git; do
    if ! command -v $pkg &> /dev/null; then
        echo -e "${YELLOW}安装 $pkg...${NC}"
        apt-get update -qq
        apt-get install -y -qq $pkg
        if [ $? -ne 0 ]; then
            echo -e "${RED}安装 $pkg 失败${NC}"
            exit 1
        fi
    fi
done

echo -e "${GREEN}所有依赖项已安装${NC}"

# 创建安装目录
INSTALL_DIR="/opt/proxmox-templates"
echo -e "${CYAN}创建安装目录 $INSTALL_DIR...${NC}"
mkdir -p $INSTALL_DIR

# 下载脚本
echo -e "${CYAN}下载脚本文件...${NC}"
cd $INSTALL_DIR

# 选择安装方式
echo -e "${CYAN}请选择安装方式:${NC}"
echo "1) 从GitHub下载最新版本"
echo "2) 从本地仓库克隆(开发用)"
read -p "请输入选项 [1-2]: " install_choice

case $install_choice in
    1)
        echo -e "${CYAN}从GitHub下载最新版本...${NC}"
        wget -q --show-progress -O proxmox_debian_template.sh https://raw.githubusercontent.com/Tiancaizhi9098/Proxmox-VE-OS-Template/main/proxmox_debian_template.sh
        ;;
    2)
        echo -e "${CYAN}从本地仓库克隆...${NC}"
        read -p "请输入本地仓库路径: " repo_path
        if [ ! -d "$repo_path" ]; then
            echo -e "${RED}错误: 路径不存在${NC}"
            exit 1
        fi
        cp "$repo_path/proxmox_debian_template.sh" ./proxmox_debian_template.sh
        ;;
    *)
        echo -e "${RED}无效选项，使用默认选项1${NC}"
        wget -q --show-progress -O proxmox_debian_template.sh https://raw.githubusercontent.com/Tiancaizhi9098/Proxmox-VE-OS-Template/main/proxmox_debian_template.sh
        ;;
esac

# 设置权限
echo -e "${CYAN}设置执行权限...${NC}"
chmod +x proxmox_debian_template.sh

# 创建快捷方式
echo -e "${CYAN}创建命令快捷方式...${NC}"
ln -sf $INSTALL_DIR/proxmox_debian_template.sh /usr/local/bin/pve-template

# 完成
echo -e "${GREEN}安装完成!${NC}"
echo -e "${YELLOW}您可以通过以下命令运行脚本:${NC}"
echo -e "${CYAN}   pve-template${NC}"
echo -e "${YELLOW}或者:${NC}"
echo -e "${CYAN}   $INSTALL_DIR/proxmox_debian_template.sh${NC}"

# 询问是否立即运行
echo ""
read -p "是否立即运行脚本? (y/n): " run_now

if [[ "$run_now" == [Yy]* ]]; then
    echo -e "${GREEN}启动脚本...${NC}"
    $INSTALL_DIR/proxmox_debian_template.sh
else
    echo -e "${YELLOW}您可以稍后运行脚本${NC}"
fi

exit 0
