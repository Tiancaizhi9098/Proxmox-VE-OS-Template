#!/bin/bash

# Proxmox Cloud-Init 模板虚拟机创建脚本
# 作者: Tiancaizhi9098
# GitHub: https://github.com/Tiancaizhi9098/Proxmox-VE-OS-Template

# 设置颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # 无颜色

# 显示横幅
display_banner() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                            ║${NC}"
    echo -e "${CYAN}║   ${GREEN}Proxmox VE Cloud-Init 模板虚拟机创建工具${CYAN}                 ║${NC}"
    echo -e "${CYAN}║   ${YELLOW}作者: Tiancaizhi9098${CYAN}                                   ║${NC}"
    echo -e "${CYAN}║   ${BLUE}GitHub: github.com/Tiancaizhi9098/Proxmox-VE-OS-Template${CYAN} ║${NC}"
    echo -e "${CYAN}║                                                            ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# 显示错误信息并退出
error_exit() {
    echo -e "${RED}错误: $1${NC}" 1>&2
    exit 1
}

# 显示成功信息
success_msg() {
    echo -e "${GREEN}成功: $1${NC}"
}

# 显示信息
info_msg() {
    echo -e "${BLUE}信息: $1${NC}"
}

# 显示警告信息
warning_msg() {
    echo -e "${YELLOW}警告: $1${NC}"
}

# 检查必要的命令是否可用
check_requirements() {
    commands=("wget" "qm" "pvesm" "pvesh")
    
    for cmd in "${commands[@]}"; do
        if ! command -v $cmd &> /dev/null; then
            error_exit "$cmd 命令不可用，请确保您在 Proxmox VE 环境中运行此脚本"
        fi
    done
    
    info_msg "所有必要的命令均可用"
}

# 选择操作系统
select_os() {
    display_banner
    echo -e "${CYAN}请选择要创建的模板操作系统:${NC}"
    echo -e "  ${GREEN}1) Debian 12 (Bookworm)${NC}"
    echo -e "  ${GREEN}2) Debian 11 (Bullseye)${NC}"
    echo -e "  ${YELLOW}3) 退出${NC}"
    echo ""
    
    read -p "请输入选项 [1-3]: " os_choice
    
    case $os_choice in
        1)
            OS_NAME="Debian 12"
            OS_CODE="bookworm"
            OS_VERSION="12"
            IMAGE_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"
            ;;
        2)
            OS_NAME="Debian 11"
            OS_CODE="bullseye"
            OS_VERSION="11"
            IMAGE_URL="https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-genericcloud-amd64.qcow2"
            ;;
        3)
            info_msg "脚本已取消执行"
            exit 0
            ;;
        *)
            error_exit "无效的选项: $os_choice"
            ;;
    esac
    
    IMAGE_FILENAME=$(basename $IMAGE_URL)
    success_msg "已选择 $OS_NAME ($OS_CODE)"
}

# 检查是否为 root 用户
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error_exit "请使用 root 权限运行此脚本"
    fi
}

# 输入 VMID
input_vmid() {
    display_banner
    echo -e "${CYAN}虚拟机 ID 设置${NC}"
    echo ""
    
    # 获取所有已存在的 VMID 列表
    EXISTING_VMIDS=$(qm list | tail -n +2 | awk '{print $1}')
    
    while true; do
        read -p "请输入虚拟机 ID [推荐 8000+]: " VMID
        
        # 检查输入是否为数字
        if ! [[ "$VMID" =~ ^[0-9]+$ ]]; then
            warning_msg "请输入有效的数字 ID"
            continue
        fi
        
        # 检查 ID 是否已存在
        if echo "$EXISTING_VMIDS" | grep -q "^$VMID$"; then
            warning_msg "VMID $VMID 已存在"
            read -p "是否要删除现有虚拟机并继续? [y/n]: " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                info_msg "正在删除 VMID $VMID..."
                qm stop $VMID &>/dev/null || true
                qm destroy $VMID || error_exit "无法删除 VMID $VMID"
                success_msg "已删除 VMID $VMID"
                break
            else
                info_msg "请选择其他 VMID"
                continue
            fi
        else
            success_msg "已选择 VMID: $VMID"
            break
        fi
    done
}

# 选择存储位置
select_storage() {
    display_banner
    echo -e "${CYAN}存储选择${NC}"
    echo ""
    
    # 获取可用的存储列表
    STORAGES=$(pvesm status | tail -n +2 | awk '{print $1}')
    
    if [ -z "$STORAGES" ]; then
        warning_msg "无法自动获取存储列表，将使用手动输入"
        read -p "请手动输入存储名称(例如: local-lvm): " STORAGE
        
        if [ -z "$STORAGE" ]; then
            error_exit "未提供存储名称"
        fi
        
        success_msg "已手动选择存储: $STORAGE"
        return
    fi
    
    echo "可用的存储位置:"
    count=1
    declare -a STORAGE_ARRAY
    
    while read -r storage; do
        echo -e "  ${GREEN}$count)${NC} $storage"
        STORAGE_ARRAY[$count]=$storage
        ((count++))
    done <<< "$STORAGES"
    
    echo ""
    read -p "请选择存储位置 [1-$((count-1))]: " storage_choice
    
    if ! [[ "$storage_choice" =~ ^[0-9]+$ ]] || [ "$storage_choice" -lt 1 ] || [ "$storage_choice" -ge "$count" ]; then
        warning_msg "无效的选择，将使用默认存储"
        STORAGE=${STORAGE_ARRAY[1]}
    else
        STORAGE=${STORAGE_ARRAY[$storage_choice]}
    fi
    
    success_msg "已选择存储: $STORAGE"
}

