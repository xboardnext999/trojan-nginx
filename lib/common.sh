#!/usr/bin/env bash

COMMON_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROJECT_DIR=$(cd -- "${COMMON_DIR}/.." && pwd)
CONFIG_DEFAULT_FILE="${PROJECT_DIR}/config.env"
CONFIG_LOADED="0"
LOG_FILE=""

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

print_banner() {
  blue "============================================================"
  blue "$1"
  blue "============================================================"
}

print_step() { blue "[步骤] $*"; }
print_info() { printf '[信息] %s\n' "$*"; }
print_success() { green "[成功] $*"; }
print_warn() { yellow "[警告] $*"; }
print_error() { red "[失败] $*"; }

die() {
  print_error "$*"
  exit 1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

require_bash_5() {
  if ((BASH_VERSINFO[0] < 5)); then
    die "需要 Bash 5.x 或更高版本，当前版本: ${BASH_VERSION}"
  fi
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    die "请使用 root 权限运行"
  fi
}

normalize_yes_no() {
  case "${1:-N}" in
    y|Y|yes|YES|true|TRUE|1)
      printf 'Y'
      ;;
    *)
      printf 'N'
      ;;
  esac
}

derive_config() {
  PROJECT_NAME="${PROJECT_NAME:-trojan-go-sni}"
  PROJECT_DISPLAY_NAME="${PROJECT_DISPLAY_NAME:-Trojan-Go SNI}"
  TROJAN_PORT="${TROJAN_PORT:-8080}"
  TROJAN_REMOTE_ADDR="${TROJAN_REMOTE_ADDR:-127.0.0.1}"
  TROJAN_REMOTE_PORT="${TROJAN_REMOTE_PORT:-8081}"
  WEB_PORT="${WEB_PORT:-8443}"
  ENABLE_IPV6=$(normalize_yes_no "${ENABLE_IPV6:-N}")
  CERTBOT_EMAIL="${CERTBOT_EMAIL:-}"
  LE_STAGING="${LE_STAGING:-0}"
  SKIP_DNS_CHECK="${SKIP_DNS_CHECK:-0}"
  TROJAN_GO_REPO="${TROJAN_GO_REPO:-p4gefau1t/trojan-go}"
  TROJAN_BIN="${TROJAN_BIN:-/usr/local/bin/trojan-go}"
  TROJAN_CLI_LINK="${TROJAN_CLI_LINK:-/usr/local/bin/trojan}"
  INSTALL_ROOT="${INSTALL_ROOT:-/opt/${PROJECT_NAME}}"
  RUNTIME_DIR="${RUNTIME_DIR:-/etc/${PROJECT_NAME}}"
  RUNTIME_CONFIG_FILE="${RUNTIME_CONFIG_FILE:-${RUNTIME_DIR}/config.env}"
  TROJAN_CONFIG_DIR="${TROJAN_CONFIG_DIR:-/etc/trojan-go}"
  TROJAN_CONFIG_FILE="${TROJAN_CONFIG_FILE:-${TROJAN_CONFIG_DIR}/config.json}"
  TROJAN_SERVICE_FILE="${TROJAN_SERVICE_FILE:-/etc/systemd/system/trojan-go.service}"
  WEB_ROOT="${WEB_ROOT:-/var/www/${PROJECT_NAME}}"
  NGINX_HTTP_CONF="${NGINX_HTTP_CONF:-/etc/nginx/conf.d/${PROJECT_NAME}.conf}"
  NGINX_STREAM_CONF_DIR="${NGINX_STREAM_CONF_DIR:-/etc/nginx/stream-conf.d}"
  NGINX_STREAM_CONF="${NGINX_STREAM_CONF:-${NGINX_STREAM_CONF_DIR}/${PROJECT_NAME}.conf}"
  NGINX_MAIN_CONF="${NGINX_MAIN_CONF:-/etc/nginx/nginx.conf}"
  RENEW_SERVICE_FILE="${RENEW_SERVICE_FILE:-/etc/systemd/system/${PROJECT_NAME}-renew.service}"
  RENEW_TIMER_FILE="${RENEW_TIMER_FILE:-/etc/systemd/system/${PROJECT_NAME}-renew.timer}"
  RENEW_TIMER_CALENDAR="${RENEW_TIMER_CALENDAR:-daily}"
  RENEW_RANDOM_DELAY="${RENEW_RANDOM_DELAY:-2h}"
  LOG_DIR="${LOG_DIR:-/var/log/${PROJECT_NAME}}"
  LOGROTATE_FILE="${LOGROTATE_FILE:-/etc/logrotate.d/${PROJECT_NAME}}"
  BACKUP_ROOT="${BACKUP_ROOT:-/var/backups/${PROJECT_NAME}}"
  if [[ -z "${CLIENT_NAME:-}" || "${CLIENT_NAME:-}" == "Trojan-Go SNI" ]]; then
    CLIENT_NAME="${TROJAN_DOMAIN:-Trojan-Go SNI}"
  fi
  CLIENT_URI_FILE="${CLIENT_URI_FILE:-${RUNTIME_DIR}/client.uri}"
  CLIENT_QR_PNG="${CLIENT_QR_PNG:-${RUNTIME_DIR}/client-qr.png}"
  CLIENT_QR_TXT="${CLIENT_QR_TXT:-${RUNTIME_DIR}/client-qr.txt}"
  NON_INTERACTIVE="${NON_INTERACTIVE:-0}"
  ASSUME_YES="${ASSUME_YES:-0}"

  TROJAN_CERT_FULLCHAIN="/etc/letsencrypt/live/${TROJAN_DOMAIN:-}/fullchain.pem"
  TROJAN_CERT_PRIVKEY="/etc/letsencrypt/live/${TROJAN_DOMAIN:-}/privkey.pem"
  WEB_CERT_FULLCHAIN="/etc/letsencrypt/live/${WEB_DOMAIN:-}/fullchain.pem"
  WEB_CERT_PRIVKEY="/etc/letsencrypt/live/${WEB_DOMAIN:-}/privkey.pem"

  SAME_DOMAIN_MODE="0"
  if [[ -n "${TROJAN_DOMAIN:-}" && "${TROJAN_DOMAIN:-}" == "${WEB_DOMAIN:-}" ]]; then
    SAME_DOMAIN_MODE="1"
  fi

  NGINX_SITE_SERVER_NAMES="${WEB_DOMAIN:-_}"
  NGINX_STREAM_MAP_ENTRIES=""
  if [[ -n "${TROJAN_DOMAIN:-}" && -n "${WEB_DOMAIN:-}" ]]; then
    if [[ "${SAME_DOMAIN_MODE}" == "1" ]]; then
      NGINX_SITE_SERVER_NAMES="${TROJAN_DOMAIN}"
      NGINX_STREAM_MAP_ENTRIES="    ${TROJAN_DOMAIN} trojan_backend;"
    else
      NGINX_SITE_SERVER_NAMES="${WEB_DOMAIN} ${TROJAN_DOMAIN}"
      NGINX_STREAM_MAP_ENTRIES="    ${TROJAN_DOMAIN} trojan_backend;"$'\n'"    ${WEB_DOMAIN} web_backend;"
    fi
  fi

  NGINX_HTTP_IPV6_LISTEN=""
  NGINX_STREAM_IPV6_LISTEN=""
  if [[ "${ENABLE_IPV6}" == "Y" ]]; then
    NGINX_HTTP_IPV6_LISTEN="    listen [::]:80 default_server;"
    NGINX_STREAM_IPV6_LISTEN="    listen [::]:443 reuseport;"
  fi
}

