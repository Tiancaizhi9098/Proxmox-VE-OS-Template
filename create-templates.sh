#!/bin/bash
set -e  # 添加此选项以确保任何错误导致脚本退出

# 函数：显示网卡选择菜单并获取网卡名称
prompt_for_network() {
    echo "====================================="
    echo "请选择网络接口："
    echo "====================================="
    local interfaces=()
    local index=1
    while IFS=': ' read -r num iface rest; do
        if [[ "$num" =~ ^[0-9]+$ && -n "$iface" && "$iface" != "lo" ]]; then
            interfaces[$index]=$iface
            echo "$index. $iface"
            ((index++))
        fi
    done < <(ip link | grep '^[0-9]')
    if [ ${#interfaces[@]} -eq 0 ]; then
        echo "错误：未找到可用的网络接口。"
        exit 1
    fi
    echo -n "请输入选项 (1-${#interfaces[@]})："
    read -r choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#interfaces[@]} ]; then
        echo "无效选项。"
        exit 1
    fi
    vmbr=${interfaces[$choice]}
    echo "已选择网络接口：$vmbr"
}

# 函数：显示存储选择菜单并获取存储名称
prompt_for_storage() {
    echo "====================================="
    echo "请选择存储目标："
    echo "====================================="
    local storages=() paths=() types=()
    local index=1
    while IFS=' ' read -r name type status total used avail; do
        if [[ "$status" == "active" && "$name" != "Name" ]]; then
            path=$(pvesm path "$name" 2>/dev/null || echo "未知路径")
            storages[$index]=$name
            paths[$index]=$path
            types[$index]=$type
            echo "$index. $name (类型: $type, 路径: $path)"
            ((index++))
        fi
    done < <(pvesm status)
    if [ ${#storages[@]} -eq 0 ]; then
        echo "错误：未找到可用的存储。"
        exit 1
    fi
    echo -n "请输入选项 (1-${#storages[@]})："
    read -r choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#storages[@]} ]; then
        echo "无效选项。"
        exit 1
    fi
    storage=${storages[$choice]}
    storage_path=${paths[$choice]}
    echo "已选择存储：$storage (路径: $storage_path)"
}

# 函数：显示发行版选项菜单
show_distro_menu() {
    echo "====================================="
    echo "请选择要创建的发行版："
    echo "1. Debian 12"
    echo "2. Debian 11"
    echo "3. CentOS 9 Stream"
    echo "4. CentOS 8 Stream"
    echo "5. Ubuntu 22.04"
    echo "6. Ubuntu 24.04"
    echo "7. AlmaLinux 8"
    echo "8. AlmaLinux 9"
    echo "9. Rocky Linux 8"
    echo "10. Rocky Linux 9"
    echo -n "请输入选项 (1-10)："
    read -r choice
    case $choice in
        1)
            distro="debian12"
            image_url="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
            image_file="debian-12-generic-amd64.qcow2"
            vm_name="Debian-12"
            ;;
        2)
            distro="debian11"
            image_url="https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2"
            image_file="debian-11-generic-amd64.qcow2"
            vm_name="Debian-11"
            ;;
        3)
            distro="centos9"
            image_url="https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"
            image_file="CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"
            vm_name="CentOS-9"
            ;;
        4)
            distro="centos8"
            image_url="https://cloud.centos.org/centos/8-stream/x86_64/images/CentOS-Stream-GenericCloud-8-latest.x86_64.qcow2"
            image_file="CentOS-Stream-GenericCloud-8-latest.x86_64.qcow2"
            vm_name="CentOS-8"
            ;;
        5)
            distro="ubuntu22"
            image_url="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
            image_file="jammy-server-cloudimg-amd64.img"
            vm_name="Ubuntu-22"
            ;;
        6)
            distro="ubuntu24"
            image_url="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
            image_file="noble-server-cloudimg-amd64.img"
            vm_name="Ubuntu-24"
            ;;
        7)
            distro="alma8"
            image_url="https://repo.almalinux.org/almalinux/8/cloud/x86_64/images/AlmaLinux-8-GenericCloud-latest.x86_64.qcow2"
            image_file="AlmaLinux-8-GenericCloud-latest.x86_64.qcow2"
            vm_name="AlmaLinux-8"
            ;;
        8)
            distro="alma9"
            image_url="https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
            image_file="AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
            vm_name="AlmaLinux-9"
            ;;
        9)
            distro="rocky8"
            image_url="https://download.rockylinux.org/pub/rocky/8/images/x86_64/Rocky-8-GenericCloud.latest.x86_64.qcow2"
            image_file="Rocky-8-GenericCloud.latest.x86_64.qcow2"
            vm_name="Rocky-8"
            ;;
        10)
            distro="rocky9"
            image_url="https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2"
            image_file="Rocky-9-GenericCloud.latest.x86_64.qcow2"
            vm_name="Rocky-9"
            ;;
        *)
            echo "无效选项。"
            exit 1
            ;;
    esac
    echo -n "请输入 VMID（例如 8000）："
    read -r vmid
    if ! [[ "$vmid" =~ ^[0-9]+$ ]]; then
        echo "VMID 必须是数字。"
        exit 1
    fi
}

