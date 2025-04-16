# 1_sysmon.sh
- 监控系统占用，当CPU或Memory持续十分钟超过设定阈值时发送邮件

1. 安装邮件工具:
    ```
    sudo apt update && sudo apt install -y mailutils
    ```
2. 编辑邮件配置（选择Internet Site并根据提示配置）：
    ```
    sudo dpkg-reconfigure postfix
    ```
3. 创建日志文件并设置权限：
    ```
    sudo touch /var/log/system_monitor.log
    sudo chmod 644 /var/log/system_monitor.log
    ```
4. 设置cron定时任务：
    ```
    crontab -e
    ```
6. 添加以下内容：
    ```
    */5 * * * * /bin/bash /path/to/your_script.sh
    ```


# 2_back_up_to_nas.sh
- 定时备份系统快照至nas