#!/bin/bash
set -e

green(){ echo -e "\033[32m$1\033[0m"; }
red(){ echo -e "\033[31m$1\033[0m"; }

if [ "$EUID" -ne 0 ]; then
  red "请使用 root 执行"
  exit 1
fi

read -rp "请输入 Trojan 域名，例如 t.example.com: " TROJAN_DOMAIN
read -rp "请输入伪装网站域名，例如 www.example.com: " WEB_DOMAIN
read -rp "请输入 Trojan 内部端口，默认 8080: " TROJAN_PORT
TROJAN_PORT=${TROJAN_PORT:-8080}
read -rp "请输入 Trojan 密码，留空自动生成: " TROJAN_PASS
TROJAN_PASS=${TROJAN_PASS:-$(openssl rand -hex 16)}

WEB_PORT=8443

green "安装依赖..."
apt update
apt install -y nginx libnginx-mod-stream certbot unzip curl wget openssl

green "创建伪装网站..."
mkdir -p /var/www/fake-site
cat > /var/www/fake-site/index.html <<HTML
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Welcome</title>
  <style>
    body{font-family:Arial;background:#f7f7f7;color:#333;text-align:center;padding-top:120px}
    .box{background:white;display:inline-block;padding:40px 60px;border-radius:16px;box-shadow:0 10px 30px #ddd}
  </style>
</head>
<body>
  <div class="box">
    <h1>Welcome</h1>
    <p>This website is running normally.</p>
  </div>
</body>
</html>
HTML

green "申请证书..."
systemctl stop nginx || true

certbot certonly --standalone --agree-tos --register-unsafely-without-email -d "$TROJAN_DOMAIN"
certbot certonly --standalone --agree-tos --register-unsafely-without-email -d "$WEB_DOMAIN"

green "安装 Trojan-Go..."
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"
ARCH=$(uname -m)

if [[ "$ARCH" == "x86_64" ]]; then
  TROJAN_ZIP="trojan-go-linux-amd64.zip"
elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
  TROJAN_ZIP="trojan-go-linux-armv8.zip"
else
  red "不支持的架构: $ARCH"
  exit 1
fi

wget -O trojan-go.zip "https://github.com/p4gefau1t/trojan-go/releases/latest/download/$TROJAN_ZIP"
unzip -o trojan-go.zip
install -m 755 trojan-go /usr/local/bin/trojan-go

green "生成 Trojan-Go 配置..."
mkdir -p /etc/trojan-go
cat > /etc/trojan-go/config.json <<JSON
{
  "run_type": "server",
  "local_addr": "127.0.0.1",
  "local_port": $TROJAN_PORT,
  "remote_addr": "127.0.0.1",
  "remote_port": 80,
  "password": [
    "$TROJAN_PASS"
  ],
  "ssl": {
    "cert": "/etc/letsencrypt/live/$TROJAN_DOMAIN/fullchain.pem",
    "key": "/etc/letsencrypt/live/$TROJAN_DOMAIN/privkey.pem",
    "sni": "$TROJAN_DOMAIN",
    "alpn": [
      "http/1.1"
    ]
  }
}
JSON

cat > /etc/systemd/system/trojan-go.service <<SERVICE
[Unit]
Description=Trojan-Go Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/trojan-go -config /etc/trojan-go/config.json
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
SERVICE

green "配置 Nginx HTTP 网站..."
cat > /etc/nginx/conf.d/fake-site.conf <<NGINX
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    root /var/www/fake-site;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }
}

server {
    listen 127.0.0.1:$WEB_PORT ssl http2;
    server_name $WEB_DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$WEB_DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$WEB_DOMAIN/privkey.pem;

    root /var/www/fake-site;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
NGINX

green "配置 Nginx Stream SNI 分流..."
mkdir -p /etc/nginx/stream-conf.d

cat > /etc/nginx/stream-conf.d/sni.conf <<NGINX
map \$ssl_preread_server_name \$backend_name {
    $TROJAN_DOMAIN trojan_backend;
    $WEB_DOMAIN web_backend;
    default web_backend;
}

upstream trojan_backend {
    server 127.0.0.1:$TROJAN_PORT;
}

upstream web_backend {
    server 127.0.0.1:$WEB_PORT;
}

server {
    listen 443 reuseport;
    listen [::]:443 reuseport;
    proxy_pass \$backend_name;
    ssl_preread on;
}
NGINX

if ! grep -q "stream-conf.d" /etc/nginx/nginx.conf; then
cat >> /etc/nginx/nginx.conf <<'NGINX'

stream {
    include /etc/nginx/stream-conf.d/*.conf;
}
NGINX
fi

green "启动服务..."
systemctl daemon-reload
systemctl enable trojan-go nginx
systemctl restart trojan-go
nginx -t
systemctl restart nginx

green "部署完成！"
echo
echo "Trojan 域名: $TROJAN_DOMAIN"
echo "Trojan 端口: 443"
echo "Trojan 密码: $TROJAN_PASS"
echo "SNI: $TROJAN_DOMAIN"
echo "伪装站: https://$WEB_DOMAIN"
echo
echo "客户端配置："
echo "地址: $TROJAN_DOMAIN"
echo "端口: 443"
echo "密码: $TROJAN_PASS"
echo "传输: TCP"
echo "TLS: 开启"
echo "SNI: $TROJAN_DOMAIN"
