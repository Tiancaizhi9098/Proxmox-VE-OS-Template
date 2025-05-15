#!/bin/bash

# ========================================================
# 项目：Proxmox-VE-OS-Template
# 作者：Tiancaizhi9098 (https://github.com/Tiancaizhi9098)
# 仓库：https://github.com/Tiancaizhi9098/Proxmox-VE-OS-Template
# 描述：用于创建多种Linux发行版的PVE模板工具
# 一键执行命令: bash <(curl -s https://raw.githubusercontent.com/Tiancaizhi9098/Proxmox-VE-OS-Template/main/create_pve_templates.sh)
# ========================================================

# 设置错误处理
set -o pipefail
trap 'echo -e "\n脚本执行出错，退出中..." >&2; exit 1' ERR

# 定义颜色
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # 无颜色

# 标记是否已经检查过依赖
DEPS_CHECKED=0

# 显示LOGO
function show_logo() {
    clear
    echo -e "${BLUE}"
    echo " ████████╗██╗ █████╗ ███╗   ██╗ ██████╗ █████╗ ██╗███████╗██╗  ██╗██╗"
    echo " ╚══██╔══╝██║██╔══██╗████╗  ██║██╔════╝██╔══██╗██║╚══███╔╝██║  ██║██║"
    echo "    ██║   ██║███████║██╔██╗ ██║██║     ███████║██║  ███╔╝ ███████║██║"
    echo "    ██║   ██║██╔══██║██║╚██╗██║██║     ██╔══██║██║ ███╔╝  ██╔══██║██║"
    echo "    ██║   ██║██║  ██║██║ ╚████║╚██████╗██║  ██║██║███████╗██║  ██║██║"
    echo "    ╚═╝   ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝╚═╝  ╚═╝╚═╝╚══════╝╚═╝  ╚═╝╚═╝"
    echo -e "${NC}"
    echo -e "${GREEN}云镜像定制与PVE模板创建工具${NC}"
    echo -e "${YELLOW}GitHub: https://github.com/Tiancaizhi9098/Proxmox-VE-OS-Template${NC}"
    echo ""
}

# 检查系统兼容性
function check_system() {
    echo -e "${BLUE}检查系统兼容性...${NC}"
    
    # 检查是否为Proxmox VE
    if [ ! -f /usr/bin/pveversion ]; then
        echo -e "${RED}错误: 此脚本只能在Proxmox VE上运行${NC}"
        exit 1
    fi
    
    # 检查是否有足够的空间
    available_space=$(df -h /root | awk 'NR==2 {print $4}')
    echo -e "${GREEN}系统检查通过. 可用空间: $available_space${NC}"
}

# 检查依赖
function check_dependencies() {
    # 如果已经检查过，直接返回
    if [ "$DEPS_CHECKED" -eq 1 ]; then
        return 0
    fi
    
    echo -e "${BLUE}检查依赖...${NC}"
    
    # 检查是否安装了libguestfs-tools
    if ! command -v virt-customize &> /dev/null; then
        echo -e "${YELLOW}安装libguestfs-tools...${NC}"
        apt update
        apt install -y libguestfs-tools
        
        if ! command -v virt-customize &> /dev/null; then
            echo -e "${RED}错误: 无法安装libguestfs-tools，请手动安装后再试${NC}"
            exit 1
        fi
    fi
    
    # 检查cloud-init工具
    if ! command -v cloud-localds &> /dev/null; then
        echo -e "${YELLOW}安装cloud-init工具...${NC}"
        apt update
        apt install -y cloud-init
        
        if ! command -v cloud-localds &> /dev/null; then
            echo -e "${YELLOW}警告: cloud-init已安装但cloud-localds命令不可用。继续执行...${NC}"
            # 不再退出，而是继续执行
        fi
    else
        echo -e "${GREEN}cloud-init工具已安装${NC}"
    fi
    
    # 检查基本工具
    if ! command -v wget &> /dev/null || ! command -v curl &> /dev/null; then
        echo -e "${YELLOW}安装基本工具...${NC}"
        apt update
        apt install -y curl wget file
    fi
    
    echo -e "${GREEN}依赖检查完成${NC}"
    
    # 标记已检查
    DEPS_CHECKED=1
}

# 检查VM ID是否已存在
function check_vmid_exists() {
    local vmid=$1
    
    if qm status $vmid &>/dev/null; then
        return 0  # VM存在
    else
        return 1  # VM不存在
    fi
}

