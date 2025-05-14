#!/bin/bash

# Proxmox VE Cloud-Init模板创建脚本
# 作者: tiancaizhi9098
# 仓库: https://github.com/Tiancaizhi9098/Proxmox-VE-OS-Template

# 设置颜色变量
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # 恢复默认颜色

# 检查是否为root用户
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}错误: 请使用root权限运行此脚本!${NC}"
    exit 1
fi

# 检查是否在Proxmox VE环境中
if ! command -v pveversion &> /dev/null; then
    echo -e "${RED}错误: 此脚本必须在Proxmox VE环境中运行!${NC}"
    exit 1
fi

# 清屏
clear

# 显示脚本信息
echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}      Proxmox VE Cloud-Init 模板创建工具          ${NC}"
echo -e "${BLUE}      作者: tiancaizhi9098                        ${NC}"
echo -e "${BLUE}      仓库: github.com/Tiancaizhi9098/Proxmox-VE-OS-Template${NC}"
echo -e "${BLUE}====================================================${NC}"
echo

# 全局变量
VM_ID=""
STORAGE=""
NETWORK_BRIDGE=""
OS_VERSION=""
DISK_SIZE="8G"
MEMORY="1024"
CORES="1"
IMAGE_FILE=""
IMAGE_URL=""

# 获取可用的存储和网络接口
function get_available_storages() {
    pvesm status | grep -E 'active' | awk '{print $1}'
}

function get_available_bridges() {
    ip link show | grep -E '^[0-9]+: (vmbr[0-9]+|eth[0-9]+|ens[0-9]+)' | awk -F ': ' '{print $2}' | cut -d '@' -f 1
}

function print_status() {
    echo -e "${YELLOW}[+] $1${NC}"
}

function print_success() {
    echo -e "${GREEN}[*] $1${NC}"
}

function print_error() {
    echo -e "${RED}[!] $1${NC}"
}

# 检查VM ID是否存在
function check_vm_exists() {
    qm status "$1" &>/dev/null
    return $?
}

# 确认操作
function confirm_action() {
    read -p "$1 (y/n): " choice
    case "$choice" in
        y|Y ) return 0 ;;
        * ) return 1 ;;
    esac
}

# 选择操作系统版本
function select_os_version() {
    echo
    echo -e "${YELLOW}请选择操作系统版本:${NC}"
    echo "1) Debian 12 (Bookworm)"
    echo "2) Debian 11 (Bullseye)"
    echo "0) 退出"
    
    read -p "请输入选项 [0-2]: " os_choice
    
    case $os_choice in
        1)
            OS_VERSION="debian12"
            IMAGE_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"
            ;;
        2)
            OS_VERSION="debian11"
            IMAGE_URL="https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-genericcloud-amd64.qcow2"
            ;;
        0)
            echo "退出脚本..."
            exit 0
            ;;
        *)
            print_error "无效选项，请重新选择"
            select_os_version
            ;;
    esac
    
    # 设置镜像文件名
    IMAGE_FILE="${OS_VERSION}-genericcloud-amd64.qcow2"
}

# 输入VM ID
function input_vm_id() {
    echo
    read -p "请输入VMID [1000-9999]: " VM_ID
    
    # 检查输入格式
    if ! [[ "$VM_ID" =~ ^[0-9]+$ ]] || [ "$VM_ID" -lt 1000 ] || [ "$VM_ID" -gt 9999 ]; then
        print_error "无效的VM ID，请输入1000-9999之间的数字"
        input_vm_id
        return
    fi
    
    # 检查VM ID是否已存在
    if check_vm_exists "$VM_ID"; then
        print_error "VMID $VM_ID 已存在!"
        if confirm_action "是否删除现有VM并继续"; then
            print_status "正在删除VM $VM_ID..."
            qm destroy "$VM_ID" --purge
        else
            input_vm_id
            return
        fi
    fi
}

