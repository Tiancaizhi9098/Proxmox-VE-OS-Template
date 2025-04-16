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
            image
