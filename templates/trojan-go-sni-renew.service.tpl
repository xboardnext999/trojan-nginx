[Unit]
Description=Renew Trojan-Go SNI Let's Encrypt certificates
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/env bash ${INSTALL_ROOT}/renew.sh
