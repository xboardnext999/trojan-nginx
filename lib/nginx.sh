#!/usr/bin/env bash

disable_default_nginx_sites() {
  print_step "处理 Nginx 默认站点"
  local target
  for target in /etc/nginx/sites-enabled/default /etc/nginx/conf.d/default.conf; do
    if [[ -e "${target}" || -L "${target}" ]]; then
      rm -f -- "${target}"
      print_info "已禁用默认站点: ${target}"
    fi
  done
  print_success "Nginx 默认站点处理完成"
}

configure_nginx_stream_include() {
  print_step "开启 Nginx stream 配置入口"
  install -d -m 755 "${NGINX_STREAM_CONF_DIR}"

  if grep -Eq 'include[[:space:]]+/etc/nginx/stream-conf\.d/\*\.conf;' "${NGINX_MAIN_CONF}"; then
    print_success "Nginx stream include 已存在"
    return 0
  fi

  if grep -Eq '^[[:space:]]*stream[[:space:]]*\{' "${NGINX_MAIN_CONF}"; then
    local tmp
    tmp=$(mktemp)
    awk '
      BEGIN { inserted = 0 }
      /^[[:space:]]*stream[[:space:]]*\{/ && inserted == 0 {
        print
        print "    # trojan-go-sni managed include"
        print "    include /etc/nginx/stream-conf.d/*.conf;"
        inserted = 1
        next
      }
      { print }
    ' "${NGINX_MAIN_CONF}" > "${tmp}"
    install -m 644 "${tmp}" "${NGINX_MAIN_CONF}"
    rm -f "${tmp}"
  else
    cat >> "${NGINX_MAIN_CONF}" <<'NGINX'

# BEGIN trojan-go-sni managed stream
stream {
    include /etc/nginx/stream-conf.d/*.conf;
}
# END trojan-go-sni managed stream
NGINX
  fi

  print_success "Nginx stream 配置入口已开启"
}

render_nginx_configs() {
  print_step "生成 Nginx 配置"
  disable_default_nginx_sites
  render_template "nginx-http.conf.tpl" "${NGINX_HTTP_CONF}" "0644"
  render_template "nginx-stream.conf.tpl" "${NGINX_STREAM_CONF}" "0644"
  print_success "Nginx 配置已生成"
}
