#!/bin/bash

# 函数：提示用户输入网络接口和存储
prompt_for_network_and_storage() {
    echo -n "请输入网络接口（例如 vmbr0，默认为 vmbr0）："
    read -r vmbr
    if [ -z "$vmbr" ]; then
        vmbr="vmbr0"
    fi

    echo -n "请输入存储名称（例如 local，默认为 local）："
    read -r storage
    if [ -z "$storage" ]; then
        storage="local"
    fi
}

# 函数：设置发行版信息
set_distro_info() {
    local choice=$1
    local input_vmid=$2

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
            echo "无效选项：$choice，请选择 1-10 之间的数字。"
            exit 1
            ;;
    esac

    vmid=$input_vmid
    if ! [[ "$vmid" =~ ^[0-9]+$ ]]; then
        echo "VMID 必须是数字：$vmid"
        exit 1
    fi
}

# 函数：检查并销毁已存在的虚拟机（自动确认销毁）
destroy_existing_vm() {
    local vmid=$1
    if qm status $vmid >/dev/null 2>&1; then
        echo "检测到 VMID $vmid 已存在，自动销毁..."
        # 停止虚拟机（如果正在运行）
        qm stop $vmid 2>/dev/null
        # 销毁虚拟机
        qm destroy $vmid --destroy-unreferenced-disks 1 --purge 1
        if [ $? -ne 0 ]; then
            echo "销毁虚拟机失败：VMID $vmid"
            exit 1
        fi
        echo "已销毁 VMID $vmid 及其未引用磁盘和作业配置。"
    fi
}

# 函数：下载镜像
download_image() {
    local url=$1
    local file=$2
    echo "正在下载 $file ..."
    wget -O /tmp/$file $url
    if [ $? -ne 0 ]; then
        echo "下载失败：$url"
        echo "请检查网络连接或镜像地址是否有效。"
        exit 1
    fi
}

# 函数：创建虚拟机
create_vm() {
    local vmid=$1
    local vm_name=$2
    local vmbr=$3
    echo "正在创建虚拟机 $vm_name (VMID: $vmid)..."
    # 创建虚拟机时不添加默认硬盘，使用用户指定的网络接口
    qm create $vmid --memory 2048 --core 2 --name $vm_name --net0 virtio,bridge=$vmbr --ide0 none
    if [ $? -ne 0 ]; then
        echo "创建虚拟机失败：VMID $vmid"
        exit 1
    fi
}

# 函数：导入磁盘
import_disk() {
    local vmid=$1
    local image_file=$2
    local storage=$3
    # 导入磁盘到用户指定的存储
    echo "正在导入磁盘 /tmp/$image_file 到 $storage 存储..."
    qm importdisk $vmid /tmp/$image_file $storage --format qcow2
    if [ $? -ne 0 ]; then
        echo "导入磁盘失败：$image_file"
        exit 1
    fi
    # 检查导入的磁盘文件是否存在（路径可能因存储类型不同而变化）
    if [ ! -f "/var/lib/vz/images/$vmid/vm-$vmid-disk-0.qcow2" ]; then
        echo "警告：未在 /var/lib/vz/images/$vmid/ 找到磁盘文件，可能是存储路径不同，请手动检查。"
    else
        echo "磁盘文件 /var/lib/vz/images/$vmid/vm-$vmid-disk-0.qcow2 已成功生成。"
    fi
}

# 函数：配置虚拟机
configure_vm() {
    local vmid=$1
    local storage=$2
    # 设置 SCSI 控制器并挂载导入的磁盘
    echo "正在挂载磁盘 $storage:$vmid/vm-$vmid-disk-0.qcow2 到 scsi0..."
    qm set $vmid --scsihw virtio-scsi-pci --scsi0 $storage:$vmid/vm-$vmid-disk-0.qcow2
    if [ $? -ne 0 ]; then
        echo "挂载磁盘到 scsi0 失败：VMID $vmid"
        # 打印存储内容以供调试
        echo "当前 $storage 存储内容："
        ls -lh /var/lib/vz/images/$vmid/ 2>/dev/null || echo "无法列出存储内容，可能是存储路径不同。"
        exit 1
    fi
    # 配置 CloudInit、启动顺序等
    qm set $vmid --ide2 $storage:cloudinit
    qm set $vmid --boot c --bootdisk scsi0
    qm set $vmid --serial0 socket --vga serial0
}

# 函数：将虚拟机转换为模板
convert_to_template() {
    local vmid=$1
    echo "正在将 VMID $vmid 转换为模板..."
    qm template $vmid
    if [ $? -ne 0 ]; then
        echo "转换为模板失败：VMID $vmid"
        exit 1
    fi
}

# 函数：创建单个模板
create_template() {
    local distro_option=$1
    local vmid=$2
    local vmbr=$3
    local storage=$4

    # 设置发行版信息
    set_distro_info $distro_option $vmid

    # 检查并销毁已存在的虚拟机
    destroy_existing_vm $vmid

    # 下载镜像
    download_image $image_url $image_file

    # 创建虚拟机
    create_vm $vmid $vm_name $vmbr

    # 导入磁盘
    import_disk $vmid $image_file $storage

    # 配置虚拟机
    configure_vm $vmid $storage

    # 转换为模板
    convert_to_template $vmid

    # 清理临时文件
    rm /tmp/$image_file

    echo "====================================="
    echo "虚拟机模板 $vm_name (VMID: $vmid) 创建并转换为模板完成！"
    echo "====================================="
}

# 函数：自动创建所有模板
create_all_templates() {
    local start_vmid=8000
    local distro_count=10  # 总共有 10 个发行版
    local current_vmid=$start_vmid

    # 发行版名称（仅用于显示）
    declare -A distro_names
    distro_names[1]="Debian 12"
    distro_names[2]="Debian 11"
    distro_names[3]="CentOS 9 Stream"
    distro_names[4]="CentOS 8 Stream"
    distro_names[5]="Ubuntu 22.04"
    distro_names[6]="Ubuntu 24.04"
    distro_names[7]="AlmaLinux 8"
    distro_names[8]="AlmaLinux 9"
    distro_names[9]="Rocky Linux 8"
    distro_names[10]="Rocky Linux 9"

    for distro_option in $(seq 1 $distro_count); do
        echo "====================================="
        echo "正在为 ${distro_names[$distro_option]} 创建模板，VMID: $current_vmid"
        echo "====================================="

        # 创建模板
        create_template $distro_option $current_vmid $vmbr $storage

        # VMID 递增
        current_vmid=$((current_vmid + 1))
    done
}

# 主函数
main() {
    echo "====================================="
    echo "开始一键安装所有 Proxmox VE 模板"
    echo "VMID 将从 8000 开始递增"
    echo "====================================="

    # 提示用户输入网络接口和存储
    prompt_for_network_and_storage

    # 创建所有模板
    create_all_templates

    echo "====================================="
    echo "所有模板创建完成！"
    echo "创建的模板 VMID 范围：8000 - $((8000 + 10 - 1))"
    echo "====================================="
}

# 运行主函数
main
