#!/bin/bash

# Proxmox VE 模板虚拟机创建脚本
# 作者: Tiancaizhi9098
# 仓库: https://github.com/Tiancaizhi9098/Proxmox-VE-OS-Template

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logo 显示
function show_logo {
    clear
    echo -e "${BLUE}"
    echo "   ____                                         _   ______"    
    echo "  / __ \_________  _  ______ ___  ____  _  __ | | / / __/"
    echo " / /_/ / __/ _ \ | |/_/ __ \__ \/ __ \| |/_/ | |/ / _/  "
    echo "/ ____/ / /  __/  >  < /_/ / / / /_/ />  <   |   / /___"
    echo "/_/   /_/  \___/ /_/|_\____/ /_/\____/_/|_|  |_|_/_____/"
    echo -e "${NC}"
    echo -e "${GREEN}========= Debian Cloud-Init 模板创建工具 =========${NC}"
    echo -e "${YELLOW}作者: Tiancaizhi9098${NC}"
    echo -e "${YELLOW}仓库: https://github.com/Tiancaizhi9098/Proxmox-VE-OS-Template${NC}"
    echo ""
}

# 检查是否为 root 用户
function check_root {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}错误: 请使用 root 用户权限运行此脚本${NC}" 
        exit 1
    fi
}

# 检查是否在 Proxmox VE 环境
function check_proxmox {
    if [ ! -f /usr/bin/pvesh ]; then
        echo -e "${RED}错误: 此脚本只能在 Proxmox VE 环境中运行${NC}"
        exit 1
    fi
}

# 检查必要工具
function check_tools {
    for cmd in qm curl wget; do
        if ! command -v $cmd &> /dev/null; then
            echo -e "${RED}错误: 未找到必要工具: $cmd${NC}"
            exit 1
        fi
    done
}

# 选择 Debian 版本
function select_debian_version {
    echo -e "${BLUE}请选择 Debian 版本:${NC}"
    echo "1) Debian 11 (Bullseye)"
    echo "2) Debian 12 (Bookworm)"
    read -p "请输入选项 [1-2]: " debian_choice
    
    case $debian_choice in
        1)
            DEBIAN_VERSION="11"
            DEBIAN_CODENAME="bullseye"
            ;;
        2)
            DEBIAN_VERSION="12"
            DEBIAN_CODENAME="bookworm"
            ;;
        *)
            echo -e "${RED}无效选项，请重新选择${NC}"
            select_debian_version
            ;;
    esac
    
    echo -e "${GREEN}已选择: Debian $DEBIAN_VERSION ($DEBIAN_CODENAME)${NC}"
}

# 选择存储位置
function select_storage {
    echo -e "${BLUE}可用存储位置:${NC}"
    pvesm status | grep -v 'local(dir)' | awk 'NR>1 {print NR-1") "$1}'
    
    # 获取存储数量
    storage_count=$(pvesm status | grep -v 'local(dir)' | awk 'NR>1 {print $1}' | wc -l)
    
    read -p "请选择存储位置 [1-$storage_count]: " storage_choice
    
    if [[ "$storage_choice" =~ ^[0-9]+$ ]] && [ "$storage_choice" -ge 1 ] && [ "$storage_choice" -le "$storage_count" ]; then
        STORAGE=$(pvesm status | grep -v 'local(dir)' | awk 'NR>1 {print $1}' | sed -n "${storage_choice}p")
        echo -e "${GREEN}已选择存储: $STORAGE${NC}"
    else
        echo -e "${RED}无效选项，请重新选择${NC}"
        select_storage
    fi
}

# 选择网络桥接
function select_network_bridge {
    echo -e "${BLUE}可用网络桥接:${NC}"
    bridges=$(ip link show | grep -E ': vmbr[0-9]+' | cut -d':' -f2 | tr -d ' ')
    
    if [ -z "$bridges" ]; then
        echo -e "${YELLOW}未找到网络桥接，使用默认值 vmbr0${NC}"
        BRIDGE="vmbr0"
        return
    fi
    
    # 显示可用的桥接接口
    bridge_count=0
    for bridge in $bridges; do
        bridge_count=$((bridge_count+1))
        echo "$bridge_count) $bridge"
    done
    
    read -p "请选择网络桥接 [1-$bridge_count]: " bridge_choice
    
    if [[ "$bridge_choice" =~ ^[0-9]+$ ]] && [ "$bridge_choice" -ge 1 ] && [ "$bridge_choice" -le "$bridge_count" ]; then
        BRIDGE=$(echo $bridges | tr ' ' '\n' | sed -n "${bridge_choice}p")
        echo -e "${GREEN}已选择网络桥接: $BRIDGE${NC}"
    else
        echo -e "${RED}无效选项，使用默认值 vmbr0${NC}"
        BRIDGE="vmbr0"
    fi
}

