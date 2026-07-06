#!/usr/bin/env bash

SYSTEM_ARCH=""
TROJAN_GO_ASSET=""

detect_os() {
  print_step "检测操作系统"
  if [[ ! -f /etc/os-release ]]; then
    die "无法检测操作系统: 缺少 /etc/os-release"
  fi

  # shellcheck source=/dev/null
  source /etc/os-release
  local os_id="${ID:-}"
  local version_id="${VERSION_ID:-0}"
  local major_version="${version_id%%.*}"

  case "${os_id}" in
    ubuntu)
      if ((major_version < 22)); then
        die "Ubuntu 版本过低，需要 Ubuntu 22.04 或更高版本，当前: ${version_id}"
      fi
      ;;
    debian)
      if ((major_version < 12)); then
        die "Debian 版本过低，需要 Debian 12 或更高版本，当前: ${version_id}"
      fi
      ;;
    *)
      die "不支持的系统: ${PRETTY_NAME:-${os_id}}"
      ;;
  esac

  print_success "系统支持: ${PRETTY_NAME:-${os_id} ${version_id}}"
}

detect_arch() {
  print_step "检测系统架构"
  local machine
  machine=$(uname -m)
  case "${machine}" in
    x86_64|amd64)
      SYSTEM_ARCH="amd64"
      TROJAN_GO_ASSET="trojan-go-linux-amd64.zip"
      ;;
    aarch64|arm64)
      SYSTEM_ARCH="arm64"
      TROJAN_GO_ASSET="trojan-go-linux-armv8.zip"
      ;;
    *)
      die "不支持的系统架构: ${machine}"
      ;;
  esac
  export SYSTEM_ARCH TROJAN_GO_ASSET
  print_success "系统架构: ${SYSTEM_ARCH}"
}

install_packages() {
  print_step "安装系统依赖"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y --no-install-recommends \
    ca-certificates \
    certbot \
    curl \
    gettext-base \
    iproute2 \
    libnginx-mod-stream \
    nginx \
    openssl \
    unzip \
    wget
  print_success "系统依赖已安装"
}

install_update_dependencies() {
  print_step "安装升级依赖"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y --no-install-recommends ca-certificates curl openssl unzip wget
  print_success "升级依赖已安装"
}

validate_port_plan() {
  validate_port_or_die "${TROJAN_PORT}" "Trojan 后端监听端口"
  validate_port_or_die "${WEB_PORT}" "伪装网站本地 HTTPS 端口"
  validate_port_or_die "${TROJAN_REMOTE_PORT}" "Trojan-Go fallback 端口"

  if [[ "${TROJAN_PORT}" == "80" || "${TROJAN_PORT}" == "443" ]]; then
    die "Trojan 后端监听端口不能使用外部端口 80 或 443"
  fi

  if [[ "${WEB_PORT}" == "80" || "${WEB_PORT}" == "443" ]]; then
    die "伪装网站本地 HTTPS 端口不能使用外部端口 80 或 443"
  fi

  if [[ "${TROJAN_REMOTE_PORT}" == "80" || "${TROJAN_REMOTE_PORT}" == "443" ]]; then
    die "Trojan-Go fallback 端口不能使用外部端口 80 或 443，建议使用 8081"
  fi

  if [[ "${TROJAN_PORT}" == "${WEB_PORT}" ]]; then
    die "Trojan 后端监听端口不能与伪装网站本地 HTTPS 端口相同"
  fi

  if [[ "${TROJAN_PORT}" == "${TROJAN_REMOTE_PORT}" || "${WEB_PORT}" == "${TROJAN_REMOTE_PORT}" ]]; then
    die "Trojan 后端端口、网站 HTTPS 端口和 fallback 网站端口必须互不相同"
  fi
}

port_listeners() {
  local port="$1"
  ss -H -ltnp 2>/dev/null | awk -v suffix=":${port}" '$4 ~ suffix "$" {print}'
}

