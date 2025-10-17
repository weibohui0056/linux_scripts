#!/bin/bash

# 清理之前安装
rm -rf sing-box-1.12.0-linux-amd64
rm -f sing-box-1.12.0-linux-amd64.tar.gz
rm -f /usr/local/bin/sing-box
rm -rf /etc/sing-box
sudo crontab -l | grep -v 'sing-box' | sudo crontab -
pkill sing-box

# 下载 sing-box
wget https://v6.gh-proxy.com/https://github.com/SagerNet/sing-box/releases/download/v1.12.0/sing-box-1.12.0-linux-amd64.tar.gz
tar -zxvf sing-box-1.12.0-linux-amd64.tar.gz
mv sing-box-1.12.0-linux-amd64/sing-box /usr/local/bin
chmod +x /usr/local/bin/sing-box
rm -rf sing-box-1.12.0-linux-amd64
rm -f sing-box-1.12.0-linux-amd64.tar.gz

# 生成服务端配置文件
mkdir /etc/sing-box
## UUID
read -p "UUID:" UUID
if ! [[ "$UUID" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$ ]]; then
    UUID=$(/usr/local/bin/sing-box generate uuid)
    echo "UUID(自动生成):$UUID"
fi
## PORT
read -p "PORT:" PORT
if ! ([[ "$PORT" =~ ^[0-9]+$ ]] && [ "$PORT" -ge 0 ] && [ "$PORT" -le 65535 ]); then
    PORT=$((60000 + $(od -An -N2 -i /dev/urandom) % 5536))
    echo "PORT(自动生成):$PORT"
fi
cat > /etc/sing-box/server_vless_ws_warp_cf.json <<EOF
{
    "inbounds": [
        {
            "type": "vless",
            "listen": "::",
            "listen_port": $PORT,
            "users": [
              {
                "uuid": "$UUID"
                }
              ],
            "transport": {
              "type": "ws",
              "path": "/$UUID"
            }
        }
    ],
    "endpoints": [
        {
            "type": "wireguard",
            "tag": "warp",
            "mtu": 1280,
            "address": "172.16.0.2/32",
            "private_key": "uJaFlAvGYFdpE1Y/Iyvd1Ct3rSVvfR+rFCxwWE88D08=",
            "peers": [
               {
                 "address": "engage.cloudflareclient.com",
                 "port": 2408,
                 "public_key": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
                 "allowed_ips": "0.0.0.0/0"
               }
            ]
        }
    ],
    "route": {
       "final": "warp"
    }
}
EOF

# 启动 sing-box
/usr/local/bin/sing-box -c /etc/sing-box/server_vless_ws_warp_cf.json run > /dev/null 2>&1 &

# 生成保活脚本
cat > /etc/sing-box/keep.sh <<'EOF'
#!/bin/bash

# 守护进程名和启动命令
progress1="sing-box"
cmd1="/usr/local/bin/sing-box -c /etc/sing-box/server_vless_ws_warp_cf.json run"


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

# 生成客户端出站配置
read -p "CF解析域名:" DOMAIN
read -p "节点地区:" REGION
cat <<EOF
    {
     "type": "vless",
     "tag": "CF-VL-$REGION",
     "server": "$DOMAIN",
     "server_port": 443,
     "uuid": "$UUID",
     "tls": {
       "enabled": true,
       "server_name": "$DOMAIN",
       },
     "transport": {
        "type": "ws",
        "path": "/$UUID",
        "headers": {"Host": "$DOMAIN"},
        "early_data_header_name": "Sec-WebSocket-Protocol",
        "max_early_data": 0
        }
    }
EOF