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

# 生成服务端配置文件
mkdir /etc/sing-box
## uuid
read -p "UUID:" uuid
if ! [[ "$uuid" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$ ]]; then
    uuid=$(/usr/local/bin/sing-box generate uuid)
    echo "UUID(自动生成):$uuid"
fi
## port
read -p "VLESS_WS_CF_PORT:" vless_ws_cf_port
if ! ([[ "$vless_ws_cf_port" =~ ^[0-9]+$ ]] && [ "$vless_ws_cf_port" -ge 0 ] && [ "$vless_ws_cf_port" -le 65535 ]); then
    vless_ws_cf_port=$((60000 + $(od -An -N2 -i /dev/urandom) % 5536))
    echo "VLESS_WS_CF_PORT(自动生成):$vless_ws_cf_port"
fi
read -p "VLESS_REALITY_PORT:" vless_reality_port
if ! ([[ "$vless_reality_port" =~ ^[0-9]+$ ]] && [ "$vless_reality_port" -ge 0 ] && [ "$vless_reality_port" -le 65535 ]); then
    vless_reality_port=$((50000 + $(od -An -N2 -i /dev/urandom) % 9999))
    echo "VLESS_REALITY_PORT(自动生成):$vless_reality_port"
fi
## key
key=$(/usr/local/bin/sing-box generate reality-keypair)
private_key=$(echo "$key" | grep "PrivateKey:" | awk '{print $2}')
public_key=$(echo "$key" | grep "PublicKey:" | awk '{print $2}')
cat > /etc/sing-box/server_vless_ws_cf_and_reality.json <<EOF
{
    "inbounds": [
        {
            "type": "vless",
            "listen": "::",
            "listen_port": $vless_ws_cf_port,
            "users": [
              {
                "uuid": "$uuid"
              }
            ],
            "transport": {
              "type": "ws",
              "path": "/$uuid"
            }
        },
        {
            "type": "vless",
            "listen": "::",
            "listen_port": $port,
            "users": [
              {
                "uuid": "$uuid",
                "flow": "xtls-rprx-vision"
                }
              ],
            "tls": {
                "enabled": true,
                "server_name": "www.amazon.com",
                "reality": {
                    "enabled": true,
                    "handshake": {
                        "server": "www.amazon.com",
                        "server_port": 443
                    },
                "private_key": "$private_key",
                "short_id": ""
                }
            }
        }
    ]
}
EOF

# 启动 sing-box
/usr/local/bin/sing-box -c /etc/sing-box/server_vless_ws_cf_and_reality.json run > /dev/null 2>&1 &

# 生成保活脚本
cat > /etc/sing-box/keep.sh <<'EOF'
#!/bin/bash

# 守护进程名和启动命令
progress1="sing-box"
cmd1="/usr/local/bin/sing-box -c /etc/sing-box/server_vless_ws_cf_and_reality.json run"


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
read -p "CF解析域名:" domain
read -p "IP:" ip
read -p "地区:" region
cat <<EOF
    {
     "type": "vless",
     "tag": "CF-VL-$region",
     "server": "$domain",
     "server_port": 443,
     "uuid": "$uuid",
     "tls": {
       "enabled": true,
       "server_name": "$domain",
       },
     "transport": {
        "type": "ws",
        "path": "/$uuid",
        "headers": {"Host": "$domain"},
        "early_data_header_name": "Sec-WebSocket-Protocol",
        "max_early_data": 0
        }
    },
    {
     "type": "vless",
     "tag": "VL-REALITY-$region",
     "server": "$ip",
     "server_port": $vless_reality_port,
     "uuid": "$uuid",
     "flow": "xtls-rprx-vision",
     "tls": {
       "enabled": true,
       "server_name": "www.amazon.com",
       "reality": {
         "enabled": true,
         "public_key": "$public_key",
         "short_id": ""
       },
       "utls": {
          "enabled": true,
          "fingerprint": "chrome"
        }
      }
    }
EOF