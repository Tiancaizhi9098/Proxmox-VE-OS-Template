#!/bin/bash

# 函数：显示网卡选择菜单并获取网卡名称
prompt_for_network() {
    echo "====================================="
    echo "请选择网络接口："
    echo "====================================="

    # 获取所有网络接口，并保存到数组
    local interfaces=()
    local index=1

    # 使用 ip link 获取网络接口
    while IFS=': ' read -r num iface rest; do
        if [[ "$num" =~ ^[0-9]+$ && -n "$iface" && "$iface" != "lo" ]]; then
            interfaces[$index]=$iface
            echo "$index. $iface"
            ((index++))
        fi
    done < <(ip link | grep '^[0-9]')

    if [ ${#interfaces[@]} -eq 0 ]; then
        echo "错误：未找到可用的网络接口。请检查网络配置："
        echo "  ip link"
        exit 1
    fi

    # 提示用户选择网卡
    echo -n "请输入选项 (1-${#interfaces[@]})："
    read -r choice

    # 验证用户输入
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#interfaces[@]} ]; then
        echo "无效选项，请选择 1-${#interfaces[@]} 之间的数字。"
        exit 1
    fi

    # 设置网卡名称
    vmbr=${interfaces[$choice]}
    echo "已选择网络接口：$vmbr"
}

# 函数：显示存储选择菜单并获取存储名称
prompt_for_storage() {
    echo "====================================="
    echo "请选择存储目标："
    echo "====================================="

    # 获取所有可用存储，并保存到数组
    local storages=()
    local paths=()
    local types=()
    local index=1

    # 使用 pvesm status 获取存储信息
    while IFS=' ' read -r name type status total used avail; do
        if [[ "$status" == "active" && "$name" != "Name" ]]; then
            # 获取存储路径
            path=$(pvesm path $name 2>/dev/null || echo "未知路径")
            storages[$index]=$name
            paths[$index]=$path
            types[$index]=$type
            echo "$index. $name (类型: $type, 路径: $path)"
            ((index++))
        fi
    done < <(pvesm status)

    if [ ${#storages[@]} -eq 0 ]; then
        echo "错误：未找到可用的存储。请检查存储配置："
        echo "  pvesm status"
        exit 1
    fi

    # 提示用户选择存储
    echo -n "请输入选项 (1-${#storages[@]})："
    read -r choice

    # 验证用户输入
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#storages[@]} ]; then
        echo "无效选项，请选择 1-${#storages[@]} 之间的数字。"
        exit 1
    fi

    # 设置存储名称
    storage=${storages[$choice]}
    echo "已选择存储：$storage (路径: ${paths[$choice]})"
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
            sha256_url="https://cloud.debian.org/images/cloud/bookworm/latest/SHA256SUMS"
            package_manager="apt"
            ;;
        2)
            distro="debian11"
            image_url="https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2"
            image_file="debian-11-generic-amd64.qcow2"
            vm_name="Debian-11"
            sha256_url="https://cloud.debian.org/images/cloud/bullseye/latest/SHA256SUMS"
            package_manager="apt"
            ;;
        3)
            distro="centos9"
            image_url="https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"
            image_file="CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"
            vm_name="CentOS-9"
            sha256_url="https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2.SHA256SUM"
            package_manager="dnf"
            ;;
        4)
            distro="centos8"
            image_url="https://cloud.centos.org/centos/8-stream/x86_64/images/CentOS-Stream-GenericCloud-8-latest.x86_64.qcow2"
            image_file="CentOS-Stream-GenericCloud-8-latest.x86_64.qcow2"
            vm_name="CentOS-8"
            sha256_url="https://cloud.centos.org/centos/8-stream/x86_64/images/CentOS-Stream-GenericCloud-8-latest.x86_64.qcow2.SHA256SUM"
            package_manager="dnf"
            ;;
        5)
            distro="ubuntu22"
            image_url="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
            image_file="jammy-server-cloudimg-amd64.img"
            vm_name="Ubuntu-22"
            sha256_url="https://cloud-images.ubuntu.com/jammy/current/SHA256SUMS"
            package_manager="apt"
            ;;
        6)
            distro="ubuntu24"
            image_url="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
            image_file="noble-server-cloudimg-amd64.img"
            vm_name="Ubuntu-24"
            sha256_url="https://cloud-images.ubuntu.com/noble/current/SHA256SUMS"
            package_manager="apt"
            ;;
        7)
            distro="alma8"
            image_url="https://repo.almalinux.org/almalinux/8/cloud/x86_64/images/AlmaLinux-8-GenericCloud-latest.x86_64.qcow2"
            image_file="AlmaLinux-8-GenericCloud-latest.x86_64.qcow2"
            vm_name="AlmaLinux-8"
            sha256_url="https://repo.almalinux.org/almalinux/8/cloud/x86_64/images/AlmaLinux-8-GenericCloud-latest.x86_64.qcow2.sha256"
            package_manager="dnf"
            ;;
        8)
            distro="alma9"
            image_url="https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
            image_file="AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
            vm_name="AlmaLinux-9"
            sha256_url="https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2.sha256"
            package_manager="dnf"
            ;;
        9)
            distro="rocky8"
            image_url="https://download.rockylinux.org/pub/rocky/8/images/x86_64/Rocky-8-GenericCloud.latest.x86_64.qcow2"
            image_file="Rocky-8-GenericCloud.latest.x86_64.qcow2"
            vm_name="Rocky-8"
            sha256_url="https://download.rockylinux.org/pub/rocky/8/images/x86_64/Rocky-8-GenericCloud.latest.x86_64.qcow2.sha256sum"
            package_manager="dnf"
            ;;
        10)
            distro="rocky9"
            image_url="https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2"
            image_file="Rocky-9-GenericCloud.latest.x86_64.qcow2"
            vm_name="Rocky-9"
            sha256_url="https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2.sha256sum"
            package_manager="dnf"
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

