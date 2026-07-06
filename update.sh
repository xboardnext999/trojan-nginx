#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/backup.sh
source "${SCRIPT_DIR}/lib/backup.sh"
# shellcheck source=lib/system.sh
source "${SCRIPT_DIR}/lib/system.sh"
# shellcheck source=lib/trojan.sh
source "${SCRIPT_DIR}/lib/trojan.sh"

rollback_on_error() {
  restore_backup
  systemctl daemon-reload >/dev/null 2>&1 || true
  systemctl restart trojan-go >/dev/null 2>&1 || true
}

main() {
  require_bash_5
  require_root
  load_config
  init_logging "update"
  trap 'error_exit "$LINENO" "$BASH_COMMAND"' ERR

  print_banner "Trojan-Go 升级器"
  require_runtime_config
  detect_os
  detect_arch
  install_update_dependencies
  create_backup
  backup_path "${TROJAN_BIN}"

  local before_version
  before_version=$(trojan_go_version)
  print_info "当前版本: ${before_version}"

  install_trojan_go_latest
  systemctl restart trojan-go
  assert_service_active "trojan-go"

  local after_version
  after_version=$(trojan_go_version)
  print_success "升级完成: ${before_version} -> ${after_version}"

  trap - ERR
}

main "$@"