load_config() {
  if [[ ! -f "${CONFIG_DEFAULT_FILE}" ]]; then
    die "缺少默认配置文件: ${CONFIG_DEFAULT_FILE}"
  fi

  # shellcheck source=../config.env
  source "${CONFIG_DEFAULT_FILE}"

  if [[ -n "${RUNTIME_CONFIG_FILE:-}" && -f "${RUNTIME_CONFIG_FILE}" ]]; then
    # shellcheck source=/dev/null
    source "${RUNTIME_CONFIG_FILE}"
  fi

  derive_config
  CONFIG_LOADED="1"
}

init_logging() {
  local action="$1"
  if [[ "${CONFIG_LOADED}" != "1" ]]; then
    die "内部错误: init_logging 调用前必须先 load_config"
  fi

  install -d -m 750 "${LOG_DIR}"
  LOG_FILE="${LOG_DIR}/${action}-$(date +%Y%m%d-%H%M%S).log"
  touch "${LOG_FILE}"
  chmod 640 "${LOG_FILE}"
  exec > >(tee -a "${LOG_FILE}") 2>&1
  print_info "日志文件: ${LOG_FILE}"
}

error_exit() {
  local line="$1"
  local command="$2"
  print_error "命令失败，行号 ${line}: ${command}"
  if declare -F rollback_on_error >/dev/null 2>&1; then
    rollback_on_error
  fi
  exit 1
}

