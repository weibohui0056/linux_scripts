#!/bin/bash

# 检查内核版本
KERNEL=$(uname -r | awk -F- '{print $1}')
KERNEL_MAJOR=$(echo $KERNEL | cut -d. -f1)
KERNEL_MINOR=$(echo $KERNEL | cut -d. -f2)

if [ "$KERNEL_MAJOR" -lt 4 ] || { [ "$KERNEL_MAJOR" -eq 4 ] && [ "$KERNEL_MINOR" -lt 9 ]; }; then
    echo "请升级系统"
    exit 1
fi

# 开启 BBR
if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
    echo "net.core.default_qdisc=fq" | sudo tee -a /etc/sysctl.conf
fi

if ! grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf; then
    echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee -a /etc/sysctl.conf
fi

sudo sysctl -p

# 输出当前TCP拥塞控制算法
TCP_CONTROL=$(sysctl -n net.ipv4.tcp_congestion_control)
echo "当前TCP拥塞控制算法: $TCP_CONTROL"