#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/backup.sh
source "${SCRIPT_DIR}/lib/backup.sh"
# shellcheck source=lib/system.sh
source "${SCRIPT_DIR}/lib/system.sh"
# shellcheck source=lib/templates.sh
source "${SCRIPT_DIR}/lib/templates.sh"
# shellcheck source=lib/certbot.sh
source "${SCRIPT_DIR}/lib/certbot.sh"
# shellcheck source=lib/nginx.sh
source "${SCRIPT_DIR}/lib/nginx.sh"
# shellcheck source=lib/trojan.sh
source "${SCRIPT_DIR}/lib/trojan.sh"

rollback_on_error() {
  restore_backup
  systemctl daemon-reload >/dev/null 2>&1 || true
  systemctl restart nginx >/dev/null 2>&1 || true
  systemctl restart trojan-go >/dev/null 2>&1 || true
}

prompt_install_config() {
  print_step "读取安装参数"

  prompt_required TROJAN_DOMAIN "请输入 Trojan 域名"
  validate_domain_or_die "${TROJAN_DOMAIN}" "Trojan 域名"

  prompt_with_default TROJAN_PORT "请输入 Trojan 后端监听端口" "${TROJAN_PORT:-8080}"
  validate_port_or_die "${TROJAN_PORT}" "Trojan 后端监听端口"

  prompt_secret_or_generate TROJAN_PASSWORD "请输入 Trojan 密码，留空自动生成"
  validate_password_or_die "${TROJAN_PASSWORD}"

  prompt_with_default WEB_DOMAIN "请输入伪装网站域名" "${WEB_DOMAIN:-${TROJAN_DOMAIN}}"
  validate_domain_or_die "${WEB_DOMAIN}" "伪装网站域名"

  prompt_yes_no ENABLE_IPV6 "是否开启 IPv6" "${ENABLE_IPV6:-N}"
  ENABLE_IPV6=$(normalize_yes_no "${ENABLE_IPV6}")

  derive_config
  if [[ "${SAME_DOMAIN_MODE}" == "1" ]]; then
    print_info "已启用同域模式: Trojan 和伪装网站共用 ${TROJAN_DOMAIN}"
  else
    print_info "已启用双域 SNI 分流模式"
  fi
  print_success "安装参数已确认"
}

persist_and_install_project() {
  print_step "写入运行配置和安装项目文件"
  local project_real
  local install_real

  install -d -m 700 "${RUNTIME_DIR}"
  write_runtime_config "${RUNTIME_CONFIG_FILE}"

  install -d -m 755 "${INSTALL_ROOT}"
  project_real=$(cd -- "${PROJECT_DIR}" && pwd -P)
  install_real=$(cd -- "${INSTALL_ROOT}" && pwd -P)

  if [[ "${project_real}" == "${install_real}" ]]; then
    print_info "项目已位于安装目录，跳过项目文件复制"
  else
    find "${INSTALL_ROOT}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
    find "${PROJECT_DIR}" -mindepth 1 -maxdepth 1 \
      ! -name ".git" \
      ! -name ".DS_Store" \
      -exec cp -a {} "${INSTALL_ROOT}/" \;
  fi

  chmod 600 "${RUNTIME_CONFIG_FILE}"
  chmod +x "${INSTALL_ROOT}/install.sh" "${INSTALL_ROOT}/uninstall.sh" \
    "${INSTALL_ROOT}/update.sh" "${INSTALL_ROOT}/renew.sh"
  print_success "运行配置和项目文件已写入"
}

prepare_managed_paths() {
  print_step "准备目录和备份"
  create_backup
  backup_path "${RUNTIME_DIR}"
  backup_path "${INSTALL_ROOT}"
  backup_path "${TROJAN_CONFIG_DIR}"
  backup_path "${TROJAN_SERVICE_FILE}"
  backup_path "${RENEW_SERVICE_FILE}"
  backup_path "${RENEW_TIMER_FILE}"
  backup_path "${LOGROTATE_FILE}"
  backup_path "${WEB_ROOT}"
  backup_path "${NGINX_HTTP_CONF}"
  backup_path "${NGINX_STREAM_CONF}"
  backup_path "${NGINX_MAIN_CONF}"
  backup_path "/etc/nginx/sites-enabled/default"
  backup_path "/etc/nginx/conf.d/default.conf"
  backup_path "${TROJAN_BIN}"

  install -d -m 755 "${TROJAN_CONFIG_DIR}"
  install -d -m 755 "${WEB_ROOT}"
  install -d -m 755 "${NGINX_STREAM_CONF_DIR}"
  install -d -m 750 "${LOG_DIR}"
  print_success "备份已创建: ${BACKUP_DIR}"
}

main() {
  require_bash_5
  require_root
  load_config
  init_logging "install"
  trap 'error_exit "$LINENO" "$BASH_COMMAND"' ERR

  print_banner "Trojan-Go SNI 生产级安装器"
  detect_os
  detect_arch
  prompt_install_config
  validate_port_plan
  install_packages
  prepare_managed_paths
  persist_and_install_project
  check_required_ports_before_install
  check_domain_resolution

  print_step "停止冲突服务并准备证书申请"
  stop_service_if_exists "trojan-go"
  stop_service_if_exists "nginx"
  assert_port_free "80"
  print_success "证书申请端口已释放"

  obtain_certificates
  install_trojan_go_latest
  render_static_site
  render_trojan_config
  render_trojan_service
  render_nginx_configs
  configure_nginx_stream_include
  render_renew_units
  render_logrotate

  print_step "启动并设置开机启动"
  systemctl daemon-reload
  systemctl enable --now trojan-go
  nginx -t
  systemctl enable --now nginx
  systemctl restart nginx
  systemctl enable --now trojan-go-sni-renew.timer
  assert_service_active "trojan-go"
  assert_service_active "nginx"
  assert_service_active "trojan-go-sni-renew.timer"
  print_success "服务已启动并设置开机启动"

  trap - ERR
  print_install_summary
}

main "$@"
