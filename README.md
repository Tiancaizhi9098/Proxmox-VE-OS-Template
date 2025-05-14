# 🚀 Proxmox VE Cloud-Init 模板创建工具  
**一键生成支持 Cloud-Init 的虚拟机模板，支持多发行版快速部署！**
**支持WHMCS系统对接Proxmox使用**


## 📖 功能特性  
- **自动化流程**：通过交互式菜单选择系统版本，自动完成镜像下载、虚拟机创建、磁盘导入及模板转换  
- **Cloud-Init 集成**：预配置云初始化功能
- **一键脚本**：无需手动配置，通过单行命令快速部署  


## 🛠️ 安装与运行  
### 前置条件  
- 已部署 Proxmox VE 环境（建议版本 ≥ 7.0）  
- 具备 root 权限或 `qm` 命令执行权限  
- 网络连通性（用于下载系统镜像）  

### 一键部署  
```bash  
bash -c "$(wget -qO- https://raw.githubusercontent.com/Tiancaizhi9098/Proxmox-VE-OS-Template/main/create-templates.sh)"
```
### 一键部署全部模版  
```bash  
wget -O install-all-templates.sh https://raw.githubusercontent.com/Tiancaizhi9098/Proxmox-VE-OS-Template/refs/heads/main/install-all-templates.sh && chmod +x install-all-templates.sh && ./install-all-templates.sh  
```  


## 🚀 使用指南  
1. **选择发行版**：根据菜单提示输入对应数字（1-10）  
2. **输入 VMID**：自定义虚拟机 ID（例如：8000，需确保未被占用）  
3. **自动处理**：脚本将检测并销毁同名 VM（如需）、下载镜像、创建虚拟机、配置 Cloud-Init 并转换为模板  


## 📜 支持的发行版  
1. Debian 12
2. Debian 11
3. CentOS 9 Stream
4. CentOS 8 Stream
5. Ubuntu 24.04
6. Ubuntu 22.04
7. AlmaLinux 9
8. AlmaLinux 8
9. Rocky Linux 9
10. Rocky Linux 8

## ⚠️ 注意事项  
1. **VMID 唯一性**：请确保输入的 VMID 未被占用，脚本会提示销毁已存在的同名 VM（需手动确认）  
2. **镜像大小**：部分系统镜像较大（约 1-2GB），下载时间取决于网络速度  
3. **存储位置**：镜像默认导入到 Proxmox 的 `local` 存储，如需更改请修改脚本中的存储名称（如 `local-lvm`）  
4. **模板使用**：创建完成后，可在 Proxmox 网页端 **模板** 列表中找到对应条目，通过“克隆”快速生成新虚拟机  


## 🤝 贡献与反馈  
- 欢迎提交 [Issue](https://github.com/Tiancaizhi9098/Proxmox-VE-OS-Template/issues) 反馈问题或建议  
- 如需新增发行版支持，可通过 Pull Request 提交镜像链接及配置参数  


## 📄 许可证  
本项目采用 **MIT 许可证**，详见 [LICENSE](LICENSE) 文件。  
