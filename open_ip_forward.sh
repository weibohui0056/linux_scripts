#!/bin/bash

# 开启 IPv4 转发
if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
fi

# 如需开启 IPv6 转发，取消下面两行的注释
# if ! grep -q "net.ipv6.conf.all.forwarding=1" /etc/sysctl.conf; then
#     echo "net.ipv6.conf.all.forwarding=1" | sudo tee -a /etc/sysctl.conf
# fi

# 应用配置
sudo sysctl -p

# 输出当前 IPv4 转发状态
FORWARD_STATUS=$(sysctl -n net.ipv4.ip_forward)
echo "IPv4 转发状态: $FORWARD_STATUS "
