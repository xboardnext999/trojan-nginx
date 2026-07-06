#!/usr/bin/env bash

trojan_go_version() {
  if [[ -x "${TROJAN_BIN}" ]]; then
    "${TROJAN_BIN}" -version 2>&1 | head -n 1
  else
    printf 'not installed'
  fi
}

install_trojan_go_latest() {
  print_step "下载并安装 Trojan-Go 最新 Release"
  [[ -n "${TROJAN_GO_ASSET:-}" ]] || detect_arch

  local tmp_dir
  local archive
  local download_url
  local binary
  tmp_dir=$(mktemp -d)
  archive="${tmp_dir}/trojan-go.zip"
  download_url="https://github.com/${TROJAN_GO_REPO}/releases/latest/download/${TROJAN_GO_ASSET}"

  print_info "下载地址: ${download_url}"
  curl -fL --retry 3 --connect-timeout 15 -o "${archive}" "${download_url}"
  unzip -q -o "${archive}" -d "${tmp_dir}/unpack"

  binary=$(find "${tmp_dir}/unpack" -type f -name trojan-go -print -quit)
  [[ -n "${binary}" ]] || die "压缩包中未找到 trojan-go 二进制文件"

  install -m 755 "${binary}" "${TROJAN_BIN}"
  rm -rf -- "${tmp_dir}"
  print_success "Trojan-Go 已安装: $(trojan_go_version)"
}

render_trojan_config() {
  print_step "生成 Trojan-Go 配置"
  install -d -m 755 "${TROJAN_CONFIG_DIR}"
  render_template "trojan-go-config.json.tpl" "${TROJAN_CONFIG_FILE}" "0600"
  print_success "Trojan-Go 配置已生成"
}

render_trojan_service() {
  print_step "生成 Trojan-Go systemd 服务"
  render_template "trojan-go.service.tpl" "${TROJAN_SERVICE_FILE}" "0644"
  print_success "Trojan-Go systemd 服务已生成"
}

render_renew_units() {
  print_step "生成证书自动续期 systemd 单元"
  render_template "trojan-go-sni-renew.service.tpl" "${RENEW_SERVICE_FILE}" "0644"
  render_template "trojan-go-sni-renew.timer.tpl" "${RENEW_TIMER_FILE}" "0644"
  print_success "证书自动续期单元已生成"
}
