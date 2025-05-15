# Proxmox VE OS Template - 云镜像定制与PVE模板创建工具

![logo](https://raw.githubusercontent.com/Tiancaizhi9098/Proxmox-VE-OS-Template/main/resources/logo.png)

## 📋 项目介绍

这是一个用于在Proxmox VE上自动下载、定制和创建多种Linux发行版云镜像模板的工具。通过本工具，您可以轻松创建支持Cloud-Init的虚拟机模板，并自动配置root登录、软件预装等功能。

### 🌟 特色功能

- 🔄 自动下载和处理官方云镜像
- 🛠️ 预装必要软件如qemu-guest-agent等
- 🔐 配置SSH允许root密码登录
- 🌐 配置Cloud-Init支持
- 🕒 自动设置亚洲/上海时区
- 📦 支持多种主流Linux发行版
- 🧩 自动识别PVE存储配置

## 💻 支持的Linux发行版

按字母顺序排列的支持发行版：

- **AlmaLinux**: 9, 8
- **Alpine Linux**: 3.19, 3.18
- **CentOS**: 9-stream, 8-stream
- **Debian**: 12, 11, 10
- **Fedora**: 40, 39
- **Kali Linux**: 2023.4
- **Rocky Linux**: 9, 8
- **Ubuntu**: 24.04, 22.04, 20.04
- **openSUSE**: Tumbleweed, Leap 15.5

## 🚀 快速开始

### 一键安装运行

```bash
bash <(curl -s https://raw.githubusercontent.com/Tiancaizhi9098/Proxmox-VE-OS-Template/main/create_pve_templates.sh)
```

### 手动安装

1. 克隆仓库
```bash
git clone https://github.com/Tiancaizhi9098/Proxmox-VE-OS-Template.git
cd Proxmox-VE-OS-Template
```

2. 设置执行权限并运行
```bash
chmod +x create_pve_templates.sh
./create_pve_templates.sh
```

## 📝 使用方法

1. 运行脚本后，将显示菜单界面
2. 选择要创建的Linux发行版模板
3. 选择存储位置（默认使用第一个可用存储）
4. 指定虚拟机ID（默认从9000开始）
5. 脚本将自动下载、定制镜像并创建虚拟机
6. 完成后可选择是否将虚拟机转换为模板

### 从模板克隆虚拟机

创建模板后，您可以通过PVE界面或命令行从模板克隆新的虚拟机：

```bash
# 从模板克隆新虚拟机
qm clone <模板ID> <新虚拟机ID> --name <新虚拟机名称>

# 设置Cloud-Init参数
qm set <新虚拟机ID> --ciuser root --cipassword <密码>
qm set <新虚拟机ID> --ipconfig0 ip=dhcp
```

## 🔧 定制内容

本工具对所有镜像进行了以下定制：

1. 预装软件：
   - qemu-guest-agent
   - htop
   - git
   - neofetch
   - tree
   - 其他系统特定软件

2. 配置：
   - 允许SSH root登录
   - 允许密码认证登录
   - 设置亚洲/上海时区
   - 配置Cloud-Init支持

## ⚠️ 注意事项

- 需要在Proxmox VE环境下运行
- 需要root权限
- 确保有足够的存储空间用于下载和处理镜像
- 默认磁盘空间会调整为32G，可以根据需要在脚本中修改

## 💡 问题排查

常见问题：

- **依赖问题**：脚本会自动安装所需依赖
- **导入失败**：检查存储空间和权限
- **Cloud-Init配置问题**：确认虚拟机已配置正确的Cloud-Init存储

## 📜 许可

MIT License 