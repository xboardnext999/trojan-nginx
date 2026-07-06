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

certificate_valid_for_30_days() {
  local domain="$1"
  certificate_files_exist "${domain}" || return 1
  openssl x509 -checkend 2592000 -noout -in "/etc/letsencrypt/live/${domain}/fullchain.pem" >/dev/null 2>&1
}

issue_certificate() {
  local domain="$1"
  print_step "申请或续期证书: ${domain}"

  if certificate_valid_for_30_days "${domain}"; then
    print_success "证书有效期超过 30 天，跳过申请: ${domain}"
    return 0
  fi

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