# 下载云镜像
function download_image() {
    local distro=$1
    local version=$2
    local download_dir="/root/qcow"
    local image_file
    local image_url
    local download_success=0
    
    # 创建下载目录
    mkdir -p $download_dir
    
    case "$distro" in
        "centos")
            if [ "$version" = "9-stream" ]; then
                image_url="https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"
                image_file="$download_dir/centos-9-stream-genericcloud-amd64.qcow2"
                
                # 验证URL是否可访问，如果不可访问则尝试备用URL
                if ! curl --output /dev/null --silent --head --fail "$image_url"; then
                    echo -e "${YELLOW}主URL不可用，尝试备用URL...${NC}"
                    image_url="https://mirror.stream.centos.org/9-stream/Cloud/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"
                fi
            elif [ "$version" = "8-stream" ]; then
                image_url="https://cloud.centos.org/centos/8-stream/x86_64/images/CentOS-Stream-GenericCloud-8-latest.x86_64.qcow2"
                image_file="$download_dir/centos-8-stream-genericcloud-amd64.qcow2"
                
                # 验证URL是否可访问，如果不可访问则尝试备用URL
                if ! curl --output /dev/null --silent --head --fail "$image_url"; then
                    echo -e "${YELLOW}主URL不可用，尝试备用URL...${NC}"
                    image_url="https://mirror.stream.centos.org/8-stream/Cloud/x86_64/images/CentOS-Stream-GenericCloud-8-latest.x86_64.qcow2"
                fi
            fi
            ;;
        "debian")
            if [ "$version" == "12" ]; then
                image_url="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"
                image_file="$download_dir/debian-12-genericcloud-amd64.qcow2"
            elif [ "$version" == "11" ]; then
                image_url="https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-genericcloud-amd64.qcow2"
                image_file="$download_dir/debian-11-genericcloud-amd64.qcow2"
            elif [ "$version" == "10" ]; then
                image_url="https://cloud.debian.org/images/cloud/buster/latest/debian-10-genericcloud-amd64.qcow2"
                image_file="$download_dir/debian-10-genericcloud-amd64.qcow2"
            fi
            ;;
        "ubuntu")
            if [ "$version" == "24.04" ]; then
                image_url="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
                image_file="$download_dir/ubuntu-24.04-server-cloudimg-amd64.img"
            elif [ "$version" == "22.04" ]; then
                image_url="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
                image_file="$download_dir/ubuntu-22.04-server-cloudimg-amd64.img"
            elif [ "$version" == "20.04" ]; then
                image_url="https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img"
                image_file="$download_dir/ubuntu-20.04-server-cloudimg-amd64.img"
            fi
            ;;
        *)
            echo -e "${RED}错误：不支持的发行版 $distro${NC}"
            return 1
            ;;
    esac
    
    # 如果镜像不存在，则下载
    if [ ! -f "$image_file" ]; then
        echo -e "${YELLOW}下载 $distro $version 云镜像...${NC}"
        wget -O "$image_file" "$image_url" || curl -L "$image_url" -o "$image_file"
        
        # 检查下载是否成功
        if [ ! -f "$image_file" ] || [ ! -s "$image_file" ]; then
            echo -e "${RED}下载失败，无法获取镜像文件${NC}"
            return 1
        fi
        download_success=1
    else
        echo -e "${GREEN}镜像已存在，跳过下载${NC}"
    fi
    
    # 检查文件是否为有效的镜像文件
    if ! file "$image_file" | grep -q -i "QEMU\|disk image"; then
        if [ "$download_success" -eq 1 ]; then
            echo -e "${RED}错误：下载的文件不是有效的QEMU镜像格式${NC}"
            # 删除可能损坏的文件
            rm -f "$image_file"
            return 1
        else
            echo -e "${RED}错误：现有文件不是有效的QEMU镜像格式，将重新下载${NC}"
            rm -f "$image_file"
            # 递归调用来重新下载
            download_image "$distro" "$version"
            return $?
        fi
    fi
    
    echo -e "${GREEN}镜像准备完成: $image_file${NC}"
    
    # 保存结果变量而不是echo
    RESULT_IMAGE_FILE="$image_file"
    return 0
}