# 选择存储
function select_storage() {
    echo
    echo -e "${YELLOW}可用存储:${NC}"
    local storages=($(get_available_storages))
    
    if [ ${#storages[@]} -eq 0 ]; then
        print_error "未找到可用的存储!"
        exit 1
    fi
    
    local i=1
    for storage in "${storages[@]}"; do
        echo "$i) $storage"
        ((i++))
    done
    
    read -p "请选择存储 [1-${#storages[@]}]: " storage_choice
    
    if ! [[ "$storage_choice" =~ ^[0-9]+$ ]] || [ "$storage_choice" -lt 1 ] || [ "$storage_choice" -gt ${#storages[@]} ]; then
        print_error "无效选项，请重新选择"
        select_storage
        return
    fi
    
    STORAGE=${storages[$storage_choice-1]}
}

# 选择网络接口
function select_network_bridge() {
    echo
    echo -e "${YELLOW}可用网络接口:${NC}"
    local bridges=($(get_available_bridges))
    
    if [ ${#bridges[@]} -eq 0 ]; then
        print_error "未找到可用的网络接口!"
        exit 1
    fi
    
    local i=1
    for bridge in "${bridges[@]}"; do
        echo "$i) $bridge"
        ((i++))
    done
    
    read -p "请选择网络接口 [1-${#bridges[@]}]: " bridge_choice
    
    if ! [[ "$bridge_choice" =~ ^[0-9]+$ ]] || [ "$bridge_choice" -lt 1 ] || [ "$bridge_choice" -gt ${#bridges[@]} ]; then
        print_error "无效选项，请重新选择"
        select_network_bridge
        return
    fi
    
    NETWORK_BRIDGE=${bridges[$bridge_choice-1]}
}

# 下载云镜像
function download_cloud_image() {
    print_status "正在下载 $OS_VERSION 云镜像..."
    
    # 创建临时目录
    local temp_dir="/tmp/pve-cloud-init"
    mkdir -p "$temp_dir"
    
    # 下载镜像
    if ! wget -O "$temp_dir/$IMAGE_FILE" "$IMAGE_URL"; then
        print_error "下载镜像失败!"
        exit 1
    fi
    
    print_success "镜像下载完成!"
    echo
}

# 创建VM
function create_vm() {
    print_status "正在创建VM $VM_ID..."
    
    # 创建VM
    qm create "$VM_ID" \
        --name "template-$OS_VERSION" \
        --memory "$MEMORY" \
        --cores "$CORES" \
        --net0 "virtio,bridge=$NETWORK_BRIDGE" \
        --bios ovmf \
        --ostype l26 \
        --agent enabled=1 \
        --scsihw virtio-scsi-pci \
        --boot c \
        --bootdisk scsi0
    
    # 导入磁盘
    print_status "正在导入磁盘..."
    qm importdisk "$VM_ID" "/tmp/pve-cloud-init/$IMAGE_FILE" "$STORAGE"
    
    # 配置磁盘
    qm set "$VM_ID" --scsi0 "$STORAGE:vm-$VM_ID-disk-0"
    qm set "$VM_ID" --ide2 "$STORAGE:cloudinit"
    
    # 设置Cloud-Init配置
    qm set "$VM_ID" --ipconfig0 "ip=dhcp"
    qm set "$VM_ID" --ciuser "root"
    qm set "$VM_ID" --cipassword "proxmox"
    qm set "$VM_ID" --sshkeys "~/.ssh/authorized_keys"
    
    # 调整磁盘大小
    print_status "正在调整磁盘大小为 $DISK_SIZE..."
    qm resize "$VM_ID" scsi0 "$DISK_SIZE"
    
    # 配置串行控制台
    qm set "$VM_ID" --serial0 socket --vga serial0
    
    print_success "VM创建完成!"
    echo
}

# 设置为模板
function convert_to_template() {
    echo
    if confirm_action "是否将VM转换为模板"; then
        print_status "正在将VM转换为模板..."
        qm template "$VM_ID"
        print_success "VM已成功转换为模板!"
    else
        print_status "VM保留为普通虚拟机"
    fi
}

# 清理
function cleanup() {
    print_status "正在清理临时文件..."
    rm -rf "/tmp/pve-cloud-init"
    print_success "清理完成!"
}

# 显示摘要
function display_summary() {
    echo
    echo -e "${BLUE}====================================================${NC}"
    echo -e "${BLUE}                    摘要信息                      ${NC}"
    echo -e "${BLUE}====================================================${NC}"
    echo -e "操作系统版本: ${GREEN}$OS_VERSION${NC}"
    echo -e "VM ID: ${GREEN}$VM_ID${NC}"
    echo -e "存储: ${GREEN}$STORAGE${NC}"
    echo -e "网络接口: ${GREEN}$NETWORK_BRIDGE${NC}"
    echo -e "磁盘大小: ${GREEN}$DISK_SIZE${NC}"
    echo -e "内存: ${GREEN}$MEMORY MB${NC}"
    echo -e "CPU核心数: ${GREEN}$CORES${NC}"
    echo -e "${BLUE}====================================================${NC}"
    echo
    
    if confirm_action "确认创建该模板"; then
        return 0
    else
        return 1
    fi
}

# 主函数
function main() {
    # 选择操作系统版本
    select_os_version
    
    # 输入VM ID
    input_vm_id
    
    # 选择存储
    select_storage
    
    # 选择网络接口
    select_network_bridge
    
    # 显示摘要
    if ! display_summary; then
        print_status "操作已取消"
        exit 0
    fi
    
    # 下载镜像
    download_cloud_image
    
    # 创建VM
    create_vm
    
    # 转换为模板
    convert_to_template
    
    # 清理
    cleanup
    
    echo
    print_success "操作完成! 模板已准备就绪."
    echo -e "您可以使用以下命令从模板创建新的VM:"
    echo -e "${GREEN}qm clone $VM_ID <new_vmid> --name <vm_name>${NC}"
    echo
}

# 开始执行
main 
