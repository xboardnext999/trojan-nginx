#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/backup.sh
source "${SCRIPT_DIR}/lib/backup.sh"
# shellcheck source=lib/nginx.sh
source "${SCRIPT_DIR}/lib/nginx.sh"

PURGE="0"

rollback_on_error() {
  restore_backup
  systemctl daemon-reload >/dev/null 2>&1 || true
  systemctl restart nginx >/dev/null 2>&1 || true
}

usage() {
  cat <<USAGE
Usage: sudo bash uninstall.sh [--yes] [--purge]

Options:
  --yes     Skip confirmation prompt.
  --purge   Remove runtime config, web root, logs and Trojan-Go binary.
USAGE
}

parse_args() {
  while (($#)); do
    case "$1" in
      --yes|-y)
        ASSUME_YES="1"
        ;;
      --purge)
        PURGE="1"
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        die "未知参数: $1"
        ;;
    esac
    shift
  done
}

confirm_uninstall() {
  if [[ "${ASSUME_YES}" == "1" ]]; then
    return 0
  fi

  local answer
  read -r -p "确认卸载 ${PROJECT_DISPLAY_NAME}? [y/N]: " answer
  case "${answer}" in
    y|Y|yes|YES)
      ;;
    *)
      die "已取消卸载"
      ;;
  esac
}

backup_uninstall_targets() {
  create_backup
  backup_path "${NGINX_HTTP_CONF}"
  backup_path "${NGINX_STREAM_CONF}"
  backup_path "${TROJAN_CONFIG_DIR}"
  backup_path "${TROJAN_SERVICE_FILE}"
  backup_path "${RENEW_SERVICE_FILE}"
  backup_path "${RENEW_TIMER_FILE}"
  backup_path "${LOGROTATE_FILE}"
  backup_path "${RUNTIME_DIR}"
  backup_path "${INSTALL_ROOT}"
  backup_path "${WEB_ROOT}"
  backup_path "${LOG_DIR}"
  backup_path "${TROJAN_BIN}"
}

remove_path() {
  local target="$1"
  if [[ -e "${target}" || -L "${target}" ]]; then
    rm -rf -- "${target}"
  fi
}

main() {
  require_bash_5
  require_root
  parse_args "$@"
  load_config
  init_logging "uninstall"
  trap 'error_exit "$LINENO" "$BASH_COMMAND"' ERR

  print_banner "Trojan-Go SNI 卸载器"
  confirm_uninstall
  backup_uninstall_targets

  print_step "停止并禁用服务"
  stop_service_if_exists "trojan-go-sni-renew.timer"
  stop_service_if_exists "trojan-go"
  disable_service_if_exists "trojan-go-sni-renew.timer"
  disable_service_if_exists "trojan-go"
  print_success "服务已停止"

  print_step "移除托管配置"
  remove_path "${NGINX_HTTP_CONF}"
  remove_path "${NGINX_STREAM_CONF}"
  remove_path "${TROJAN_CONFIG_DIR}"
  remove_path "${TROJAN_SERVICE_FILE}"
  remove_path "${RENEW_SERVICE_FILE}"
  remove_path "${RENEW_TIMER_FILE}"
  remove_path "${LOGROTATE_FILE}"

  if [[ "${PURGE}" == "1" ]]; then
    remove_path "${RUNTIME_DIR}"
    remove_path "${INSTALL_ROOT}"
    remove_path "${WEB_ROOT}"
    remove_path "${LOG_DIR}"
    remove_path "${TROJAN_BIN}"
  fi

  systemctl daemon-reload
  if command_exists nginx; then
    nginx -t
    systemctl restart nginx || true
  fi
  print_success "托管配置已移除"

  trap - ERR
  print_success "卸载完成，备份目录: ${BACKUP_DIR}"
}

main "$@"