# 定制镜像
function customize_image() {
    local distro=$1
    local version=$2
    local image_file=$3
    local customized_image
    local customize_result=0
    
    # 检查镜像文件是否存在
    if [ ! -f "$image_file" ]; then
        echo -e "${RED}错误：镜像文件 $image_file 不存在${NC}"
        return 1
    fi
    
    # 修复文件路径，确保不会重复添加后缀
    base_name=$(basename "$image_file" | sed 's/\.\(qcow2\|img\)$//')
    dir_name=$(dirname "$image_file")
    customized_image="${dir_name}/${base_name}-customized.qcow2"
    
    echo -e "${BLUE}开始定制镜像...${NC}"
    
    # 复制一份镜像用于定制
    echo -e "${YELLOW}复制镜像用于定制...${NC}"
    rm -f "$customized_image" # 确保目标文件不存在
    cp "$image_file" "$customized_image"
    
    # 检查复制是否成功
    if [ ! -f "$customized_image" ]; then
        echo -e "${RED}错误：无法复制镜像文件${NC}"
        return 1
    fi
    
    # 检查镜像文件大小
    original_size=$(stat -c %s "$image_file")
    copied_size=$(stat -c %s "$customized_image")
    
    if [ "$original_size" != "$copied_size" ]; then
        echo -e "${RED}错误：复制后的镜像文件大小不一致，可能复制不完整${NC}"
        rm -f "$customized_image" 
        return 1
    fi
    
    # 通用定制项
    echo -e "${YELLOW}安装常用工具...${NC}"
    
    # 根据不同发行版设置不同的定制命令
    case "$distro" in
        "centos")
            # CentOS发行版 - 添加EPEL仓库并安装软件
            echo -e "${YELLOW}为${distro}添加EPEL仓库...${NC}"
            
            virt-customize -a "$customized_image" \
                --update \
                --install 'qemu-guest-agent' \
                --selinux-relabel || customize_result=1
                
            # 尝试安装EPEL和其他工具，但不要因此失败
            virt-customize -a "$customized_image" \
                --run-command "dnf -y install epel-release || dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-\$(rpm -E %rhel).noarch.rpm || true" \
                --run-command "dnf -y update || true" \
                --run-command "dnf -y install git tree || true" \
                --run-command "dnf -y install htop neofetch || true" \
                --selinux-relabel || true
            
            # 配置SSH
            echo -e "${YELLOW}配置SSH允许root登录和密码认证...${NC}"
            virt-customize -a "$customized_image" \
                --run-command "sed -i 's/#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config" \
                --run-command "sed -i 's/#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config" \
                --run-command "grep -q '^PermitRootLogin yes' /etc/ssh/sshd_config || echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config" \
                --run-command "grep -q '^PasswordAuthentication yes' /etc/ssh/sshd_config || echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config" \
                --run-command "systemctl enable qemu-guest-agent" \
                --selinux-relabel || true

            # 禁用网络等待服务，避免启动挂起
            echo -e "${YELLOW}禁用网络等待服务...${NC}"
            virt-customize -a "$customized_image" \
                --run-command "systemctl disable NetworkManager-wait-online.service || true" \
                --run-command "systemctl disable systemd-networkd-wait-online.service || true" \
                --run-command "if [ -f /etc/cloud/cloud.cfg ]; then sed -i 's/^ - growpart/# - growpart/' /etc/cloud/cloud.cfg || true; fi" \
                --selinux-relabel || true
                
            # 修复CentOS 9 cloud-init问题
            if [ "$version" = "9-stream" ]; then
                echo -e "${YELLOW}应用CentOS 9 cloud-init修复...${NC}"
                virt-customize -a "$customized_image" \
                    --run-command "echo 'datasource_list: [ NoCloud, ConfigDrive, None ]' > /etc/cloud/cloud.cfg.d/99-pve.cfg" \
                    --run-command "sed -i 's/name: centos/name: cloud-user/' /etc/cloud/cloud.cfg || true" \
                    --run-command "dnf reinstall -y cloud-init || true" \
                    --run-command "systemctl enable cloud-init" \
                    --selinux-relabel || true
            fi
                
            # 设置时区
            echo -e "${YELLOW}设置时区为Asia/Shanghai...${NC}"
            virt-customize -a "$customized_image" \
                --run-command "timedatectl set-timezone Asia/Shanghai || true" \
                --selinux-relabel || true
                
            # 清理
            echo -e "${YELLOW}清理系统...${NC}"
            virt-customize -a "$customized_image" \
                --run-command "dnf clean all || yum clean all || true" \
                --run-command "truncate -s 0 /etc/machine-id /var/lib/dbus/machine-id || true" \
                --selinux-relabel || true
            ;;
            
        "debian"|"ubuntu")
            # Debian系发行版
            virt-customize -a "$customized_image" \
                --run-command "apt update" \
                --run-command "apt install -y qemu-guest-agent" || customize_result=1
                
            # 尝试安装其他工具，但不中断流程
            virt-customize -a "$customized_image" \
                --run-command "apt install -y acpid || true" \
                --run-command "apt install -y htop git tree || true" \
                --run-command "apt install -y neofetch || true" || true
    
            # 配置SSH允许root登录和密码登录
            echo -e "${YELLOW}配置SSH允许root登录和密码认证...${NC}"
            virt-customize -a "$customized_image" \
                --run-command "sed -i 's/#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config" \
                --run-command "sed -i 's/#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config" \
                --run-command "grep -q '^PermitRootLogin yes' /etc/ssh/sshd_config || echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config" \
                --run-command "grep -q '^PasswordAuthentication yes' /etc/ssh/sshd_config || echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config" || true
            
            # 禁用网络等待服务，避免启动挂起
            echo -e "${YELLOW}配置网络等待服务...${NC}"
            virt-customize -a "$customized_image" \
                --run-command "systemctl disable systemd-networkd-wait-online.service || true" \
                --run-command "systemctl disable NetworkManager-wait-online.service || true" \
                --run-command "if [ -f /etc/netplan/01-netcfg.yaml ]; then mkdir -p /etc/cloud/cloud.cfg.d/ && echo 'network: {config: disabled}' > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg || true; fi" \
                --run-command "if [ -f /etc/cloud/cloud.cfg ]; then sed -i 's/^ - growpart/# - growpart/' /etc/cloud/cloud.cfg || true; fi" \
                --run-command "mkdir -p /etc/systemd/system/systemd-networkd-wait-online.service.d/ && echo '[Service]\nTimeoutStartSec=2sec' > /etc/systemd/system/systemd-networkd-wait-online.service.d/override.conf || true" || true
            
            # 设置时区
            echo -e "${YELLOW}设置时区为Asia/Shanghai...${NC}"
            virt-customize -a "$customized_image" \
                --run-command "timedatectl set-timezone Asia/Shanghai || true" || true
                
            # 清理
            echo -e "${YELLOW}清理系统...${NC}"
            virt-customize -a "$customized_image" \
                --run-command "apt clean || true" \
                --run-command "apt autoclean || true" \
                --run-command "apt autoremove -y || true" \
                --run-command "truncate -s 0 /etc/machine-id /var/lib/dbus/machine-id || true" || true
            ;;
            
        *)
            echo -e "${RED}错误：不支持的发行版 $distro${NC}"
            return 1
            ;;
    esac
    
    # 检查virt-customize是否成功
    if [ "$customize_result" -ne 0 ]; then
        echo -e "${YELLOW}警告：部分核心定制失败，但我们会尝试继续...${NC}"
    fi
    
    # 检查创建的镜像是否有效
    if [ ! -f "$customized_image" ] || [ ! -s "$customized_image" ]; then
        echo -e "${RED}错误：定制后的镜像无效或为空${NC}"
        return 1
    fi
    
    echo -e "${GREEN}镜像定制完成: $customized_image${NC}"
    
    # 保存结果变量而不是echo
    RESULT_CUSTOMIZED_IMAGE="$customized_image"
    return 0
}