# 选择网络接口
select_network() {
    display_banner
    echo -e "${CYAN}网络接口选择${NC}"
    echo ""
    
    # 获取可用的网桥
    BRIDGES=$(ip link show | grep -E ': (vmbr[0-9]+|eth[0-9]+|ens[0-9]+)@' | cut -d: -f2 | awk '{print $1}' | tr -d '@')
    
    if [ -z "$BRIDGES" ]; then
        warning_msg "未找到标准的网络接口，将使用手动输入"
        read -p "请手动输入网络接口名称(例如: vmbr0): " BRIDGE
        
        if [ -z "$BRIDGE" ]; then
            BRIDGE="vmbr0"
            warning_msg "使用默认网络接口: $BRIDGE"
        fi
    else
        echo "可用的网络接口:"
        count=1
        declare -a BRIDGE_ARRAY
        
        while read -r bridge; do
            echo -e "  ${GREEN}$count)${NC} $bridge"
            BRIDGE_ARRAY[$count]=$bridge
            ((count++))
        done <<< "$BRIDGES"
        
        echo ""
        read -p "请选择网络接口 [1-$((count-1))]: " bridge_choice
        
        if ! [[ "$bridge_choice" =~ ^[0-9]+$ ]] || [ "$bridge_choice" -lt 1 ] || [ "$bridge_choice" -ge "$count" ]; then
            warning_msg "无效的选择，将使用第一个网络接口"
            BRIDGE=${BRIDGE_ARRAY[1]}
        else
            BRIDGE=${BRIDGE_ARRAY[$bridge_choice]}
        fi
    fi
    
    success_msg "已选择网络接口: $BRIDGE"
}

# 自定义资源
customize_resources() {
    display_banner
    echo -e "${CYAN}虚拟机资源配置${NC}"
    echo ""
    
    # 默认资源
    MEMORY="2048"
    CORES="2"
    DISK_SIZE="8G"
    
    echo -e "默认资源配置:"
    echo -e "  ${YELLOW}内存:${NC} $MEMORY MB"
    echo -e "  ${YELLOW}CPU核心数:${NC} $CORES"
    echo -e "  ${YELLOW}磁盘大小:${NC} $DISK_SIZE"
    echo ""
    
    read -p "是否自定义资源配置? [y/n]: " customize
    
    if [[ "$customize" =~ ^[Yy]$ ]]; then
        # 内存
        read -p "请输入内存大小(MB) [$MEMORY]: " custom_memory
        if [[ -n "$custom_memory" && "$custom_memory" =~ ^[0-9]+$ ]]; then
            MEMORY=$custom_memory
        fi
        
        # CPU核心
        read -p "请输入CPU核心数 [$CORES]: " custom_cores
        if [[ -n "$custom_cores" && "$custom_cores" =~ ^[0-9]+$ && "$custom_cores" -gt 0 ]]; then
            CORES=$custom_cores
        fi
        
        # 磁盘大小
        read -p "请输入磁盘大小(例如:8G, 16G, 32G) [$DISK_SIZE]: " custom_disk
        if [[ -n "$custom_disk" ]]; then
            DISK_SIZE=$custom_disk
        fi
        
        success_msg "已自定义资源配置"
    else
        info_msg "使用默认资源配置"
    fi
    
    echo -e "最终资源配置:"
    echo -e "  ${GREEN}内存:${NC} $MEMORY MB"
    echo -e "  ${GREEN}CPU核心数:${NC} $CORES"
    echo -e "  ${GREEN}磁盘大小:${NC} $DISK_SIZE"
}

# 下载映像文件
download_image() {
    display_banner
    echo -e "${CYAN}下载 $OS_NAME Cloud 镜像${NC}"
    echo ""
    
    # 创建临时目录
    TEMP_DIR=$(mktemp -d)
    if [ ! -d "$TEMP_DIR" ]; then
        error_exit "无法创建临时目录"
    fi
    
    cd "$TEMP_DIR" || error_exit "无法切换到临时目录"
    
    info_msg "正在下载 $OS_NAME 云镜像..."
    info_msg "下载地址: $IMAGE_URL"
    
    wget -q --show-progress "$IMAGE_URL" -O "$IMAGE_FILENAME" || error_exit "下载失败"
    
    success_msg "镜像下载完成: $IMAGE_FILENAME"
}

