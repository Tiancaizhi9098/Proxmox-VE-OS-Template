# Proxmox VE OS Template

[![GitHub issues](https://img.shields.io/github/issues/Tiancaizhi9098/Proxmox-VE-OS-Template)](https://github.com/Tiancaizhi9098/Proxmox-VE-OS-Template/issues)
[![GitHub license](https://img.shields.io/github/license/Tiancaizhi9098/Proxmox-VE-OS-Template)](https://github.com/Tiancaizhi9098/Proxmox-VE-OS-Template/blob/main/LICENSE)

## 简介 | Introduction

这是一个用于在Proxmox VE上自动创建Cloud-Init模板虚拟机的脚本。脚本提供交互式菜单，支持多种操作系统，自动完成镜像下载、虚拟机创建、磁盘导入及模板转换等操作。

This is a script for automatically creating Cloud-Init template virtual machines on Proxmox VE. The script provides an interactive menu, supports multiple operating systems, and automatically completes image download, virtual machine creation, disk import, and template conversion.

## 功能 | Features

- 通过交互式菜单选择操作系统版本
- 自动下载最新的Cloud镜像
- 自定义虚拟机ID (VMID)
- 自动检测并销毁同名VM (需确认)
- 选择存储目标和网络接口
- 开启Root和密码登录
- 一键转换为模板

## 支持的系统 | Supported Systems

- Debian 12 (Bookworm)
- Debian 11 (Bullseye)
- 更多系统将陆续添加...

## 一键安装与使用 | One-click Install and Use

在Proxmox VE节点上执行以下命令：

```bash
wget -O /usr/local/bin/create_pve_template.sh https://raw.githubusercontent.com/Tiancaizhi9098/Proxmox-VE-OS-Template/main/create_pve_template.sh && chmod +x /usr/local/bin/create_pve_template.sh && create_pve_template.sh
```

## 手动安装 | Manual Installation

1. 克隆仓库:

```bash
git clone https://github.com/Tiancaizhi9098/Proxmox-VE-OS-Template.git
```

2. 进入目录:

```bash
cd Proxmox-VE-OS-Template
```

3. 添加执行权限:

```bash
chmod +x create_pve_template.sh
```

4. 运行脚本:

```bash
./create_pve_template.sh
```

## 使用说明 | Usage

1. 运行脚本后，按照提示选择所需的操作系统版本
2. 输入VMID (范围1000-9999)
3. 选择存储位置
4. 选择网络接口
5. 确认配置信息
6. 等待脚本自动完成剩余操作

## 从模板创建VM | Create VM from Template

模板创建完成后，可以使用以下命令从模板克隆创建新的VM:

```bash
qm clone <template_id> <new_vmid> --name <vm_name>
```

## 贡献 | Contributing

欢迎提交Pull Request或创建Issue来帮助改进此项目。

## 许可证 | License

本项目采用MIT许可证。详情请参阅[LICENSE](LICENSE)文件。 