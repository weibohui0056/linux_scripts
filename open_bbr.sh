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




root@ImmortalWrt:/etc/sing-box# cat ddns.sh
#!/bin/sh                                                                   
# =========================                                                 # 配置区域
# =========================
API_TOKEN="s7dOVEIKpKZzbUyJEumHPmCcF5yZMAFECOBHnu8y"
DOMAIN="ipv6.fast790101.eu.org"   # 要更新的完整域名
BASE_DOMAIN="fast790101.eu.org" # 根域名
IP_TYPE="AAAA"                # 'A' = IPv4, 'AAAA' = IPv6
                                                                            # =========================
# 获取公网 IP
# =========================
if [ "$IP_TYPE" = "A" ]; then                                                   PUBLIC_IP=$(curl -s https://4.ipw.cn)                                   else
    PUBLIC_IP=$(curl -s https://6.ipw.cn)
fi

if [ -z "$PUBLIC_IP" ]; then                                                    echo "获取公网 IP 失败"
    exit 1
fi                                                                          
echo "获取公网 IP: $PUBLIC_IP"
                                                                            # =========================                                                 # 获取 Zone ID
# =========================
ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${BASE_DOMAIN}" \
    -H "Authorization: Bearer ${API_TOKEN}" \
    -H "Content-Type: application/json" \                                       | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$ZONE_ID" ]; then
    echo "获取 Zone ID 失败"                                                    exit 1                                                                  fi
                                                                            # =========================                                                 # 获取 DNS 记录 ID
# =========================                                                 RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=${IP_TYPE}&name=${DOMAIN}" \
    -H "Authorization: Bearer ${API_TOKEN}" \                                   -H "Content-Type: application/json" \                                       | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
                                                                            if [ -z "$RECORD_ID" ]; then
    echo "未找到 DNS 记录，请先在 Cloudflare 添加 $DOMAIN"
    exit 1                                                                  fi

# =========================                                                 # 更新 DNS 记录
# =========================
UPDATED_IP=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD_ID}" \                                              -H "Authorization: Bearer ${API_TOKEN}" \
    -H "Content-Type: application/json" \                                       --data '{"type":"'"$IP_TYPE"'","name":"'"$DOMAIN"'","content":"'"$PUBLIC_IP"'","ttl":60,"proxied":false}' \
    | grep -o '"content":"[^"]*"' | cut -d'"' -f4)                          
echo "更新后 IP: $UPDATED_IP"                                               root@ImmortalWrt:/etc/sing-box#