# 输入 VMID
function enter_vmid {
    read -p "请输入虚拟机 ID (VMID) [默认: 8000]: " VMID
    VMID=${VMID:-8000}
    
    # 检查 VMID 是否为数字
    if ! [[ "$VMID" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}错误: VMID 必须为数字${NC}"
        enter_vmid
        return
    fi
    
    # 检查 VMID 是否已存在
    if qm status $VMID &>/dev/null; then
        echo -e "${YELLOW}警告: VMID $VMID 已存在${NC}"
        read -p "是否删除现有虚拟机并继续? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}正在删除虚拟机 $VMID...${NC}"
            qm destroy $VMID --purge
        else
            echo -e "${YELLOW}请选择其他 VMID${NC}"
            enter_vmid
            return
        fi
    fi
    
    echo -e "${GREEN}使用 VMID: $VMID${NC}"
}

# 下载镜像
function download_image {
    echo -e "${BLUE}开始下载 Debian $DEBIAN_VERSION Cloud 镜像...${NC}"
    
    IMAGE_URL="https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2"
    
    if [ "$DEBIAN_VERSION" == "12" ]; then
        IMAGE_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
    fi
    
    IMAGE_NAME="debian-$DEBIAN_VERSION-generic-amd64.qcow2"
    
    # 下载镜像
    echo -e "${YELLOW}下载中，请稍候...${NC}"
    wget -q --show-progress -O /tmp/$IMAGE_NAME $IMAGE_URL
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}下载失败！${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}镜像下载完成: /tmp/$IMAGE_NAME${NC}"
}

# 创建虚拟机
function create_vm {
    echo -e "${BLUE}开始创建虚拟机...${NC}"
    
    # 创建新的虚拟机
    qm create $VMID --name "debian-$DEBIAN_VERSION-template" --memory 2048 --cores 2 --net0 virtio,bridge=$BRIDGE
    
    # 导入磁盘
    qm importdisk $VMID /tmp/$IMAGE_NAME $STORAGE
    
    # 配置磁盘
    qm set $VMID --scsihw virtio-scsi-pci --scsi0 $STORAGE:vm-$VMID-disk-0
    
    # 设置启动顺序
    qm set $VMID --boot c --bootdisk scsi0
    
    # 添加 Cloud-Init 驱动
    qm set $VMID --ide2 $STORAGE:cloudinit
    
    # 配置显示
    qm set $VMID --serial0 socket --vga serial0
    
    # 启用 SSH 和密码登录
    qm set $VMID --ciuser root
    qm set $VMID --cipassword-crypted '$6$rounds=656000$nXODm5eaXWUkm5MI$q4L81.eM8tfKLrgTLVkptL8.QicrhDR9hCw34D5FDFrjlGztA47zWaKaFqZXTa9Oe3CtIstZEQXv5jb.uwFuK0'  # Password: "proxmox"
    qm set $VMID --sshkeys /root/.ssh/authorized_keys 2>/dev/null || true
    
    # 转换为模板
    echo -e "${BLUE}正在将虚拟机转换为模板...${NC}"
    qm template $VMID
    
    # 删除临时文件
    rm -f /tmp/$IMAGE_NAME
    
    echo -e "${GREEN}Debian $DEBIAN_VERSION 模板创建完成！${NC}"
    echo -e "${YELLOW}VMID: $VMID${NC}"
    echo -e "${YELLOW}初始 root 密码: proxmox${NC}"
}

# 主函数
function main {
    show_logo
    check_root
    check_proxmox
    check_tools
    
    select_debian_version
    select_storage
    select_network_bridge
    enter_vmid
    
    download_image
    create_vm
    
    echo -e "${GREEN}=========================================================${NC}"
    echo -e "${GREEN}✅ 模板创建成功!${NC}"
    echo -e "${YELLOW}系统: Debian $DEBIAN_VERSION${NC}"
    echo -e "${YELLOW}VMID: $VMID${NC}"
    echo -e "${YELLOW}用户名: root${NC}"
    echo -e "${YELLOW}密码: proxmox${NC}"
    echo -e "${GREEN}=========================================================${NC}"
    echo -e "${BLUE}您现在可以从此模板克隆新的虚拟机:${NC}"
    echo -e "${YELLOW}qm clone $VMID <新VMID> --name <新虚拟机名>${NC}"
    echo ""
    echo -e "${RED}注意: 请记得在首次使用前修改默认密码!${NC}"
}

# 执行主函数
main
