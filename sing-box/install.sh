#!/bin/bash

# 清理之前安装
rm -rf sing-box-1.12.0-linux-amd64
rm -f sing-box-1.12.0-linux-amd64.tar.gz
rm -f /usr/local/bin/sing-box
rm -rf /etc/sing-box
sudo crontab -l | grep -v 'sing-box' | sudo crontab -
pkill sing-box

# 下载 sing-box
wget https://github.com/SagerNet/sing-box/releases/download/v1.12.0/sing-box-1.12.0-linux-amd64.tar.gz
tar -zxvf sing-box-1.12.0-linux-amd64.tar.gz
mv sing-box-1.12.0-linux-amd64/sing-box /usr/local/bin
chmod +x /usr/local/bin/sing-box
rm -rf sing-box-1.12.0-linux-amd64
rm -f sing-box-1.12.0-linux-amd64.tar.gz

# 生成保活脚本
cat > /etc/sing-box/keep.sh <<'EOF'
#!/bin/bash

# 守护进程名和启动命令
progress1="sing-box"
cmd1="/usr/local/bin/sing-box -c /etc/sing-box/server.json run"


# 定义编号列表
progress_list="1"

# 检测所有进程,保存状态变量
for i in $progress_list; do
    eval "progress=\$progress$i"
    eval "cmd=\$cmd$i"

    if pgrep "$progress" > /dev/null 2>&1; then
        echo "$progress is running"
        eval "progress_status$i=0"
    else
        echo "$progress is not running"
        eval "progress_status$i=1"
    fi
done

# 根据状态变量启动未运行的进程
for i in $progress_list; do
    eval "status=\$progress_status$i"
    eval "cmd=\$cmd$i"
    eval "progress=\$progress$i"

    if [ "$status" = 1 ]; then
        echo "starting $progress"
        $cmd > /dev/null 2>&1 &

        # 启动后检测进程是否启动成功
        sleep 1  # 等待进程启动,视情况调整秒数
        if pgrep "$progress" > /dev/null 2>&1; then
            echo "$progress is running"
        else
            echo "failed to start $progress"
        fi
    fi
done
EOF
chmod +x /etc/sing-box/keep.sh

# 添加计划任务
(sudo crontab -l 2>/dev/null; echo "@reboot /etc/sing-box/keep.sh") | sudo crontab -
(sudo crontab -l 2>/dev/null; echo "0 * * * * /etc/sing-box/keep.sh") | sudo crontab -