# 函数：非交互模式设置发行版和 VMID
set_distro_and_vmid() {
    local choice=$1 input_vmid=$2
    case $choice in
        1)
            distro="debian12"
            image_url="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
            image_file="debian-12-generic-amd64.qcow2"
            vm_name="Debian-12"
            ;;
        2)
            distro="debian11"
            image_url="https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2"
            image_file="debian-11-generic-amd64.qcow2"
            vm_name="Debian-11"
            ;;
        3)
            distro="centos9"
            image_url="https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"
            image_file="CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"
            vm_name="CentOS-9"
            ;;
        4)
            distro="centos8"
            image_url="https://cloud.centos.org/centos/8-stream/x86_64/images/CentOS-Stream-GenericCloud-8-latest.x86_64.qcow2"
            image_file="CentOS-Stream-GenericCloud-8-latest.x86_64.qcow2"
            vm_name="CentOS-8"
            ;;
        5)
            distro="ubuntu22"
            image_url="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
            image_file="jammy-server-cloudimg-amd64.img"
            vm_name="Ubuntu-22"
            ;;
        6)
            distro="ubuntu24"
            image_url="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
            image_file="noble-server-cloudimg-amd64.img"
            vm_name="Ubuntu-24"
            ;;
        7)
            distro="alma8"
            image_url="https://repo.almalinux.org/almalinux/8/cloud/x86_64/images/AlmaLinux-8-GenericCloud-latest.x86_64.qcow2"
            image_file="AlmaLinux-8-GenericCloud-latest.x86_64.qcow2"
            vm_name="AlmaLinux-8"
            ;;
        8)
            distro="alma9"
            image_url="https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
            image_file="AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
            vm_name="AlmaLinux-9"
            ;;
        9)
            distro="rocky8"
            image_url="https://download.rockylinux.org/pub/rocky/8/images/x86_64/Rocky-8-GenericCloud.latest.x86_64.qcow2"
            image_file="Rocky-8-GenericCloud.latest.x86_64.qcow2"
            vm_name="Rocky-8"
            ;;
        10)
            distro="rocky9"
            image_url="https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2"
            image_file="Rocky-9-GenericCloud.latest.x86_64.qcow2"
            vm_name="Rocky-9"
            ;;
        *)
            echo "无效选项。"
            exit 1
            ;;
    esac
    vmid=$input_vmid
    if ! [[ "$vmid" =~ ^[0-9]+$ ]]; then
        echo "VMID 必须是数字。"
        exit 1
    fi
}

