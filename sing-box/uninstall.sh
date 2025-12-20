#!/bin/bash

# 清理安装
rm -rf sing-box-1.12.0-linux-amd64
rm -f sing-box-1.12.0-linux-amd64.tar.gz
rm -f /usr/local/bin/sing-box
rm -rf /etc/sing-box
sudo crontab -l | grep -v 'sing-box' | sudo crontab -
pkill sing-box