#!/bin/sh

set -eu

print_banner() {
  cat <<'EOF'
__     ___  ____     _____ ___   ___  _     
\ \   / / |/ ___|   |_   _/ _ \ / _ \| |    
 \ \ / /| | |        | || | | | | | | |    
  \ V / | | |___     | || |_| | |_| | |___ 
   \_/  |_|\____|    |_| \___/ \___/|_____|
           vps tool
EOF
}

run_sysinfo() {
  curl -s https://raw.githubusercontent.com/LeoJyenn/vpstool/main/system_info.sh | bash
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
  printf '%s\n' "88) 卸载快捷命令 (vps)"
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
  "")
    :
    ;;
  *)
    printf '%s\n' "Unknown command: $1"
    printf '%s\n' "Usage: vpstool.sh [info|install|uninstall]"
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
