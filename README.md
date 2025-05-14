# Proxmox-VE-OS-Template

基于 Cloud-Init 的 Proxmox VE 操作系统模板生成工具

## 简介

这个脚本用于在 Proxmox VE 上自动创建基于 Cloud-Init 的操作系统模板。目前支持 Debian 11 和 Debian 12，后续会添加更多系统支持。

## 功能

- 交互式菜单选择系统版本
- 自动下载最新的云镜像
- 自定义虚拟机 ID
- 自动检测并删除同名虚拟机（需确认）
- 自定义存储位置
- 自定义网络接口
- 自动配置 Cloud-Init（启用 root 登录和密码认证）
- 转换为模板（可选）

## 一键安装使用

```bash
wget -O /usr/local/bin/create_template.sh https://raw.githubusercontent.com/Tiancaizhi9098/Proxmox-VE-OS-Template/main/create_template.sh && chmod +x /usr/local/bin/create_template.sh && create_template.sh
```

或者：

```bash
curl -s https://raw.githubusercontent.com/Tiancaizhi9098/Proxmox-VE-OS-Template/main/create_template.sh -o /usr/local/bin/create_template.sh && chmod +x /usr/local/bin/create_template.sh && create_template.sh
```

## 手动安装

1. 克隆仓库：

```bash
git clone https://github.com/Tiancaizhi9098/Proxmox-VE-OS-Template.git
```

2. 进入目录：

```bash
cd Proxmox-VE-OS-Template
```

3. 添加执行权限：

```bash
chmod +x create_template.sh
```

4. 运行脚本：

```bash
./create_template.sh
```

## 使用说明

1. 选择要创建的操作系统模板（Debian 11 或 Debian 12）
2. 输入虚拟机 ID（推荐 8000+）
3. 选择存储位置
4. 选择网络接口
5. 等待脚本自动完成下载、配置和创建过程
6. 选择是否将虚拟机转换为模板

## 默认设置

- **内存**：2GB
- **CPU 核心数**：2核
- **用户名**：root
- **密码**：ChangeMe2024!
- **SSH**：已启用密码认证

## 注意事项

- 脚本需要在 Proxmox VE 宿主机上以 root 权限运行
- 确保宿主机可以访问互联网以下载镜像
- 创建模板后，请通过克隆方式使用，而不是直接使用模板

## 后续工作

- 添加更多操作系统支持（Ubuntu, CentOS, Rocky Linux 等）
- 添加更多自定义选项（CPU, 内存, 磁盘大小等）
- 添加更多网络配置选项

## 贡献

欢迎通过 Issue 和 Pull Request 来完善这个项目。

## 许可

MIT 许可证
