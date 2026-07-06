#!/usr/bin/env bash

template_vars() {
  printf '%s' '
$PROJECT_NAME
$PROJECT_DISPLAY_NAME
$TROJAN_DOMAIN
$TROJAN_PORT
$TROJAN_PASSWORD
$TROJAN_REMOTE_ADDR
$TROJAN_REMOTE_PORT
$WEB_DOMAIN
$WEB_PORT
$WEB_ROOT
$TROJAN_CONFIG_FILE
$TROJAN_BIN
$TROJAN_CERT_FULLCHAIN
$TROJAN_CERT_PRIVKEY
$WEB_CERT_FULLCHAIN
$WEB_CERT_PRIVKEY
$NGINX_HTTP_IPV6_LISTEN
$NGINX_STREAM_IPV6_LISTEN
$INSTALL_ROOT
$LOG_DIR
$RENEW_TIMER_CALENDAR
$RENEW_RANDOM_DELAY
'
}

export_template_values() {
  export PROJECT_NAME PROJECT_DISPLAY_NAME TROJAN_DOMAIN TROJAN_PORT TROJAN_PASSWORD
  export TROJAN_REMOTE_ADDR TROJAN_REMOTE_PORT WEB_DOMAIN WEB_PORT WEB_ROOT
  export TROJAN_CONFIG_FILE TROJAN_BIN TROJAN_CERT_FULLCHAIN TROJAN_CERT_PRIVKEY
  export WEB_CERT_FULLCHAIN WEB_CERT_PRIVKEY NGINX_HTTP_IPV6_LISTEN
  export NGINX_STREAM_IPV6_LISTEN INSTALL_ROOT LOG_DIR RENEW_TIMER_CALENDAR
  export RENEW_RANDOM_DELAY
}

render_template() {
  local template_name="$1"
  local destination="$2"
  local mode="$3"
  local template_file="${PROJECT_DIR}/templates/${template_name}"
  local tmp

  [[ -f "${template_file}" ]] || die "缺少模板文件: ${template_file}"
  tmp=$(mktemp)
  export_template_values
  envsubst "$(template_vars)" < "${template_file}" > "${tmp}"
  install -m "${mode}" -D "${tmp}" "${destination}"
  rm -f "${tmp}"
}

render_static_site() {
  print_step "生成伪装网站"
  install -d -m 755 "${WEB_ROOT}"
  render_template "site-index.html.tpl" "${WEB_ROOT}/index.html" "0644"
  print_success "伪装网站已生成: ${WEB_ROOT}"
}

render_logrotate() {
  print_step "生成日志轮转配置"
  install -d -m 750 "${LOG_DIR}"
  render_template "logrotate.conf.tpl" "${LOGROTATE_FILE}" "0644"
  print_success "日志轮转配置已生成"
}
