#!/bin/bash

# Proxmox VE Cloud-Init Template Creator
# Author: Tiancaizhi9098
# GitHub: https://github.com/Tiancaizhi9098/Proxmox-VE-OS-Template

# 检查是否以root权限运行
if [ "$(id -u)" -ne 0 ]; then
    echo "此脚本需要root权限运行"
    exit 1
fi

# 检查是否在Proxmox环境中运行
if [ ! -f /usr/bin/pvesh ]; then
    echo "此脚本必须在Proxmox VE环境中运行"
    exit 1
fi

# 显示欢迎信息
echo "======================================================="
echo "       Proxmox VE Cloud-Init 模板创建工具"
echo "======================================================="
echo "此脚本用于快速创建Debian Cloud-Init模板虚拟机"
echo "兼容Proxmox VE 8.x 版本"
echo "GitHub: https://github.com/Tiancaizhi9098/Proxmox-VE-OS-Template"
echo "======================================================="
echo ""

# 获取系统版本
system_versions=("Debian 11" "Debian 12")
echo "请选择系统版本:"
select system_version in "${system_versions[@]}"; do
    if [ -n "$system_version" ]; then
        break
    else
        echo "请输入有效的选项"
    fi
done

# 设置下载URL
case "$system_version" in
    "Debian 11")
        image_url="https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2"
        image_name="debian-11-generic-amd64.qcow2"
        ;;
    "Debian 12")
        image_url="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
        image_name="debian-12-generic-amd64.qcow2"
        ;;
esac

# 获取VMID
while true; do
    read -p "请输入VMID (例如: 8000): " vmid
    if [[ "$vmid" =~ ^[0-9]+$ ]]; then
        # 检查VMID是否已存在
        if qm status $vmid >/dev/null 2>&1; then
            echo "VMID $vmid 已存在!"
            read -p "是否销毁现有虚拟机? (y/n): " destroy
            if [[ "$destroy" =~ ^[Yy]$ ]]; then
                echo "正在销毁VMID $vmid..."
                qm destroy $vmid --purge >/dev/null 2>&1
            else
                continue
            fi
        fi
        break
    else
        echo "请输入有效的数字!"
    fi
done

# 获取存储位置
storages=$(pvesh get /storage --output-format=json | jq -r '.[].storage')
echo "可用存储:"
select storage in $storages; do
    if [ -n "$storage" ]; then
        break
    else
        echo "请输入有效的选项"
    fi
done

# 获取网络设备
bridges=$(ip link show | grep -E 'vmbr[0-9]+' | awk -F': ' '{print $2}')
echo "可用网络桥接:"
select bridge in $bridges; do
    if [ -n "$bridge" ]; then
        break
    else
        echo "请输入有效的选项"
    fi
done

# 获取CPU核心数
read -p "请输入CPU核心数 (默认: 2): " cores
cores=${cores:-2}

# 获取内存大小
read -p "请输入内存大小(MB) (默认: 2048): " memory
memory=${memory:-2048}

# 获取磁盘大小
read -p "请输入磁盘大小(GB) (默认: 8): " disk_size
disk_size=${disk_size:-8}

# 下载镜像
echo "正在下载 $system_version 云镜像..."
if [ ! -d /var/lib/vz/template/iso ]; then
    mkdir -p /var/lib/vz/template/iso
fi

cd /var/lib/vz/template/iso
if [ -f "$image_name" ]; then
    read -p "镜像已存在，是否重新下载? (y/n): " redownload
    if [[ "$redownload" =~ ^[Yy]$ ]]; then
        rm -f "$image_name"
        wget -O "$image_name" "$image_url"
    fi
else
    wget -O "$image_name" "$image_url"
fi

# 创建虚拟机
echo "正在创建虚拟机..."
qm create $vmid --name "$system_version-template" --memory $memory --cores $cores --net0 virtio,bridge=$bridge

# 导入磁盘
echo "正在导入磁盘..."
qm importdisk $vmid "/var/lib/vz/template/iso/$image_name" $storage

# 配置虚拟机
echo "正在配置虚拟机..."
qm set $vmid --scsihw virtio-scsi-pci --scsi0 $storage:vm-$vmid-disk-0
qm set $vmid --boot c --bootdisk scsi0
qm set $vmid --ide2 $storage:cloudinit
qm set $vmid --serial0 socket --vga serial0
qm set $vmid --agent enabled=1
qm set $vmid --ipconfig0 ip=dhcp
qm resize $vmid scsi0 ${disk_size}G

# 配置Cloud-Init
echo "正在配置Cloud-Init..."
qm set $vmid --ciuser root
read -p "请输入root密码: " root_password
qm set $vmid --cipassword "$root_password"
qm set $vmid --sshkeys ~/.ssh/authorized_keys 2>/dev/null || true

# 转换为模板
echo "正在将虚拟机转换为模板..."
qm template $vmid

echo "======================================================="
echo "模板创建完成!"
echo "系统: $system_version"
echo "VMID: $vmid"
echo "存储: $storage"
echo "网络: $bridge"
echo "======================================================="
echo "使用以下命令基于此模板创建新的虚拟机:"
echo "qm clone $vmid NEW_VMID --name NEW_NAME"
echo "=======================================================" 