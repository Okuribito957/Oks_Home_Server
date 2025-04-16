#!/bin/bash

# 配置参数
THRESHOLD=95                       # 报警阈值百分比
RESET_THRESHOLD=60                 # 重置阈值百分比
CHECK_INTERVAL=2                   # 连续检测次数（5分钟×2次=10分钟）
CPU_COUNTER_FILE="/tmp/cpu_counter"        # CPU计数器文件
MEM_COUNTER_FILE="/tmp/mem_counter"        # 内存计数器文件
CPU_ALERT_SENT_FILE="/tmp/cpu_alert_sent"  # CPU报警标记文件
MEM_ALERT_SENT_FILE="/tmp/mem_alert_sent"  # 内存报警标记文件
RECIPIENT="admin@example.com"       # 收件人邮箱
LOG_FILE="/var/log/system_monitor.log"  # 监控日志路径

# 获取CPU使用率（整数）
get_cpu_usage() {
  cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}' | cut -d. -f1)
  echo $cpu_usage
}

# 获取内存使用率（整数）
get_mem_usage() {
  mem_usage=$(free | grep Mem | awk '{printf "%.0f", ($3/$2)*100}')
  echo $mem_usage
}

# 发送邮件函数
send_alert() {
  local reason=$1
  echo -e "报警时间：$(date)\n报警原因：$reason\n当前CPU使用率：${cpu_usage}%\n当前内存使用率：${mem_usage}%" | \
  mail -s "[紧急] 系统资源警报" "$RECIPIENT"
  echo "$(date) - 已发送警报邮件：$reason" >> "$LOG_FILE"
}

# 主监控逻辑
cpu_usage=$(get_cpu_usage)
mem_usage=$(get_mem_usage)

# 读取计数器
cpu_counter=$(cat "$CPU_COUNTER_FILE" 2>/dev/null || echo 0)
mem_counter=$(cat "$MEM_COUNTER_FILE" 2>/dev/null || echo 0)

# 处理CPU监控
if [ ! -f "$CPU_ALERT_SENT_FILE" ]; then
  if [ $cpu_usage -ge $THRESHOLD ]; then
    ((cpu_counter++))
  elif [ $cpu_usage -le $RESET_THRESHOLD ]; then
    cpu_counter=0
  fi

  if [ $cpu_counter -ge $CHECK_INTERVAL ]; then
    send_alert "CPU使用率连续10分钟超过${THRESHOLD}%"
    touch "$CPU_ALERT_SENT_FILE"
    cpu_counter=0
  fi
else
  if [ $cpu_usage -le $RESET_THRESHOLD ]; then
    rm -f "$CPU_ALERT_SENT_FILE"
    cpu_counter=0
  fi
fi

# 处理内存监控
if [ ! -f "$MEM_ALERT_SENT_FILE" ]; then
  if [ $mem_usage -ge $THRESHOLD ]; then
    ((mem_counter++))
  elif [ $mem_usage -le $RESET_THRESHOLD ]; then
    mem_counter=0
  fi

  if [ $mem_counter -ge $CHECK_INTERVAL ]; then
    send_alert "内存使用率连续10分钟超过${THRESHOLD}%"
    touch "$MEM_ALERT_SENT_FILE"
    mem_counter=0
  fi
else
  if [ $mem_usage -le $RESET_THRESHOLD ]; then
    rm -f "$MEM_ALERT_SENT_FILE"
    mem_counter=0
  fi
fi

# 保存计数器状态
echo $cpu_counter > "$CPU_COUNTER_FILE"
echo $mem_counter > "$MEM_COUNTER_FILE"

# 记录日志
log_entry="$(date) - CPU: ${cpu_usage}% [状态: "
log_entry+=$( [ -f "$CPU_ALERT_SENT_FILE" ] && echo "已报警" || echo "正常" )
log_entry+="], 内存: ${mem_usage}% [状态: "
log_entry+=$( [ -f "$MEM_ALERT_SENT_FILE" ] && echo "已报警" || echo "正常" )
log_entry+="]"
echo "$log_entry" >> "$LOG_FILE"