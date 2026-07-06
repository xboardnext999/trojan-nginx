#!/usr/bin/env bash

CERTBOT_ARGS=()

build_certbot_args() {
  CERTBOT_ARGS=(
    certonly
    --standalone
    --non-interactive
    --agree-tos
    --preferred-challenges
    http
    --http-01-port
    80
    --keep-until-expiring
  )

  if [[ -n "${CERTBOT_EMAIL}" ]]; then
    CERTBOT_ARGS+=(--email "${CERTBOT_EMAIL}")
  else
    CERTBOT_ARGS+=(--register-unsafely-without-email)
  fi

  if [[ "${LE_STAGING}" == "1" ]]; then
    CERTBOT_ARGS+=(--staging)
  fi
}

certificate_files_exist() {
  local domain="$1"
  [[ -s "/etc/letsencrypt/live/${domain}/fullchain.pem" && -s "/etc/letsencrypt/live/${domain}/privkey.pem" ]]
}

certificate_valid_beyond_renew_window() {
  local domain="$1"
  local threshold_seconds

  certificate_files_exist "${domain}" || return 1
  threshold_seconds=$((RENEW_BEFORE_DAYS * 86400))
  openssl x509 -checkend "${threshold_seconds}" -noout -in "/etc/letsencrypt/live/${domain}/fullchain.pem" >/dev/null 2>&1
}

issue_certificate() {
  local domain="$1"
  print_step "检查证书是否需要续期: ${domain}"

  if certificate_valid_beyond_renew_window "${domain}"; then
    print_success "证书剩余时间超过 ${RENEW_BEFORE_DAYS} 天，跳过续期: ${domain}"
    return 0
  fi

  print_warn "证书剩余时间小于等于 ${RENEW_BEFORE_DAYS} 天，开始申请/续期: ${domain}"
  build_certbot_args
  certbot "${CERTBOT_ARGS[@]}" --cert-name "${domain}" -d "${domain}"
  certificate_files_exist "${domain}" || die "证书文件生成失败: ${domain}"
  print_success "证书已就绪: ${domain}"
}

obtain_certificates() {
  print_step "处理 Let's Encrypt 证书"
  local domain
  while IFS= read -r domain; do
    [[ -n "${domain}" ]] || continue
    issue_certificate "${domain}"
  done < <(unique_domains)
  print_success "证书处理完成"
}
