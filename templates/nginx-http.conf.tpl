# Managed by trojan-go-sni.

server {
    listen 80 default_server;
${NGINX_HTTP_IPV6_LISTEN}
    server_name _;

    return 301 https://$host$request_uri;
}

server {
    listen 127.0.0.1:${WEB_PORT} ssl http2;
    server_name ${WEB_DOMAIN};

    ssl_certificate ${WEB_CERT_FULLCHAIN};
    ssl_certificate_key ${WEB_CERT_PRIVKEY};
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_session_cache shared:trojan_go_sni_site:10m;
    ssl_session_timeout 10m;

    root ${WEB_ROOT};
    index index.html;

    access_log /var/log/nginx/trojan-go-sni-site-access.log;
    error_log /var/log/nginx/trojan-go-sni-site-error.log warn;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