# 函数：下载并验证镜像
download_and_verify_image() {
    local url=$1
    local file=$2
    local sha256_url=$3

    # 下载镜像
    echo "正在下载 $file ..."
    wget -O /tmp/$file $url
    if [ $? -ne 0 ]; then
        echo "下载失败：$url"
        echo "请检查网络连接或镜像地址是否有效。"
        exit 1
    fi

    # 下载校验和文件
    echo "正在下载校验和文件..."
    wget -O /tmp/SHA256SUMS $sha256_url
    if [ $? -ne 0 ]; then
        echo "下载校验和文件失败：$sha256_url"
        echo "将跳过校验和验证，继续创建模板。"
        return
    fi

    # 计算本地文件的 SHA256 校验和
    local_sha256=$(sha256sum /tmp/$file | awk '{print $1}')
    echo "本地文件 SHA256 校验和：$local_sha256"

    # 从校验和文件中提取目标文件的校验和
    expected_sha256=$(grep $file /tmp/SHA256SUMS | awk '{print $1}')
    if [ -z "$expected_sha256" ]; then
        echo "未在校验和文件中找到 $file 的校验和，跳过验证。"
        rm /tmp/SHA256SUMS
        return
    fi
    echo "预期 SHA256 校验和：$expected_sha256"

    # 比较校验和
    if [ "$local_sha256" != "$expected_sha256" ]; then
        echo "校验和不匹配，镜像文件可能已损坏。"
        rm /tmp/$file /tmp/SHA256SUMS
        exit 1
    fi
    echo "校验和验证通过！"

    # 清理校验和文件
    rm /tmp/SHA256SUMS
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

# 函数：创建虚拟机
create_vm() {
    local vmid=$1
    local vm_name=$2
    local vmbr=$3
    echo "正在创建虚拟机 $vm_name (VMID: $vmid)..."
    # 创建虚拟机，使用 host CPU 类型，启用 QEMU Guest Agent
    qm create $vmid --memory 2048 --cores 2 --cpu host --name $vm_name --net0 virtio,bridge=$vmbr --ide0 none --agent 1
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
}

# 函数：配置 CloudInit 并注入用户数据
configure_cloudinit() {
    local vmid=$1
    local storage=$2
    local package_manager=$3

    # 设置 SCSI 控制器并挂载导入的磁盘
    echo "正在挂载磁盘 $storage:vm-$vmid-disk-0 到 scsi0..."
    qm set $vmid --scsihw virtio-scsi-pci --scsi0 $storage:vm-$vmid-disk-0
    if [ $? -ne 0 ]; then
        echo "挂载磁盘到 scsi0 失败：VMID $vmid"
        exit 1
    fi

    # 配置 CloudInit、启动顺序等
    qm set $vmid --ide2 $storage:cloudinit
    if [ $? -ne 0 ]; then
        echo "配置 CloudInit 失败：VMID $vmid"
        exit 1
    fi
    qm set $vmid --boot c --bootdisk scsi0
    qm set $vmid --serial0 socket --vga serial0

    # 生成 CloudInit 用户数据脚本
    echo "生成 CloudInit 用户数据..."
    cat > /tmp/user-data <<EOF
#cloud-config
# 启用 root 登录并设置密码
chpasswd:
  list: |
    root:password123
  expire: False

# 修改 SSH 配置以允许 root 登录
runcmd:
  - sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
  - systemctl restart sshd

# 根据发行版安装 qemu-guest-agent
  - if [ "$package_manager" = "apt" ]; then
      apt update && apt install -y qemu-guest-agent && systemctl enable qemu-guest-agent && systemctl start qemu-guest-agent
    elif [ "$package_manager" = "dnf" ]; then
      dnf install -y qemu-guest-agent && systemctl enable qemu-guest-agent && systemctl start qemu-guest-agent
    fi

# 清除 machine-id
  - truncate -s 0 /etc/machine-id
  - if [ -f /var/lib/dbus/machine-id ]; then truncate -s 0 /var/lib/dbus/machine-id; fi

# 确保所有更改写入磁盘
  - sync
EOF

    # 将用户数据编码为 base64 并注入到 CloudInit
    user_data_base64=$(base64 -w 0 /tmp/user-data)
    qm set $vmid --cicustom "user=local:snippets/user-data-$vmid.yml"
    echo "user: $user_data_base64" > /var/lib/vz/snippets/user-data-$vmid.yml

    # 清理临时文件
    rm /tmp/user-data
}

# 函数：临时启动虚拟机以应用 CloudInit 配置
apply_cloudinit() {
    local vmid=$1
    echo "临时启动虚拟机以应用 CloudInit 配置..."
    qm start $vmid
    if [ $? -ne 0 ]; then
        echo "启动虚拟机失败：VMID $vmid"
        exit 1
    fi

    # 等待 CloudInit 完成（60秒）
    echo "等待 60 秒以确保 CloudInit 配置完成..."
    sleep 60

    # 停止虚拟机
    echo "停止虚拟机..."
    qm stop $vmid
    if [ $? -ne 0 ]; then
        echo "停止虚拟机失败：VMID $vmid"
        exit 1
    fi
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

    # 清理 CloudInit 用户数据文件
    rm /var/lib/vz/snippets/user-data-$vmid.yml
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

    # 下载并验证镜像
    download_and_verify_image $image_url $image_file $sha256_url

    # 创建虚拟机
    create_vm $vmid $vm_name $vmbr

    # 导入磁盘
    import_disk $vmid $image_file $storage

    # 配置 CloudInit 并注入用户数据
    configure_cloudinit $vmid $storage $package_manager

    # 临时启动虚拟机以应用 CloudInit 配置
    apply_cloudinit $vmid

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

    # 提示用户选择网络接口
    prompt_for_network

    # 提示用户选择存储
    prompt_for_storage

    # 创建所有模板
    create_all_templates

    echo "====================================="
    echo "所有模板创建完成！"
    echo "创建的模板 VMID 范围：8000 - $((8000 + 10 - 1))"
    echo "====================================="
}

# 运行主函数
main
