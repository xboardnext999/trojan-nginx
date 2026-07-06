[Unit]
Description=Daily Trojan-Go SNI certificate renewal check

[Timer]
OnCalendar=${RENEW_TIMER_CALENDAR}
RandomizedDelaySec=${RENEW_RANDOM_DELAY}
Persistent=true

[Install]
WantedBy=timers.target
