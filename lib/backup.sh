#!/usr/bin/env bash

BACKUP_DIR=""
BACKUP_MANIFEST=""

create_backup() {
  local timestamp
  timestamp=$(date +%Y%m%d-%H%M%S)
  BACKUP_DIR="${BACKUP_ROOT}/${timestamp}"
  BACKUP_MANIFEST="${BACKUP_DIR}/manifest"
  install -d -m 700 "${BACKUP_DIR}/files" "${BACKUP_DIR}/missing"
  : > "${BACKUP_MANIFEST}"
  print_info "备份目录: ${BACKUP_DIR}"
}

backup_path() {
  local target="$1"
  [[ -n "${BACKUP_DIR}" ]] || die "内部错误: backup_path 调用前必须先 create_backup"

  printf '%s\n' "${target}" >> "${BACKUP_MANIFEST}"

  if [[ -e "${target}" || -L "${target}" ]]; then
    install -d -m 700 "${BACKUP_DIR}/files$(dirname "${target}")"
    cp -a -- "${target}" "${BACKUP_DIR}/files${target}"
  else
    install -d -m 700 "${BACKUP_DIR}/missing$(dirname "${target}")"
    : > "${BACKUP_DIR}/missing${target}"
  fi
}

restore_backup() {
  if [[ -z "${BACKUP_DIR}" || ! -f "${BACKUP_MANIFEST}" ]]; then
    return 0
  fi

  print_warn "开始恢复备份: ${BACKUP_DIR}"
  while IFS= read -r target; do
    [[ -n "${target}" ]] || continue

    if [[ -e "${BACKUP_DIR}/missing${target}" ]]; then
      rm -rf -- "${target}"
      continue
    fi

    if [[ -e "${BACKUP_DIR}/files${target}" || -L "${BACKUP_DIR}/files${target}" ]]; then
      rm -rf -- "${target}"
      install -d -m 755 "$(dirname "${target}")"
      cp -a -- "${BACKUP_DIR}/files${target}" "${target}"
    fi
  done < "${BACKUP_MANIFEST}"
  print_warn "备份恢复完成"
}
