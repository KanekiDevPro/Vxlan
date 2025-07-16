[فارسی](README_FA.md)
# VXLAN Tunnel Manager

<img width="1118" height="624" alt="image" src="https://github.com/user-attachments/assets/7e395ec5-563c-4a13-bee3-a790d7583b9c" />

Easy and automated VXLAN tunnel management on Linux using systemd.

---

## 🔥 Introduction

This script allows you to easily create, manage, backup, and transfer VXLAN tunnels.  
With an interactive user-friendly interface and automatic prerequisite checks, manage your VXLAN networks with ease.

---

## 🚀 Features

- Create VXLAN tunnels with selectable VNI and custom or random IPs  
- Manage systemd services for tunnels (start, stop, restart, enable on boot)  
- Display tunnel status and edit services on the fly  
- Automatic backup of related files and services  
- Easy transfer of settings and files to other servers via SSH  
- Automatic check and install of required tools (ip, dig, zip)  

---

## 📋 Prerequisites

- Operating System: Linux distributions (Ubuntu, Debian, CentOS, etc.)  
- Required tools:
  - `ip` (package iproute2)  
  - `dig` (from dnsutils package)  
  - `zip` (for backups)  
- systemd for service management

---

## How to Run?
Run the following script on your server (Debian or Ubuntu):

```
bash <(curl -Ls https://raw.githubusercontent.com/KanekiDevPro/Vxlan/main/main.sh)
```

```
bash <(curl -Ls https://raw.githubusercontent.com/KanekiDevPro/Vxlan/main/beta.sh)
```

```
bash <(curl -Ls https://raw.githubusercontent.com/KanekiDevPro/Vxlan/main/beta2.sh)
```

## 🛠️ Important Notes

- When creating a tunnel, set the same VNI on both servers.  
- Tunnel IPs should be in separate, non-overlapping ranges.  
- Ensure UDP port 4789 is open in the firewall.  
- systemd services auto-enable but can be manually managed with `systemctl`.  
- Use the "Transfer Files" option in the script menu to transfer settings to another server.

---

## 🛡️ Support & Issues

For issues or suggestions, please open an Issue or contact us.

---

## 📄 License

This project is licensed under the MIT License.

---

## 👤 Author

[KanekiDevPro]  
GitHub: [https://github.com/KanekiDevPro](https://github.com/KanekiDevPro)

---

## ⚡ Thank you for using VXLAN Tunnel Manager!
