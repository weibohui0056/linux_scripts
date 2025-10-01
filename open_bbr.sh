#!/bin/sh

# 检查内核版本
KERNEL=$(uname -r | awk -F- '{print $1}')
KERNEL_MAJOR=$(echo $KERNEL | cut -d. -f1)
KERNEL_MINOR=$(echo $KERNEL | cut -d. -f2)

if [ "$KERNEL_MAJOR" -lt 4 ] || { [ "$KERNEL_MAJOR" -eq 4 ] && [ "$KERNEL_MINOR" -lt 9 ]; }; then
    echo "内核版本过低，BBR 需要 >= 4.9 内核。当前内核：$KERNEL"
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

# 输出当前 TCP 拥塞控制算法
sysctl -n net.ipv4.tcp_congestion_control