# 创建PVE模板
function create_template() {
    local distro=$1
    local version=$2
    local image_file=$3
    local vmid=$4
    local storage=$5
    
    # 检查镜像文件是否存在
    if [ ! -f "$image_file" ]; then
        echo -e "${RED}错误：镜像文件 $image_file 不存在${NC}"
        return 1
    fi
    
    echo -e "${BLUE}创建PVE模板...${NC}"
    
    # 检查虚拟机ID是否已存在
    if check_vmid_exists $vmid; then
        echo -e "${YELLOW}注意：ID为 $vmid 的虚拟机已存在${NC}"
        read -p "是否删除现有虚拟机并继续? (y/n): " delete_vm
        if [ "$delete_vm" == "y" ] || [ "$delete_vm" == "Y" ]; then
            echo -e "${YELLOW}删除现有虚拟机...${NC}"
            qm stop $vmid &>/dev/null
            sleep 2
            qm destroy $vmid
        else
            echo -e "${YELLOW}操作取消${NC}"
            return 1
        fi
    fi
    
    # 创建虚拟机
    echo -e "${YELLOW}创建虚拟机 (ID: $vmid)...${NC}"
    qm create $vmid --name "$distro-$version-cloudinit-template" --onboot 1 --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
    
    # 导入磁盘
    echo -e "${YELLOW}导入磁盘...${NC}"
    qm importdisk $vmid "$image_file" $storage
    
    # 延迟以确保Proxmox完成导入
    sleep 5
    
    # 检查导入结果
    if ! qm config $vmid | grep -q "unused"; then
        echo -e "${RED}错误：磁盘导入失败${NC}"
        return 1
    fi
    
    # 配置虚拟机 - 按照原教程的磁盘路径格式
    echo -e "${YELLOW}配置虚拟机...${NC}"
    
    # 首先查看导入后的实际磁盘路径
    disk_path=$(qm config $vmid | grep unused | head -1 | awk '{print $2}')
    if [ -z "$disk_path" ]; then
        echo -e "${RED}错误：找不到导入的磁盘路径${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}导入的磁盘路径: $disk_path${NC}"
    
    # 使用正确的磁盘路径
    qm set $vmid --scsihw virtio-scsi-pci --scsi0 $disk_path
    qm set $vmid --boot c --bootdisk scsi0
    qm set $vmid --ide2 $storage:cloudinit
    qm set $vmid --serial0 socket --vga serial0
    qm set $vmid --agent enabled=1
    qm set $vmid --cpu host
    
    # 调整磁盘大小（可选）
    echo -e "${YELLOW}调整磁盘大小为32G...${NC}"
    qm resize $vmid scsi0 32G
    
    # 显示配置信息
    echo -e "${GREEN}虚拟机配置详情:${NC}"
    qm config $vmid | grep -v "^$"
    
    # 确认是否转为模板
    echo -e "${YELLOW}虚拟机设置完成。是否将其转换为模板?${NC}"
    read -p "转换为模板? (y/n): " confirm_template
    
    if [ "$confirm_template" == "y" ] || [ "$confirm_template" == "Y" ]; then
        echo -e "${YELLOW}转换为模板...${NC}"
        qm template $vmid
        echo -e "${GREEN}模板创建完成 (ID: $vmid)${NC}"
    else
        echo -e "${GREEN}虚拟机创建完成，未转换为模板 (ID: $vmid)${NC}"
    fi
    
    echo ""
    return 0
}

