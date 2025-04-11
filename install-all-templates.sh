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

# 函数：下载 create-templates.sh 脚本
download_create_templates() {
    echo "正在下载 create-templates.sh 脚本..."
    wget -O create-templates.sh https://raw.githubusercontent.com/Tiancaizhi9098/Proxmox-VE-OS-Template/refs/heads/main/create-templates.sh
    if [ $? -ne 0 ]; then
        echo "下载 create-templates.sh 失败，请检查网络连接或 URL 是否正确。"
        exit 1
    fi
    chmod +x create-templates.sh
    echo "create-templates.sh 已下载并设置权限。"
}

# 函数：检查 create-templates.sh 是否存在
check_create_templates() {
    if [ ! -f "create-templates.sh" ]; then
        echo "create-templates.sh 不存在，尝试下载..."
        download_create_templates
    elif [ ! -x "create-templates.sh" ]; then
        echo "create-templates.sh 没有执行权限，设置权限..."
        chmod +x create-templates.sh
    fi
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

        # 直接调用 create-templates.sh，传递发行版选项和 VMID
        # 模拟销毁确认（自动输入 Y），并提供网络接口和存储
        echo -e "Y\n$vmbr\n$storage" | ./create-templates.sh $distro_option $current_vmid

        if [ $? -ne 0 ]; then
            echo "创建 ${distro_names[$distro_option]} (VMID: $current_vmid) 失败，脚本退出。"
            exit 1
        fi

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

    # 检查并下载 create-templates.sh
    check_create_templates

    # 创建所有模板
    create_all_templates

    echo "====================================="
    echo "所有模板创建完成！"
    echo "创建的模板 VMID 范围：8000 - $((8000 + 10 - 1))"
    echo "====================================="
}

# 运行主函数
main
