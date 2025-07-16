
# VXLAN Tunnel Manager / مدیر تونل VXLAN

![VXLAN](https://upload.wikimedia.org/wikipedia/commons/thumb/0/0b/VXLAN.svg/320px-VXLAN.svg.png)

مدیریت آسان و خودکار تونل‌های VXLAN در لینوکس با استفاده از systemd.  
Easy and automated VXLAN tunnel management on Linux using systemd.

---

## 🔥 معرفی / Introduction

این اسکریپت به شما امکان می‌دهد به سادگی تونل‌های VXLAN ایجاد، مدیریت، پشتیبان‌گیری و انتقال دهید.  
This script allows you to easily create, manage, backup, and transfer VXLAN tunnels.  
با رابط تعاملی کاربرپسند و بررسی خودکار پیش‌نیازها، به‌راحتی شبکه‌های VXLAN خود را مدیریت کنید.  
With an interactive user-friendly interface and automatic prerequisite checks, manage your VXLAN networks with ease.

---

## 🚀 ویژگی‌ها / Features

- ایجاد تونل‌های VXLAN با انتخاب شناسه VNI و IPهای سفارشی یا تصادفی  
- Create VXLAN tunnels with selectable VNI and custom or random IPs  
- مدیریت سرویس‌های systemd برای تونل‌ها (شروع، توقف، راه‌اندازی مجدد، فعال‌سازی در بوت)  
- Manage systemd services for tunnels (start, stop, restart, enable on boot)  
- نمایش وضعیت تونل‌ها و ویرایش سرویس‌ها در لحظه  
- Display tunnel status and edit services on the fly  
- پشتیبان‌گیری خودکار از فایل‌ها و سرویس‌های مرتبط  
- Automatic backup of related files and services  
- انتقال آسان تنظیمات و فایل‌ها به سرورهای دیگر از طریق SSH  
- Easy transfer of settings and files to other servers via SSH  
- بررسی و نصب خودکار ابزارهای ضروری (ip, dig, zip)  
- Automatic check and install of required tools (ip, dig, zip)  

---

## 📋 پیش‌نیازها / Prerequisites

- سیستم عامل: توزیع‌های مبتنی بر لینوکس (اوبونتو، دبیان، سنت‌اواس و...)  
- Operating System: Linux distributions (Ubuntu, Debian, CentOS, etc.)  
- ابزارهای زیر باید نصب باشند / Required tools:
  - `ip` (بسته iproute2) / package iproute2  
  - `dig` (از بسته dnsutils) / from dnsutils package  
  - `zip` (برای پشتیبان‌گیری) / for backups  
- systemd برای مدیریت سرویس‌ها / systemd for service management

---

## 💡 نحوه استفاده / Usage

1. اسکریپت را روی سرور خود قرار دهید و دسترسی اجرایی بدهید:  
   Place the script on your server and make it executable:

    ```bash
    chmod +x vxlan_manager.sh
    ```

2. اسکریپت را اجرا کنید:  
   Run the script:

    ```bash
    sudo ./vxlan_manager.sh
    ```

3. از منوی اصلی گزینه مورد نظر خود را انتخاب کنید:  
   Choose your desired option from the main menu:

    - ایجاد تونل جدید / Create new tunnel  
    - مدیریت تونل‌های موجود / Manage existing tunnels  
    - شروع، توقف یا ری‌استارت تمام تونل‌ها / Start, stop, or restart all tunnels  
    - پشتیبان‌گیری و انتقال فایل‌ها / Backup and transfer files  

4. هنگام ایجاد تونل جدید، شناسه VNI، IP محلی و راه دور و آدرس IP تونل را وارد کنید یا از مقادیر پیش‌فرض استفاده کنید.  
   When creating a new tunnel, enter the VNI, local and remote IPs, and tunnel IP or use defaults.

---

## 🛠️ نکات مهم / Important Notes

- هنگام ایجاد تونل، شناسه VNI را روی هر دو سرور یکسان تنظیم کنید.  
- When creating a tunnel, set the same VNI on both servers.  
- IPهای تونل باید در محدوده‌های جداگانه و بدون تداخل باشند.  
- Tunnel IPs should be in separate, non-overlapping ranges.  
- اطمینان حاصل کنید که پورت UDP 4789 در فایروال باز باشد.  
- Ensure UDP port 4789 is open in the firewall.  
- سرویس‌های systemd به صورت خودکار فعال می‌شوند، اما می‌توانید آنها را با `systemctl` به صورت دستی مدیریت کنید.  
- systemd services auto-enable but can be manually managed with `systemctl`.  
- برای انتقال تنظیمات به سرور دیگر، از گزینه "Transfer Files" در منوی اسکریپت استفاده کنید.  
- Use the "Transfer Files" option in the script menu to transfer settings to another server.

---

## 🛡️ پشتیبانی و گزارش خطا / Support & Issues

در صورت وجود هرگونه مشکل یا پیشنهاد، لطفاً Issue باز کنید یا با ما تماس بگیرید.  
For issues or suggestions, please open an Issue or contact us.

---

## 📄 مجوز / License

این پروژه تحت مجوز MIT منتشر شده است.  
This project is licensed under the MIT License.

---

## 👤 نویسنده / Author

[نام شما یا تیم توسعه] / [Your Name or Team]  
ایمیل: [email@example.com]  
GitHub: [https://github.com/YourGitHubUsername](https://github.com/YourGitHubUsername)

---

## ⚡ تشکر از شما که از VXLAN Tunnel Manager استفاده می‌کنید!  
Thank you for using VXLAN Tunnel Manager!

