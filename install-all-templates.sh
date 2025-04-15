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

        # 设置环境变量 VMBR 和 STORAGE，传递给 create-templates.sh
        export VMBR=$vmbr
        export STORAGE=$storage

        # 直接调用 create-templates.sh，传递发行版选项和 VMID
        # 模拟销毁确认（自动输入 Y）
        echo "Y" | ./create-templates.sh $distro_option $current_vmid

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

    # 提示用户选择网络接口
    prompt_for_network

    # 提示用户选择存储
    prompt_for_storage

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