# 创建虚拟机
create_vm() {
    display_banner
    echo -e "${CYAN}创建 $OS_NAME 虚拟机${NC}"
    echo ""
    
    info_msg "正在创建虚拟机 (VMID: $VMID)..."
    
    # 创建虚拟机
    qm create $VMID \
      --name "template-$OS_CODE-$OS_VERSION" \
      --memory "$MEMORY" \
      --cores "$CORES" \
      --net0 virtio,bridge="$BRIDGE" \
      --bios ovmf \
      --description "Cloud-Init $OS_NAME 模板虚拟机，GitHub: Tiancaizhi9098/Proxmox-VE-OS-Template" \
      --ostype l26 \
      --agent enabled=1 \
      || error_exit "创建虚拟机失败"
    
    # 导入磁盘
    info_msg "正在导入磁盘镜像..."
    qm importdisk $VMID "$TEMP_DIR/$IMAGE_FILENAME" "$STORAGE" || error_exit "导入磁盘失败"
    
    # 配置磁盘
    qm set $VMID --scsihw virtio-scsi-pci --scsi0 "$STORAGE:vm-$VMID-disk-0" || error_exit "配置磁盘失败"
    
    # 添加 Cloud-Init 驱动器
    qm set $VMID --ide2 "$STORAGE:cloudinit" || error_exit "添加 Cloud-Init 驱动器失败"
    
    # 设置引导顺序
    qm set $VMID --boot c --bootdisk scsi0 || error_exit "设置引导顺序失败"
    
    # 配置串口
    qm set $VMID --serial0 socket --vga serial0 || error_exit "配置串口失败"
    
    # 配置 Cloud-Init
    qm set $VMID --ciuser root || error_exit "设置 Cloud-Init 用户失败"
    qm set $VMID --cipassword "ChangeMe2024!" || error_exit "设置 Cloud-Init 密码失败"
    
    # 调整磁盘大小
    if [[ "$DISK_SIZE" != "8G" ]]; then
        info_msg "调整磁盘大小为 $DISK_SIZE..."
        qm resize $VMID scsi0 "$DISK_SIZE" || warning_msg "调整磁盘大小失败"
    fi
    
    # 启用 SSH 密码认证
    cat > "$TEMP_DIR/99-pve.cfg" << EOF
#cloud-config
ssh_pwauth: true
EOF
    
    qm set $VMID --cicustom "user=local:snippets/99-pve.cfg" || {
        info_msg "尝试创建自定义配置目录..."
        mkdir -p /var/lib/vz/snippets/
        cp "$TEMP_DIR/99-pve.cfg" /var/lib/vz/snippets/
        qm set $VMID --cicustom "user=local:snippets/99-pve.cfg" || warning_msg "设置 SSH 密码验证失败，请手动配置"
    }
    
    success_msg "虚拟机创建成功 (VMID: $VMID)"
}

# 转换为模板
convert_to_template() {
    display_banner
    echo -e "${CYAN}转换为模板${NC}"
    echo ""
    
    read -p "是否要将虚拟机转换为模板? [y/n]: " convert_choice
    
    if [[ "$convert_choice" =~ ^[Yy]$ ]]; then
        info_msg "正在将虚拟机转换为模板..."
        qm template $VMID || error_exit "转换为模板失败"
        success_msg "虚拟机已成功转换为模板"
    else
        info_msg "虚拟机未转换为模板，您可以稍后使用以下命令转换："
        echo -e "${CYAN}qm template $VMID${NC}"
    fi
}

# 清理临时文件
cleanup() {
    info_msg "清理临时文件..."
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
    success_msg "清理完成"
}

# 显示结果
show_result() {
    display_banner
    echo -e "${GREEN}====================================${NC}"
    echo -e "${GREEN}  $OS_NAME 模板创建完成!${NC}"
    echo -e "${GREEN}  VMID: $VMID${NC}"
    echo -e "${GREEN}  存储: $STORAGE${NC}"
    echo -e "${GREEN}  网络: $BRIDGE${NC}"
    echo -e "${GREEN}====================================${NC}"
    echo ""
    echo -e "${YELLOW}默认登录信息:${NC}"
    echo -e "  ${YELLOW}用户名: root${NC}"
    echo -e "  ${YELLOW}密码: ChangeMe2024!${NC}"
    echo ""
    echo -e "${CYAN}使用以下命令从模板创建新的虚拟机:${NC}"
    echo -e "  ${CYAN}qm clone $VMID <new_vmid> --name <vm_name>${NC}"
    echo ""
    echo -e "${PURPLE}谢谢使用，享受您的 Proxmox 之旅！${NC}"
}

# 主函数
main() {
    check_root
    check_requirements
    select_os
    input_vmid
    select_storage
    select_network
    customize_resources
    download_image
    create_vm
    convert_to_template
    cleanup
    show_result
}

# 执行主函数
main "$@" 
