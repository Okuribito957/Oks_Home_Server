#!/bin/bash

# --------------------------
# 配置
# --------------------------

# 要备份的目录路径
SOURCE_DIR="/path/to/your/source/directory"  # 替换为需要备份的目录

# SMB 共享配置
SMB_SERVER="192.168.1.100"     # NAS 的 IP 地址
SMB_SHARE="backup_share"        # SMB 共享名称
SMB_USER="username"             # SMB 用户名
SMB_PASSWORD="password"         # SMB 密码
MOUNT_DIR="/mnt/smb_backup"     # 本地挂载 SMB 的目录

# 备份文件命名规则（保留最近4周备份）
BACKUP_NAME="ubuntu_XXX_backup_$(date +%Y%m%d_%H%M%S).tar.gz"  # 带时间戳的备份文件名
RETENTION_DAYS=28               # 保留最近28天（4周）的备份

# 日志文件路径
LOG_FILE="/var/log/backup_nas.log"

# --------------------------
# 处理
# --------------------------

# 创建日志目录（如果不存在）
mkdir -p "$(dirname "$LOG_FILE")"

# function：记录日志
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# function：错误处理
error_exit() {
  log "ERROR: $1"
  umount -f "$MOUNT_DIR" 2>/dev/null  # 尝试强制卸载
  exit 1
}

# step1：挂载 SMB 共享
log "开始挂载 SMB 共享..."
mount -t cifs "//${SMB_SERVER}/${SMB_SHARE}" "$MOUNT_DIR" -o username="$SMB_USER",password="$SMB_PASSWORD",vers=3.0 || error_exit "SMB 挂载失败"

# step2：打包目录为 tar.gz
log "正在打包目录: $SOURCE_DIR..."
tar -czf "${MOUNT_DIR}/${BACKUP_NAME}" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")" --exclude="*.log" --exclude="*.tmp" || error_exit "打包失败"

# step3：验证备份文件
if [ -f "${MOUNT_DIR}/${BACKUP_NAME}" ]; then
  log "备份成功: ${BACKUP_NAME} (大小: $(du -h "${MOUNT_DIR}/${BACKUP_NAME}" | cut -f1))"
  log "MD5校验: $(md5sum "${MOUNT_DIR}/${BACKUP_NAME}" | cut -d' ' -f1)"
else
  error_exit "备份文件未生成"
fi

# step4：清理旧备份
log "清理超过 ${RETENTION_DAYS} 天的旧备份..."
find "$MOUNT_DIR" -name "backup_*.tar.gz" -mtime +$RETENTION_DAYS -delete >> "$LOG_FILE" 2>&1

# step5：卸载 SMB 共享
umount "$MOUNT_DIR" && log "已卸载 SMB 共享"

log "备份流程完成"