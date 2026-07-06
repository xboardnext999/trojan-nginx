#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

sync_project_files() {
  local project_real
  local install_real

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
      ! -name "work" \
      -exec cp -a {} "${INSTALL_ROOT}/" \;
  fi

  chmod +x "${INSTALL_ROOT}/install.sh" "${INSTALL_ROOT}/uninstall.sh" \
    "${INSTALL_ROOT}/update.sh" "${INSTALL_ROOT}/renew.sh" \
    "${INSTALL_ROOT}/setup-menu.sh" "${INSTALL_ROOT}/trojan"
  ln -sf "${INSTALL_ROOT}/trojan" "${TROJAN_CLI_LINK}"
}

main() {
  require_bash_5
  require_root
  load_config

  print_banner "Trojan-Go 中文菜单安装器"
  require_runtime_config
  sync_project_files
  print_success "中文菜单已安装: ${TROJAN_CLI_LINK}"
  print_info "现在可以直接输入 trojan 进入中文菜单"
}

main "$@"
