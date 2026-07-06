#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/backup.sh
source "${SCRIPT_DIR}/lib/backup.sh"
# shellcheck source=lib/system.sh
source "${SCRIPT_DIR}/lib/system.sh"
# shellcheck source=lib/certbot.sh
source "${SCRIPT_DIR}/lib/certbot.sh"

rollback_on_error() {
  restore_backup
  systemctl daemon-reload >/dev/null 2>&1 || true
  systemctl restart nginx >/dev/null 2>&1 || true
  systemctl restart trojan-go >/dev/null 2>&1 || true
}

backup_certificate_paths() {
  local domain
  while IFS= read -r domain; do
    [[ -n "${domain}" ]] || continue
    backup_path "/etc/letsencrypt/live/${domain}"
    backup_path "/etc/letsencrypt/archive/${domain}"
    backup_path "/etc/letsencrypt/renewal/${domain}.conf"
  done < <(unique_domains)
}

main() {
  require_bash_5
  require_root
  load_config
  init_logging "renew"
  trap 'error_exit "$LINENO" "$BASH_COMMAND"' ERR

  print_banner "Let's Encrypt 证书续期"
  require_runtime_config
  create_backup
  backup_certificate_paths
  check_domain_resolution

  print_step "停止 Nginx 释放 HTTP-01 端口"
  stop_service_if_exists "nginx"
  assert_port_free "80"
  print_success "HTTP-01 端口已释放"

  obtain_certificates

  print_step "重载服务"
  nginx -t
  systemctl restart nginx
  systemctl restart trojan-go
  assert_service_active "nginx"
  assert_service_active "trojan-go"
  print_success "证书续期流程完成"

  trap - ERR
}

main "$@"
