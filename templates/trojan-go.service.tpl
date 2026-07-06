[Unit]
Description=Trojan-Go Server
Documentation=https://github.com/p4gefau1t/trojan-go
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${TROJAN_BIN} -config ${TROJAN_CONFIG_FILE}
Restart=on-failure
RestartSec=3
LimitNOFILE=1048576
StandardOutput=append:${LOG_DIR}/trojan-go.log
StandardError=append:${LOG_DIR}/trojan-go-error.log

[Install]
WantedBy=multi-user.target