# 函数：销毁已存在的虚拟机
destroy_existing_vm() {
    local vmid=$1
    if qm status $vmid >/dev/null 2>&1; then
        echo "检测到 VMID $vmid 已存在，是否销毁？（Y/N）"
        read -r confirm
        if [[ "$confirm" != "Y" && "$confirm" != "y" ]]; then
            echo "操作取消。"
            exit 1
        fi
        echo "正在销毁 VMID $vmid..."
        qm stop $vmid 2>/dev/null
        qm destroy $vmid --destroy-unreferenced-disks 1 --purge 1 || exit 1
    fi
}

# 函数：下载镜像
download_image() {
    local url=$1 file=$2
    echo "下载镜像：$file"
    wget -O "/tmp/$file" "$url" || { echo "下载失败。"; exit 1; }
}

# 函数：创建虚拟机
create_vm() {
    local vmid=$1 vm_name=$2 vmbr=$3
    echo "创建虚拟机：$vm_name (VMID: $vmid)"
    qm create $vmid --memory 2048 --core 2 --name "$vm_name" --net0 virtio,bridge=$vmbr --ide0 none || exit 1
}

# 函数：导入磁盘
import_disk() {
    local vmid=$1 image_file=$2 storage=$3
    echo "导入磁盘到存储：$storage"
    qm importdisk $vmid "/tmp/$image_file" "$storage" --format qcow2 || exit 1
}

# 函数：配置虚拟机
configure_vm() {
    local vmid=$1 storage=$2
    echo "配置虚拟机..."
    qm set $vmid --scsihw virtio-scsi-pci --scsi0 "$storage:vm-$vmid-disk-0" || exit 1
    qm set $vmid --ide2 "$storage:cloudinit" || exit 1
    qm set $vmid --boot c --bootdisk scsi0 || exit 1
    qm set $vmid --serial0 socket --vga serial0 || exit 1
}

# 函数：定制镜像（启用Root、安装Agent、清除machine-id）
customize_image() {
    local vmid=$1 storage=$2 distro=$3
    storage_path=$(pvesm path "$storage") || { echo "获取存储路径失败。"; exit 1; }
    disk_path="$storage_path/$vmid/vm-$vmid-disk-0.qcow2"
    [ -f "$disk_path" ] || { echo "磁盘文件不存在：$disk_path"; exit 1; }

    if ! command -v virt-customize &>/dev/null; then
        echo "安装 libguestfs-tools..."
        apt-get update && apt-get install -y libguestfs-tools || exit 1
    fi

    echo "启用Root登录..."
    virt-customize -a "$disk_path" --edit '/etc/ssh/sshd_config:s/^#*PermitRootLogin.*/PermitRootLogin yes/' --selinux-relabel

    echo "安装 qemu-guest-agent..."
    virt-customize -a "$disk_path" --install qemu-guest-agent

    echo "清除 machine-id..."
    virt-customize -a "$disk_path" --run-command "echo -n > /etc/machine-id && ln -sf /run/machine-id /etc/machine-id 2>/dev/null || true"
}

# 主函数
main() {
    if [ $# -eq 2 ]; then
        set_distro_and_vmid "$1" "$2"
        vmbr=${VMBR:-"vmbr0"}
        storage=${STORAGE:-"local"}
        storage_path=$(pvesm path "$storage") || exit 1
    else
        show_distro_menu
        prompt_for_network
        prompt_for_storage
    fi

    destroy_existing_vm "$vmid"
    download_image "$image_url" "$image_file"
    create_vm "$vmid" "$vm_name" "$vmbr"
    import_disk "$vmid" "$image_file" "$storage"
    configure_vm "$vmid" "$storage"
    customize_image "$vmid" "$storage" "$distro"
    convert_to_template "$vmid"
    rm -f "/tmp/$image_file"

    echo "====================================="
    echo "模板 $vm_name (VMID: $vmid) 创建完成！"
    echo "====================================="
}

# 执行主函数
main "$@"
