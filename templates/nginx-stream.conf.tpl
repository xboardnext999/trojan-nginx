# Managed by trojan-go-sni.

map $ssl_preread_server_name $backend_name {
${NGINX_STREAM_MAP_ENTRIES}
    default web_backend;
}

upstream trojan_backend {
    server 127.0.0.1:${TROJAN_PORT};
}

upstream web_backend {
    server 127.0.0.1:${WEB_PORT};
}

server {
    listen 443 reuseport;
${NGINX_STREAM_IPV6_LISTEN}
    proxy_pass $backend_name;
    ssl_preread on;
}