prompt_with_default() {
  local var_name="$1"
  local prompt="$2"
  local default_value="$3"
  local input=""

  if [[ "${NON_INTERACTIVE}" == "1" ]]; then
    printf -v "${var_name}" '%s' "${default_value}"
    return 0
  fi

  read -r -p "${prompt} [${default_value}]: " input
  printf -v "${var_name}" '%s' "${input:-${default_value}}"
}

prompt_required() {
  local var_name="$1"
  local prompt="$2"
  local current_value="${!var_name:-}"
  local input=""

  if [[ "${NON_INTERACTIVE}" == "1" ]]; then
    [[ -n "${current_value}" ]] || die "${prompt} 不能为空"
    return 0
  fi

  while [[ -z "${current_value}" ]]; do
    read -r -p "${prompt}: " input
    current_value="${input}"
  done
  printf -v "${var_name}" '%s' "${current_value}"
}

prompt_secret_or_generate() {
  local var_name="$1"
  local prompt="$2"
  local current_value="${!var_name:-}"
  local input=""

  if [[ "${NON_INTERACTIVE}" == "1" ]]; then
    if [[ -z "${current_value}" ]]; then
      current_value=$(random_password)
    fi
    printf -v "${var_name}" '%s' "${current_value}"
    return 0
  fi

  if [[ -n "${current_value}" ]]; then
    read -r -s -p "${prompt}，留空沿用当前密码: " input
  else
    read -r -s -p "${prompt}: " input
  fi
  printf '\n'
  if [[ -z "${input}" ]]; then
    if [[ -n "${current_value}" ]]; then
      input="${current_value}"
      print_info "已沿用当前 Trojan 密码"
    else
      input=$(random_password)
      print_info "已自动生成 Trojan 密码"
    fi
  fi
  printf -v "${var_name}" '%s' "${input}"
}

prompt_yes_no() {
  local var_name="$1"
  local prompt="$2"
  local default_value="$3"
  local input=""

  if [[ "${NON_INTERACTIVE}" == "1" ]]; then
    printf -v "${var_name}" '%s' "$(normalize_yes_no "${default_value}")"
    return 0
  fi

  read -r -p "${prompt} [${default_value}]: " input
  input="${input:-${default_value}}"
  printf -v "${var_name}" '%s' "$(normalize_yes_no "${input}")"
}

random_password() {
  openssl rand -hex 24
}

validate_domain_or_die() {
  local domain="$1"
  local label="$2"
  if [[ ! "${domain}" =~ ^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$ ]]; then
    die "${label} 格式不正确: ${domain}"
  fi
}

