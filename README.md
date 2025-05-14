# Proxmox VE OS Template 创建工具

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Debian](https://img.shields.io/badge/Debian-11%7C12-red)](https://www.debian.org/)
[![Proxmox](https://img.shields.io/badge/Proxmox-8.x-orange)](https://www.proxmox.com/)

这是一个用于 Proxmox VE 的 Cloud-Init 模板虚拟机快速创建工具，支持自动下载官方 Debian Cloud 镜像并生成可立即使用的模板。

## 🚀 功能特点

- 🔄 **交互式菜单设计**：通过简单的交互式菜单选择所需系统版本和设置
- 📦 **自动下载镜像**：支持自动下载 Debian 11/12 Cloud-Init 官方镜像
- 🔧 **全自动配置**：自动化完成从镜像导入到模板创建的全过程
- 🔍 **智能检测**：检测已存在的 VMID 并提供处理选项
- 🌉 **网络自动配置**：智能检测并选择可用的网络桥接接口
- 💾 **存储灵活选择**：支持选择不同的存储目标位置
- 🔒 **安全设置**：默认启用 root 用户及密码登录

## 📋 系统要求

- Proxmox VE 8.x
- 运行脚本需要 root 权限
- 需要联网环境以下载系统镜像
- `jq` 工具 (用于解析 JSON)

## 💻 一键安装使用

```bash
bash <(curl -s https://raw.githubusercontent.com/Tiancaizhi9098/Proxmox-VE-OS-Template/main/pve_template_creator.sh)
```

## 🛠️ 使用步骤

1. **选择 Debian 版本**：目前支持 Debian 11 (Bullseye) 和 Debian 12 (Bookworm)
2. **设置 VMID**：输入自定义的 VMID（例如：8000）
3. **选择存储位置**：选择您想要存储模板的存储位置（如 local、local-lvm 等）
4. **选择网络桥接**：选择您的虚拟机将使用的网络桥接接口（如 vmbr0）
5. **设置 CPU、内存和磁盘**：配置虚拟机的硬件参数
6. **设置 root 密码**：为模板设置 root 用户密码
7. **等待创建完成**：脚本会自动下载镜像并完成配置

## 🔑 模板信息

创建完成的模板信息：

- **用户名**：`root`
- **密码**：您在创建过程中设置的密码
- **SSH 公钥**：使用宿主机 root 用户的 SSH 公钥（如果存在）

## 📝 后续使用

模板创建完成后，您可以通过以下方式从模板克隆新的虚拟机：

```bash
qm clone <模板VMID> <新VMID> --name <新虚拟机名称>
```

例如：

```bash
qm clone 8000 101 --name web-server
```

> **安全提示**：请记得在首次使用克隆的虚拟机时审查安全设置！

## 📄 许可证

本项目采用 MIT 许可证

## 🤝 贡献

欢迎提交 Issue 或 Pull Request 来完善此项目！

---

如有任何问题或建议，请在 [GitHub Issues](https://github.com/Tiancaizhi9098/Proxmox-VE-OS-Template/issues) 提出 