# 主菜单
function main_menu() {
    # 清理可能存在的变量
    unset RESULT_IMAGE_FILE RESULT_CUSTOMIZED_IMAGE SELECTED_STORAGE SELECTED_VMID
    
    # 显示logo
    show_logo
    
    # 检查系统兼容性
    check_system
    
    # 检查依赖
    check_dependencies
    
    echo "请选择要执行的操作:"
    echo "1) CentOS 9-stream"
    echo "2) CentOS 8-stream"
    echo "3) Debian 12"
    echo "4) Debian 11"
    echo "5) Debian 10"
    echo "6) Ubuntu 24.04"
    echo "7) Ubuntu 22.04"
    echo "8) Ubuntu 20.04"
    echo "9) 一次性安装所有镜像"
    echo "0) 退出"
    
    read -p "请输入选项 [0-9]: " choice
    
    # 获取可用存储和虚拟机ID
    function get_storage_and_vmid() {
        local default_vmid=$1
        
        # 获取可用存储
        echo ""
        available_storages=$(pvesm status -content images | grep -v "Name" | awk '{print $1}' | sort -u)
        
        # 如果没有找到存储，则显示所有存储
        if [ -z "$available_storages" ]; then
            available_storages=$(pvesm status | grep -v "Name" | awk '{print $1}' | sort -u)
        fi
        
        # 检查是否有可用存储
        if [ -z "$available_storages" ]; then
            echo -e "${RED}错误：未找到可用存储，请确认Proxmox配置${NC}"
            read -p "按任意键返回主菜单..." 
            main_menu
            return 1
        fi
        
        # 显示可用存储
        echo -e "${YELLOW}可用存储:${NC}"
        echo "$available_storages" | nl
        read -p "请选择存储 [默认:第一个存储]: " storage_choice
        
        if [ -z "$storage_choice" ]; then
            SELECTED_STORAGE=$(echo "$available_storages" | head -n1)
        else
            SELECTED_STORAGE=$(echo "$available_storages" | sed -n "${storage_choice}p")
            if [ -z "$SELECTED_STORAGE" ]; then
                echo -e "${RED}错误：选择的存储不存在${NC}"
                read -p "按任意键返回..." 
                get_storage_and_vmid "$default_vmid"
                return $?
            fi
        fi
        
        # 虚拟机ID
        read -p "请输入模板虚拟机ID [默认:$default_vmid]: " vmid
        SELECTED_VMID=${vmid:-$default_vmid}
        
        # 验证VMID是数字
        if ! [[ "$SELECTED_VMID" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}错误：VMID必须是数字${NC}"
            read -p "按任意键返回..." 
            get_storage_and_vmid "$default_vmid"
            return $?
        fi
        
        return 0
    }
    
    # 处理镜像创建流程
    function handle_image_creation() {
        local distro=$1
        local version=$2
        local vmid=$3
        
        show_logo
        echo -e "${YELLOW}创建$distro $version模板${NC}"
        
        get_storage_and_vmid $vmid
        if [ $? -ne 0 ]; then
            return 1
        fi
        
        # 下载镜像
        download_image "$distro" "$version"
        if [ $? -ne 0 ]; then
            echo -e "${RED}下载镜像失败，请检查网络和存储空间${NC}"
            read -p "按任意键继续..."
            main_menu
            return 1
        fi
        
        image_file="$RESULT_IMAGE_FILE"
        echo -e "${YELLOW}下载的镜像文件路径: $image_file${NC}"
        
        # 定制镜像
        customize_image "$distro" "$version" "$image_file"
        if [ $? -ne 0 ]; then
            echo -e "${RED}定制镜像失败${NC}"
            read -p "按任意键继续..."
            main_menu
            return 1
        fi
        
        customized_image="$RESULT_CUSTOMIZED_IMAGE"
        if [ -z "$customized_image" ] || [ ! -f "$customized_image" ]; then
            echo -e "${RED}定制镜像未生成或路径无效${NC}"
            read -p "按任意键继续..."
            main_menu
            return 1
        fi
        
        echo -e "${YELLOW}定制后的镜像文件路径: $customized_image${NC}"
        
        # 创建模板
        create_template "$distro" "$version" "$customized_image" "$SELECTED_VMID" "$SELECTED_STORAGE"
        if [ $? -ne 0 ]; then
            echo -e "${RED}创建模板失败${NC}"
            read -p "按任意键继续..."
            main_menu
            return 1
        fi
        
        echo -e "${GREEN}所有操作已完成!${NC}"
        echo -e "${YELLOW}提示:${NC} 现在您可以从模板克隆新的虚拟机，并通过Cloud-Init配置进行自定义设置。"
        read -p "按任意键继续..."
        main_menu
        return 0
    }
    
    case $choice in
        1) handle_image_creation "centos" "9-stream" "9000" ;;
        2) handle_image_creation "centos" "8-stream" "9001" ;;
        3) handle_image_creation "debian" "12" "9006" ;;
        4) handle_image_creation "debian" "11" "9007" ;;
        5) handle_image_creation "debian" "10" "9008" ;;
        6) handle_image_creation "ubuntu" "24.04" "9014" ;;
        7) handle_image_creation "ubuntu" "22.04" "9015" ;;
        8) handle_image_creation "ubuntu" "20.04" "9016" ;;
        9) 
            show_logo
            echo -e "${YELLOW}一次性安装所有镜像${NC}"
            echo -e "${YELLOW}此操作将依次安装所有支持的操作系统镜像，请确保有足够的存储空间${NC}"
            read -p "确定要继续吗? (y/n): " confirm_all
            if [ "$confirm_all" == "y" ] || [ "$confirm_all" == "Y" ]; then
                # 获取存储位置
                get_storage_and_vmid 9000
                if [ $? -eq 0 ]; then
                    storage=$SELECTED_STORAGE
                    
                    # 依次创建各个镜像
                    handle_image_creation "centos" "9-stream" "9000"
                    handle_image_creation "centos" "8-stream" "9001"
                    handle_image_creation "debian" "12" "9006"
                    handle_image_creation "debian" "11" "9007"
                    handle_image_creation "debian" "10" "9008"
                    handle_image_creation "ubuntu" "24.04" "9014"
                    handle_image_creation "ubuntu" "22.04" "9015"
                    handle_image_creation "ubuntu" "20.04" "9016"
                    
                    echo -e "${GREEN}所有镜像安装完成!${NC}"
                fi
            else
                echo -e "${YELLOW}已取消操作${NC}"
            fi
            read -p "按任意键继续..."
            main_menu
            ;;
        0)
            echo -e "${GREEN}感谢使用，再见!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选项，请重试${NC}"
            read -p "按任意键继续..."
            main_menu
            ;;
    esac
}

# 启动主程序
main_menu 