validate_port_or_die() {
  local port="$1"
  local label="$2"
  if [[ ! "${port}" =~ ^[0-9]+$ ]] || ((port < 1 || port > 65535)); then
    die "${label} 必须是 1-65535 之间的数字: ${port}"
  fi
}

validate_password_or_die() {
  local password="$1"
  if [[ ! "${password}" =~ ^[-A-Za-z0-9._~!@#%^+=:,/]{8,128}$ ]]; then
    die "Trojan 密码必须为 8-128 位，并且只能包含字母、数字和 . _ ~ ! @ # % ^ + = : , / -"
  fi
}

require_runtime_config() {
  if [[ ! -f "${RUNTIME_CONFIG_FILE}" ]]; then
    die "未找到运行配置: ${RUNTIME_CONFIG_FILE}，请先执行 install.sh"
  fi
}

write_env_value() {
  local key="$1"
  local value="$2"
  printf '%s=%q\n' "${key}" "${value}"
}

write_runtime_config() {
  local target="$1"
  local tmp
  tmp=$(mktemp)

  {
    printf '# Generated by install.sh. Used by install.sh, update.sh, renew.sh and uninstall.sh.\n'
    write_env_value "PROJECT_NAME" "${PROJECT_NAME}"
    write_env_value "PROJECT_DISPLAY_NAME" "${PROJECT_DISPLAY_NAME}"
    write_env_value "TROJAN_DOMAIN" "${TROJAN_DOMAIN}"
    write_env_value "TROJAN_PORT" "${TROJAN_PORT}"
    write_env_value "TROJAN_PASSWORD" "${TROJAN_PASSWORD}"
    write_env_value "TROJAN_REMOTE_ADDR" "${TROJAN_REMOTE_ADDR}"
    write_env_value "TROJAN_REMOTE_PORT" "${TROJAN_REMOTE_PORT}"
    write_env_value "WEB_DOMAIN" "${WEB_DOMAIN}"
    write_env_value "WEB_PORT" "${WEB_PORT}"
    write_env_value "ENABLE_IPV6" "${ENABLE_IPV6}"
    write_env_value "CERTBOT_EMAIL" "${CERTBOT_EMAIL}"
    write_env_value "LE_STAGING" "${LE_STAGING}"
    write_env_value "SKIP_DNS_CHECK" "${SKIP_DNS_CHECK}"
    write_env_value "TROJAN_GO_REPO" "${TROJAN_GO_REPO}"
    write_env_value "TROJAN_BIN" "${TROJAN_BIN}"
    write_env_value "TROJAN_CLI_LINK" "${TROJAN_CLI_LINK}"
    write_env_value "INSTALL_ROOT" "${INSTALL_ROOT}"
    write_env_value "RUNTIME_DIR" "${RUNTIME_DIR}"
    write_env_value "RUNTIME_CONFIG_FILE" "${RUNTIME_CONFIG_FILE}"
    write_env_value "TROJAN_CONFIG_DIR" "${TROJAN_CONFIG_DIR}"
    write_env_value "TROJAN_CONFIG_FILE" "${TROJAN_CONFIG_FILE}"
    write_env_value "TROJAN_SERVICE_FILE" "${TROJAN_SERVICE_FILE}"
    write_env_value "WEB_ROOT" "${WEB_ROOT}"
    write_env_value "NGINX_HTTP_CONF" "${NGINX_HTTP_CONF}"
    write_env_value "NGINX_STREAM_CONF_DIR" "${NGINX_STREAM_CONF_DIR}"
    write_env_value "NGINX_STREAM_CONF" "${NGINX_STREAM_CONF}"
    write_env_value "NGINX_MAIN_CONF" "${NGINX_MAIN_CONF}"
    write_env_value "RENEW_SERVICE_FILE" "${RENEW_SERVICE_FILE}"
    write_env_value "RENEW_TIMER_FILE" "${RENEW_TIMER_FILE}"
    write_env_value "RENEW_TIMER_CALENDAR" "${RENEW_TIMER_CALENDAR}"
    write_env_value "RENEW_RANDOM_DELAY" "${RENEW_RANDOM_DELAY}"
    write_env_value "LOG_DIR" "${LOG_DIR}"
    write_env_value "LOGROTATE_FILE" "${LOGROTATE_FILE}"
    write_env_value "BACKUP_ROOT" "${BACKUP_ROOT}"
    write_env_value "CLIENT_NAME" "${CLIENT_NAME}"
    write_env_value "CLIENT_URI_FILE" "${CLIENT_URI_FILE}"
    write_env_value "CLIENT_QR_PNG" "${CLIENT_QR_PNG}"
    write_env_value "CLIENT_QR_TXT" "${CLIENT_QR_TXT}"
  } > "${tmp}"

  install -m 600 -D "${tmp}" "${target}"
  rm -f "${tmp}"
}

unique_domains() {
  {
    printf '%s\n' "${TROJAN_DOMAIN:-}"
    printf '%s\n' "${WEB_DOMAIN:-}"
  } | awk 'NF && !seen[$0]++'
}

assert_service_active() {
  local service="$1"
  if systemctl is-active --quiet "${service}"; then
    print_success "服务运行正常: ${service}"
    return 0
  fi

  print_error "服务未运行: ${service}"
  print_info "systemctl status ${service}:"
  systemctl status "${service}" --no-pager -l || true
  print_info "journalctl -u ${service} 最近日志:"
  journalctl -u "${service}" -n 80 --no-pager -l || true
  return 1
}

stop_service_if_exists() {
  local service="$1"
  if systemctl list-unit-files "${service}" >/dev/null 2>&1 || systemctl status "${service}" >/dev/null 2>&1; then
    systemctl stop "${service}" >/dev/null 2>&1 || true
  fi
}

disable_service_if_exists() {
  local service="$1"
  if systemctl list-unit-files "${service}" >/dev/null 2>&1 || systemctl status "${service}" >/dev/null 2>&1; then
    systemctl disable "${service}" >/dev/null 2>&1 || true
  fi
}

print_install_summary() {
  print_banner "部署完成"
  printf 'Trojan 域名: %s\n' "${TROJAN_DOMAIN}"
  printf '端口: 443\n'
  printf '密码: %s\n' "${TROJAN_PASSWORD}"
  printf 'SNI: %s\n' "${TROJAN_DOMAIN}"
  printf '证书路径: %s\n' "${TROJAN_CERT_FULLCHAIN}"
  printf '私钥路径: %s\n' "${TROJAN_CERT_PRIVKEY}"
  printf '伪装站: https://%s\n' "${WEB_DOMAIN}"
  if [[ "${SAME_DOMAIN_MODE}" == "1" ]]; then
    printf '部署模式: 同域伪装，普通浏览器访问通过 Trojan-Go fallback 到本地静态站\n'
  else
    printf '部署模式: 双域 SNI 分流\n'
  fi
  printf '运行配置: %s\n' "${RUNTIME_CONFIG_FILE}"
  printf '日志目录: %s\n' "${LOG_DIR}"
  printf '客户端链接: %s\n' "${CLIENT_URI_FILE}"
  printf '二维码 PNG: %s\n' "${CLIENT_QR_PNG}"
  printf '二维码文本: %s\n' "${CLIENT_QR_TXT}"
  printf '\n客户端配置示例:\n'
  printf '  类型: Trojan-Go\n'
  printf '  地址: %s\n' "${TROJAN_DOMAIN}"
  printf '  端口: 443\n'
  printf '  密码: %s\n' "${TROJAN_PASSWORD}"
  printf '  传输: TCP\n'
  printf '  TLS: 开启\n'
  printf '  SNI: %s\n' "${TROJAN_DOMAIN}"
  printf '  ALPN: http/1.1\n'
}
