{
  "run_type": "server",
  "local_addr": "127.0.0.1",
  "local_port": ${TROJAN_PORT},
  "remote_addr": "${TROJAN_REMOTE_ADDR}",
  "remote_port": ${TROJAN_REMOTE_PORT},
  "password": [
    "${TROJAN_PASSWORD}"
  ],
  "ssl": {
    "cert": "${TROJAN_CERT_FULLCHAIN}",
    "key": "${TROJAN_CERT_PRIVKEY}",
    "sni": "${TROJAN_DOMAIN}",
    "alpn": [
      "http/1.1"
    ]
  }
}
