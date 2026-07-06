#!/usr/bin/env bash

url_encode() {
  local value="$1"
  python3 - "$value" <<'PY'
import sys
from urllib.parse import quote

print(quote(sys.argv[1], safe=""))
PY
}

build_client_uri() {
  local encoded_password
  local encoded_sni
  local encoded_alpn
  local encoded_name

  encoded_password=$(url_encode "${TROJAN_PASSWORD}")
  encoded_sni=$(url_encode "${TROJAN_DOMAIN}")
  encoded_alpn=$(url_encode "http/1.1")
  encoded_name=$(url_encode "${CLIENT_NAME}")

  printf 'trojan://%s@%s:443?security=tls&type=tcp&sni=%s&alpn=%s#%s' \
    "${encoded_password}" \
    "${TROJAN_DOMAIN}" \
    "${encoded_sni}" \
    "${encoded_alpn}" \
    "${encoded_name}"
}

generate_client_artifacts() {
  print_step "生成客户端链接和二维码"
  local client_uri

  client_uri=$(build_client_uri)
  install -d -m 700 "${RUNTIME_DIR}"
  printf '%s\n' "${client_uri}" > "${CLIENT_URI_FILE}"
  chmod 600 "${CLIENT_URI_FILE}"

  qrencode -o "${CLIENT_QR_PNG}" "${client_uri}"
  chmod 600 "${CLIENT_QR_PNG}"
  qrencode -t ANSIUTF8 "${client_uri}" > "${CLIENT_QR_TXT}"
  chmod 600 "${CLIENT_QR_TXT}"

  print_success "客户端链接已生成: ${CLIENT_URI_FILE}"
  print_success "二维码 PNG 已生成: ${CLIENT_QR_PNG}"
  print_success "二维码文本已生成: ${CLIENT_QR_TXT}"
  printf '\n'
  qrencode -t ANSIUTF8 "${client_uri}"
  printf '\n'
}