assert_port_usable() {
  local port="$1"
  local allowed_regex="$2"
  local listeners
  listeners=$(port_listeners "${port}")

  if [[ -z "${listeners}" ]]; then
    print_success "端口可用: ${port}"
    return 0
  fi

  if grep -Ev "${allowed_regex}" <<< "${listeners}" | grep -q .; then
    print_error "端口 ${port} 被非托管进程占用:"
    printf '%s\n' "${listeners}"
    return 1
  fi

  print_warn "端口 ${port} 当前由托管服务占用，将在部署过程中重载"
}

assert_port_free() {
  local port="$1"
  local listeners
  listeners=$(port_listeners "${port}")

  if [[ -n "${listeners}" ]]; then
    print_error "端口 ${port} 未释放:"
    printf '%s\n' "${listeners}"
    return 1
  fi

  print_success "端口已释放: ${port}"
}

check_required_ports_before_install() {
  print_step "检测端口占用"
  assert_port_usable "80" "nginx|certbot"
  assert_port_usable "443" "nginx"
  assert_port_usable "${TROJAN_PORT}" "trojan-go"
  assert_port_usable "${WEB_PORT}" "nginx"
  assert_port_usable "${TROJAN_REMOTE_PORT}" "nginx"
  print_success "端口检测通过"
}

fetch_public_ipv4() {
  curl -4fsS --max-time 10 https://api.ipify.org || curl -4fsS --max-time 10 https://ipv4.icanhazip.com
}

fetch_public_ipv6() {
  curl -6fsS --max-time 10 https://api64.ipify.org || curl -6fsS --max-time 10 https://ipv6.icanhazip.com
}

resolve_ipv4() {
  local domain="$1"
  getent ahostsv4 "${domain}" | awk '{print $1}' | awk '!seen[$0]++'
}

resolve_ipv6() {
  local domain="$1"
  getent ahostsv6 "${domain}" | awk '{print $1}' | awk '!seen[$0]++'
}

ip_in_list() {
  local needle="$1"
  local candidate
  while IFS= read -r candidate; do
    if [[ "${candidate}" == "${needle}" ]]; then
      return 0
    fi
  done
  return 1
}

check_domain_resolution() {
  if [[ "${SKIP_DNS_CHECK}" == "1" ]]; then
    print_warn "已跳过 DNS 解析检测"
    return 0
  fi

  print_step "检测域名解析"
  local public_ipv4
  public_ipv4=$(fetch_public_ipv4)
  [[ -n "${public_ipv4}" ]] || die "无法获取服务器公网 IPv4"
  print_info "服务器公网 IPv4: ${public_ipv4}"

  local domain
  local records
  while IFS= read -r domain; do
    records=$(resolve_ipv4 "${domain}")
    if [[ -z "${records}" ]]; then
      die "${domain} 没有解析到 IPv4 地址"
    fi
    if ! ip_in_list "${public_ipv4}" <<< "${records}"; then
      print_error "${domain} 的 A 记录未指向本机 IPv4"
      printf '%s\n' "${records}"
      exit 1
    fi
    print_success "${domain} A 记录正确"
  done < <(unique_domains)

  if [[ "${ENABLE_IPV6}" == "Y" ]]; then
    local public_ipv6
    public_ipv6=$(fetch_public_ipv6)
    [[ -n "${public_ipv6}" ]] || die "已开启 IPv6，但无法获取服务器公网 IPv6"
    print_info "服务器公网 IPv6: ${public_ipv6}"

    while IFS= read -r domain; do
      records=$(resolve_ipv6 "${domain}")
      if [[ -z "${records}" ]]; then
        die "${domain} 没有解析到 IPv6 地址"
      fi
      if ! ip_in_list "${public_ipv6}" <<< "${records}"; then
        print_error "${domain} 的 AAAA 记录未指向本机 IPv6"
        printf '%s\n' "${records}"
        exit 1
      fi
      print_success "${domain} AAAA 记录正确"
    done < <(unique_domains)
  fi
}
