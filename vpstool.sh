#!/bin/sh

set -eu

VERSION="1.0.0"
COLOR_GREEN="\033[0;32m"
COLOR_RED="\033[0;31m"
COLOR_RESET="\033[0m"

print_banner() {
  printf '%b' "\033[0;31m"
  printf '%s\n' "__     __  ____   ____      _____   ___    ___   _     "
  printf '%b' "\033[0;33m"
  printf '%s\n' "\\ \\   / / |  _ \\ / ___|    |_   _| / _ \\  / _ \\ | |    "
  printf '%b' "\033[0;32m"
  printf '%s\n' " \\ \\ / /  | |_) |\\___ \\      | |  | | | || | | || |    "
  printf '%b' "\033[0;36m"
  printf '%s\n' "  \\ V /   |  __/  ___) |     | |  | |_| || |_| || |___ "
  printf '%b' "\033[0;34m"
  printf '%s\n' "   \\_/    |_|    |____/      |_|   \\___/  \\___/ |_____|"
  printf '%b' "\033[0;35m"
  printf '%s\n' "           vps tool"
  printf '%b' "$COLOR_RESET"
}

run_sysinfo() {
  curl -s https://raw.githubusercontent.com/LeoJyenn/vpstool/main/system_info.sh | bash
}

get_remote_version() {
  curl -fsSL https://raw.githubusercontent.com/LeoJyenn/vpstool/main/vpstool.sh \
    | awk -F'"' '/^VERSION=/{print $2; exit}'
}

update_script() {
  remote_version=$(get_remote_version || true)
  if [ -z "${remote_version:-}" ]; then
    printf '%s\n' "获取远程版本失败。"
    return 1
  fi

  if [ "$remote_version" = "$VERSION" ]; then
    printf '%s\n' "已是最新版本: $VERSION"
    return 0
  fi

  tmp_file=$(mktemp)
  if ! curl -fsSL https://raw.githubusercontent.com/LeoJyenn/vpstool/main/vpstool.sh -o "$tmp_file"; then
    rm -f "$tmp_file"
    printf '%s\n' "下载更新失败。"
    return 1
  fi

  if ! grep -q "^VERSION=\"$remote_version\"" "$tmp_file"; then
    rm -f "$tmp_file"
    printf '%s\n' "版本校验失败，取消更新。"
    return 1
  fi

  if [ ! -w "$0" ]; then
    rm -f "$tmp_file"
    printf '%s\n' "无写入权限，请使用 sudo 运行。"
    return 1
  fi

  mv "$tmp_file" "$0"
  chmod 755 "$0"
  printf '%s\n' "更新成功: $VERSION -> $remote_version"
}

install_shortcut() {
  if [ "$(id -u)" != "0" ]; then
    printf '%s\n' "需要 root 权限，请使用 sudo 运行。"
    return 1
  fi

  script_path=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/$(basename -- "$0")
  install_target=/usr/local/bin/vps

  cp "$script_path" "$install_target"
  chmod 755 "$install_target"
  printf '%s\n' "已安装快捷命令: vps"
}

uninstall_shortcut() {
  if [ "$(id -u)" != "0" ]; then
    printf '%s\n' "需要 root 权限，请使用 sudo 运行。"
    return 1
  fi

  install_target=/usr/local/bin/vps
  if [ -e "$install_target" ]; then
    rm -f "$install_target"
    printf '%s\n' "已卸载快捷命令: vps"
  else
    printf '%s\n' "未找到快捷命令: vps"
  fi
}

show_menu() {
  print_banner
  printf '%s\n' ""
  printf '%s\n' "1) 系统信息"
  printf '%s\n' "2) 安装快捷命令 (vps)"
  printf '%s\n' "--------------------"
  printf '%b\n' "${COLOR_GREEN}00) 更新脚本${COLOR_RESET}"
  printf '%s\n' "--------------------"
  printf '%b\n' "${COLOR_RED}88) 卸载快捷命令 (vps)${COLOR_RESET}"
  printf '%s\n' "0) 退出"
  printf '%s' "请选择: "
}

case "${1-}" in
  info)
    run_sysinfo
    exit 0
    ;;
  install)
    install_shortcut
    exit 0
    ;;
  uninstall)
    uninstall_shortcut
    exit 0
    ;;
  update)
    update_script
    exit 0
    ;;
  "")
    :
    ;;
  *)
    printf '%s\n' "Unknown command: $1"
    printf '%s\n' "Usage: vpstool.sh [info|install|uninstall|update]"
    exit 1
    ;;
esac

while true; do
  show_menu
  read -r choice || exit 0
  case "$choice" in
    1)
      run_sysinfo
      ;;
    2)
      install_shortcut
      ;;
    00)
      update_script
      ;;
    88)
      uninstall_shortcut
      ;;
    0)
      exit 0
      ;;
    *)
      printf '%s\n' "无效选择: $choice"
      ;;
  esac
  printf '%s\n' ""
done
