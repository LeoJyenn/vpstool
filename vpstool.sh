#!/bin/sh

set -eu

VERSION="1.1.0"
COLOR_GREEN="\033[0;32m"
COLOR_RED="\033[0;31m"
COLOR_YELLOW="\033[0;33m"
COLOR_CYAN="\033[0;36m"
COLOR_RESET="\033[0m"

info() {
  printf '%b%s%b\n' "$COLOR_GREEN" "$1" "$COLOR_RESET"
}

warn() {
  printf '%b%s%b\n' "$COLOR_YELLOW" "$1" "$COLOR_RESET"
}

error() {
  printf '%b%s%b\n' "$COLOR_RED" "$1" "$COLOR_RESET"
}

section() {
  line="=============================================================="
  printf '%b%s%b\n' "\033[0;37m" "$line" "$COLOR_RESET"
}

title_main() {
  printf '%b%s%b\n' "$COLOR_YELLOW" "$1" "$COLOR_RESET"
}

title_sub() {
  printf '%b%s%b\n' "$COLOR_CYAN" "$1" "$COLOR_RESET"
}

pause_return() {
  if [ -t 0 ]; then
    printf '%b%s%b' "$COLOR_YELLOW" "按任意键返回..." "$COLOR_RESET"
    if command -v stty >/dev/null 2>&1 && command -v dd >/dev/null 2>&1; then
      stty_state=$(stty -g)
      stty -echo -icanon time 0 min 1
      dd bs=1 count=1 >/dev/null 2>&1
      stty "$stty_state"
      printf '%s\n' ""
    else
      read -r _
      printf '%s\n' ""
    fi
  fi
}

require_root() {
  if [ "$(id -u)" != "0" ]; then
    error "需要 root 权限，请使用 sudo 运行。"
    pause_return
    return 1
  fi
  return 0
}

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
  printf '%b' "$COLOR_RESET"
}

run_sysinfo() {
  if curl -fsSL https://raw.githubusercontent.com/LeoJyenn/vpstool/main/system_info.sh | bash; then
    info "系统信息获取完成"
  else
    error "系统信息获取失败"
  fi
  pause_return
}

update_system() {
  require_root || return 1

  if command -v apt >/dev/null 2>&1; then
    if apt-get update && apt-get upgrade -y; then
      info "系统更新完成"
    else
      error "系统更新失败"
    fi
  elif command -v dnf >/dev/null 2>&1; then
    if dnf check-update && dnf upgrade -y; then
      info "系统更新完成"
    else
      error "系统更新失败"
    fi
  elif command -v yum >/dev/null 2>&1; then
    if yum check-update && yum upgrade -y; then
      info "系统更新完成"
    else
      error "系统更新失败"
    fi
  elif command -v apk >/dev/null 2>&1; then
    if apk update && apk upgrade; then
      info "系统更新完成"
    else
      error "系统更新失败"
    fi
  elif command -v pacman >/dev/null 2>&1; then
    if pacman -Syu --noconfirm; then
      info "系统更新完成"
    else
      error "系统更新失败"
    fi
  else
    error "不支持的Linux发行版"
    pause_return
    return 1
  fi
  pause_return
  return 0
}

clean_system() {
  require_root || return 1

  if command -v apt >/dev/null 2>&1; then
    clean_ok=true
    apt autoremove --purge -y || clean_ok=false
    apt clean -y || clean_ok=false
    apt autoclean -y || clean_ok=false
    rc_packages=$(dpkg -l | awk '/^rc/ {print $2}')
    if [ -n "$rc_packages" ]; then
      apt remove --purge -y $rc_packages || clean_ok=false
    fi
    if command -v journalctl >/dev/null 2>&1; then
      journalctl --vacuum-time=1s || clean_ok=false
      journalctl --vacuum-size=50M || clean_ok=false
    fi
    kernel_packages=$(dpkg -l | awk '/^ii linux-(image|headers)-[^ ]+/{print $2}' \
      | grep -v "$(uname -r | sed 's/-.*//')")
    if [ -n "$kernel_packages" ]; then
      apt remove --purge -y $kernel_packages || clean_ok=false
    fi
    if [ "$clean_ok" = true ]; then
      info "系统清理完成"
    else
      error "系统清理失败"
    fi
  elif command -v yum >/dev/null 2>&1; then
    clean_ok=true
    yum autoremove -y || clean_ok=false
    yum clean all || clean_ok=false
    if command -v journalctl >/dev/null 2>&1; then
      journalctl --vacuum-time=1s || clean_ok=false
      journalctl --vacuum-size=50M || clean_ok=false
    fi
    kernel_packages=$(rpm -q kernel | grep -v "$(uname -r)")
    if [ -n "$kernel_packages" ]; then
      yum remove -y $kernel_packages || clean_ok=false
    fi
    if [ "$clean_ok" = true ]; then
      info "系统清理完成"
    else
      error "系统清理失败"
    fi
  elif command -v dnf >/dev/null 2>&1; then
    clean_ok=true
    dnf autoremove -y || clean_ok=false
    dnf clean all || clean_ok=false
    if command -v journalctl >/dev/null 2>&1; then
      journalctl --vacuum-time=1s || clean_ok=false
      journalctl --vacuum-size=50M || clean_ok=false
    fi
    kernel_packages=$(rpm -q kernel | grep -v "$(uname -r)")
    if [ -n "$kernel_packages" ]; then
      dnf remove -y $kernel_packages || clean_ok=false
    fi
    if [ "$clean_ok" = true ]; then
      info "系统清理完成"
    else
      error "系统清理失败"
    fi
  elif command -v apk >/dev/null 2>&1; then
    clean_ok=true
    apk autoremove -y || clean_ok=false
    apk clean || clean_ok=false
    orphan_packages=$(apk info -e | grep '^r' | awk '{print $1}')
    if [ -n "$orphan_packages" ]; then
      apk del $orphan_packages || clean_ok=false
    fi
    if command -v journalctl >/dev/null 2>&1; then
      journalctl --vacuum-time=1s || clean_ok=false
      journalctl --vacuum-size=50M || clean_ok=false
    fi
    old_kernels=$(apk info -vv | grep -E 'linux-[0-9]' | grep -v "$(uname -r)" \
      | awk '{print $1}')
    if [ -n "$old_kernels" ]; then
      apk del $old_kernels || clean_ok=false
    fi
    if [ "$clean_ok" = true ]; then
      info "系统清理完成"
    else
      error "系统清理失败"
    fi
  elif command -v pacman >/dev/null 2>&1; then
    clean_ok=true
    if pacman -Qtdq >/dev/null 2>&1; then
      pacman -Rns --noconfirm $(pacman -Qtdq 2>/dev/null) || clean_ok=false
    fi
    pacman -Scc --noconfirm || clean_ok=false
    if [ "$clean_ok" = true ]; then
      info "系统清理完成"
    else
      error "系统清理失败"
    fi
  else
    error "暂不支持你的系统！"
    pause_return
    return 1
  fi
  pause_return
  return 0
}

docker_install() {
  if command -v docker >/dev/null 2>&1; then
    warn "Docker 已经安装"
    return 0
  fi
  if ! curl -fsSL https://get.docker.com | sh; then
    error "Docker 安装失败"
    return 1
  fi
  if [ -e /usr/libexec/docker/cli-plugins/docker-compose ]; then
    ln -s /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose || true
  fi
  if command -v systemctl >/dev/null 2>&1; then
    systemctl start docker || true
    systemctl enable docker || true
  fi
  info "Docker 安装完成"
}

docker_show_status() {
  clear
  printf '%s\n' "Docker版本"
  docker --version
  if command -v docker-compose >/dev/null 2>&1; then
    docker-compose --version
  fi
  printf '%s\n' ""
  printf '%s\n' "Docker镜像列表"
  docker image ls
  printf '%s\n' ""
  printf '%s\n' "Docker容器列表"
  docker ps -a
  printf '%s\n' ""
  printf '%s\n' "Docker卷列表"
  docker volume ls
  printf '%s\n' ""
  printf '%s\n' "Docker网络列表"
  docker network ls
  printf '%s\n' ""
}

docker_container_menu() {
  while true; do
    clear
    title_sub "Docker容器管理"
    printf '%s\n' "Docker容器列表"
    docker ps -a
    printf '%s\n' ""
    printf '%s\n' "容器操作"
    printf '%s\n' "------------------------"
    printf '%s\n' " 1. 创建新的容器"
    printf '%s\n' "------------------------"
    printf '%s\n' " 2. 启动指定容器             6. 启动所有容器"
    printf '%s\n' " 3. 停止指定容器             7. 暂停所有容器"
    printf '%s\n' " 4. 删除指定容器             8. 删除所有容器"
    printf '%s\n' " 5. 重启指定容器             9. 重启所有容器"
    printf '%s\n' "------------------------"
    printf '%s\n' "11. 进入指定容器           12. 查看容器日志           13. 查看容器网络"
    printf '%s\n' "------------------------"
    printf '%s\n' "0. 返回上一级选单"
    printf '%s\n' "------------------------"
    printf '%s' "请输入你的选择: "
    read -r sub_choice

    case "$sub_choice" in
      1)
        printf '%s' "请输入创建命令: "
        read -r dockername
        if sh -c "$dockername"; then
          info "容器创建完成"
        else
          error "容器创建失败"
        fi
        pause_return
        ;;
      2)
        printf '%s' "请输入容器名: "
        read -r dockername
        if docker start "$dockername"; then
          info "容器启动完成"
        else
          error "容器启动失败"
        fi
        pause_return
        ;;
      3)
        printf '%s' "请输入容器名: "
        read -r dockername
        if docker stop "$dockername"; then
          info "容器停止完成"
        else
          error "容器停止失败"
        fi
        pause_return
        ;;
      4)
        printf '%s' "请输入容器名: "
        read -r dockername
        if docker rm -f "$dockername"; then
          info "容器删除完成"
        else
          error "容器删除失败"
        fi
        pause_return
        ;;
      5)
        printf '%s' "请输入容器名: "
        read -r dockername
        if docker restart "$dockername"; then
          info "容器重启完成"
        else
          error "容器重启失败"
        fi
        pause_return
        ;;
      6)
        if docker start $(docker ps -a -q); then
          info "容器启动完成"
        else
          error "容器启动失败"
        fi
        pause_return
        ;;
      7)
        if docker stop $(docker ps -q); then
          info "容器停止完成"
        else
          error "容器停止失败"
        fi
        pause_return
        ;;
      8)
        printf '%s' "确定删除所有容器吗？(Y/N): "
        read -r choice
        case "$choice" in
          [Yy])
            if docker rm -f $(docker ps -a -q); then
              info "容器删除完成"
            else
              error "容器删除失败"
            fi
            pause_return
            ;;
        esac
        ;;
      9)
        if docker restart $(docker ps -q); then
          info "容器重启完成"
        else
          error "容器重启失败"
        fi
        pause_return
        ;;
      11)
        printf '%s' "请输入容器名: "
        read -r dockername
        docker exec -it "$dockername" /bin/bash
        pause_return
        ;;
      12)
        printf '%s' "请输入容器名: "
        read -r dockername
        docker logs "$dockername"
        pause_return
        ;;
      13)
        printf '%s\n' ""
        container_ids=$(docker ps -q)
        printf '%s\n' "------------------------------------------------------------"
        printf '%-25s %-25s %-25s\n' "容器名称" "网络名称" "IP地址"
        for container_id in $container_ids; do
          container_info=$(docker inspect --format '{{ .Name }}{{ range $network, $config := .NetworkSettings.Networks }} {{ $network }} {{ $config.IPAddress }}{{ end }}' "$container_id")
          container_name=$(printf '%s' "$container_info" | awk '{print $1}')
          network_info=$(printf '%s' "$container_info" | cut -d' ' -f2-)
          printf '%s\n' "$network_info" | while read -r line; do
            network_name=$(printf '%s' "$line" | awk '{print $1}')
            ip_address=$(printf '%s' "$line" | awk '{print $2}')
            printf '%-20s %-20s %-15s\n' "$container_name" "$network_name" "$ip_address"
          done
        done
        pause_return
        ;;
      0)
        break
        ;;
    esac
  done
}

docker_image_menu() {
  while true; do
    clear
    title_sub "Docker镜像管理"
    printf '%s\n' "Docker镜像列表"
    docker image ls
    printf '%s\n' ""
    printf '%s\n' "镜像操作"
    printf '%s\n' "------------------------"
    printf '%s\n' "1. 获取指定镜像             3. 删除指定镜像"
    printf '%s\n' "2. 更新指定镜像             4. 删除所有镜像"
    printf '%s\n' "------------------------"
    printf '%s\n' "0. 返回上一级选单"
    printf '%s\n' "------------------------"
    printf '%s' "请输入你的选择: "
    read -r sub_choice

    case "$sub_choice" in
      1|2)
        printf '%s' "请输入镜像名: "
        read -r dockername
        if docker pull "$dockername"; then
          info "镜像更新完成"
        else
          error "镜像更新失败"
        fi
        pause_return
        ;;
      3)
        printf '%s' "请输入镜像名: "
        read -r dockername
        if docker rmi -f "$dockername"; then
          info "镜像删除完成"
        else
          error "镜像删除失败"
        fi
        pause_return
        ;;
      4)
        printf '%s' "确定删除所有镜像吗？(Y/N): "
        read -r choice
        case "$choice" in
          [Yy])
            if docker rmi -f $(docker images -q); then
              info "镜像删除完成"
            else
              error "镜像删除失败"
            fi
            pause_return
            ;;
        esac
        ;;
      0)
        break
        ;;
    esac
  done
}

docker_network_menu() {
  while true; do
    clear
    title_sub "Docker网络管理"
    printf '%s\n' "Docker网络列表"
    printf '%s\n' "------------------------------------------------------------"
    docker network ls
    printf '%s\n' ""
    printf '%s\n' "------------------------------------------------------------"
    container_ids=$(docker ps -q)
    printf '%-25s %-25s %-25s\n' "容器名称" "网络名称" "IP地址"
    for container_id in $container_ids; do
      container_info=$(docker inspect --format '{{ .Name }}{{ range $network, $config := .NetworkSettings.Networks }} {{ $network }} {{ $config.IPAddress }}{{ end }}' "$container_id")
      container_name=$(printf '%s' "$container_info" | awk '{print $1}')
      network_info=$(printf '%s' "$container_info" | cut -d' ' -f2-)
      printf '%s\n' "$network_info" | while read -r line; do
        network_name=$(printf '%s' "$line" | awk '{print $1}')
        ip_address=$(printf '%s' "$line" | awk '{print $2}')
        printf '%-20s %-20s %-15s\n' "$container_name" "$network_name" "$ip_address"
      done
    done

    printf '%s\n' ""
    printf '%s\n' "网络操作"
    printf '%s\n' "------------------------"
    printf '%s\n' "1. 创建网络"
    printf '%s\n' "2. 加入网络"
    printf '%s\n' "3. 退出网络"
    printf '%s\n' "4. 删除网络"
    printf '%s\n' "------------------------"
    printf '%s\n' "0. 返回上一级选单"
    printf '%s\n' "------------------------"
    printf '%s' "请输入你的选择: "
    read -r sub_choice

    case "$sub_choice" in
      1)
        printf '%s' "设置新网络名: "
        read -r dockernetwork
        if docker network create "$dockernetwork"; then
          info "网络创建完成"
        else
          error "网络创建失败"
        fi
        pause_return
        ;;
      2)
        printf '%s' "加入网络名: "
        read -r dockernetwork
        printf '%s' "那些容器加入该网络: "
        read -r dockername
        if docker network connect "$dockernetwork" "$dockername"; then
          info "加入网络完成"
        else
          error "加入网络失败"
        fi
        pause_return
        ;;
      3)
        printf '%s' "退出网络名: "
        read -r dockernetwork
        printf '%s' "那些容器退出该网络: "
        read -r dockername
        if docker network disconnect "$dockernetwork" "$dockername"; then
          info "退出网络完成"
        else
          error "退出网络失败"
        fi
        pause_return
        ;;
      4)
        printf '%s' "请输入要删除的网络名: "
        read -r dockernetwork
        if docker network rm "$dockernetwork"; then
          info "网络删除完成"
        else
          error "网络删除失败"
        fi
        pause_return
        ;;
      0)
        break
        ;;
    esac
  done
}

docker_volume_menu() {
  while true; do
    clear
    title_sub "Docker卷管理"
    printf '%s\n' "Docker卷列表"
    docker volume ls
    printf '%s\n' ""
    printf '%s\n' "卷操作"
    printf '%s\n' "------------------------"
    printf '%s\n' "1. 创建新卷"
    printf '%s\n' "2. 删除卷"
    printf '%s\n' "------------------------"
    printf '%s\n' "0. 返回上一级选单"
    printf '%s\n' "------------------------"
    printf '%s' "请输入你的选择: "
    read -r sub_choice

    case "$sub_choice" in
      1)
        printf '%s' "设置新卷名: "
        read -r dockerjuan
        if docker volume create "$dockerjuan"; then
          info "卷创建完成"
        else
          error "卷创建失败"
        fi
        pause_return
        ;;
      2)
        printf '%s' "输入删除卷名: "
        read -r dockerjuan
        if docker volume rm "$dockerjuan"; then
          info "卷删除完成"
        else
          error "卷删除失败"
        fi
        pause_return
        ;;
      0)
        break
        ;;
    esac
  done
}

docker_menu() {
  require_root || return 1

  while true; do
    clear
    title_sub "▶ Docker管理器"
    printf '%s\n' "------------------------"
    printf '%s\n' "1. 安装更新Docker环境"
    printf '%s\n' "------------------------"
    printf '%s\n' "2. 查看Docker全局状态"
    printf '%s\n' "------------------------"
    printf '%-28s %-28s\n' "3. Docker容器管理 ▶" "4. Docker镜像管理 ▶"
    printf '%-28s %-28s\n' "5. Docker网络管理 ▶" "6. Docker卷管理 ▶"
    printf '%s\n' "------------------------"
    printf '%s\n' "7. 清理无用的docker容器和镜像网络数据卷"
    printf '%s\n' "------------------------"
    printf '%b\n' "${COLOR_RED}8. 卸载Docker环境${COLOR_RESET}"
    printf '%s\n' "------------------------"
    printf '%s\n' " 0. 返回主菜单"
    printf '%s\n' "------------------------"
    printf '%s' "请输入你的选择: "
    read -r sub_choice

    case "$sub_choice" in
      1)
        docker_install
        pause_return
        ;;
      2)
        docker_show_status
        pause_return
        ;;
      3)
        docker_container_menu
        ;;
      4)
        docker_image_menu
        ;;
      5)
        docker_network_menu
        ;;
      6)
        docker_volume_menu
        ;;
      7)
        printf '%s' "确定清理无用的镜像容器网络吗？(Y/N): "
        read -r choice
        case "$choice" in
          [Yy])
            if docker system prune -af --volumes; then
              info "Docker 清理完成"
            else
              error "Docker 清理失败"
            fi
            pause_return
            ;;
        esac
        ;;
      8)
        printf '%s' "确定卸载docker环境吗？(Y/N): "
        read -r choice
        case "$choice" in
          [Yy])
            docker rm $(docker ps -a -q) || true
            docker rmi $(docker images -q) || true
            docker network prune -f || true
            if command -v apt >/dev/null 2>&1; then
              apt remove -y docker docker.io docker-ce docker-ce-cli containerd.io || true
            elif command -v yum >/dev/null 2>&1; then
              yum remove -y docker docker-ce docker-ce-cli containerd.io || true
            elif command -v dnf >/dev/null 2>&1; then
              dnf remove -y docker docker-ce docker-ce-cli containerd.io || true
            elif command -v apk >/dev/null 2>&1; then
              apk del docker || true
            elif command -v pacman >/dev/null 2>&1; then
              pacman -Rns --noconfirm docker || true
            fi
            rm -rf /var/lib/docker
            info "Docker 卸载完成"
            pause_return
            ;;
        esac
        ;;
      0)
        break
        ;;
    esac
  done
}

node_menu() {
  while true; do
    clear
    title_sub "节点搭建合集"
    printf '%s\n' "1) argo节点 (快捷命令 argo)"
    printf '%s\n' "2) 233boy/sing-box (快捷命令 sb)"
    printf '%s\n' "3) 233boy/V2Ray (快捷命令 v2ray)"
    printf '%s\n' "4) 233boy/Xray (快捷命令xray)"
    printf '%s\n' "5) Hysteria2 (快捷命令 hy)"
    printf '%s\n' "6) MTProto (快捷命令 mtp)"
    printf '%s\n' "0) 返回上一级"
    printf '%s' "请输入你的选择: "
    read -r sub_choice

    case "$sub_choice" in
      1)
        bash -c "bash <(curl -sL https://raw.githubusercontent.com/LeoJyenn/node/main/argo.sh/argo.sh)"
        pause_return
        ;;
      2)
        bash -c "bash <(wget -qO- -o- https://github.com/233boy/sing-box/raw/main/install.sh)"
        pause_return
        ;;
      3)
        bash -c "bash <(wget -qO- -o- https://github.com/233boy/v2ray/raw/master/install.sh)"
        pause_return
        ;;
      4)
        bash -c "bash <(wget -qO- -o- https://github.com/233boy/Xray/raw/main/install.sh)"
        pause_return
        ;;
      5)
        bash -c "bash <(curl -sL https://raw.githubusercontent.com/LeoJyenn/node/main/Hysteria2.sh/Hysteria2.sh)"
        pause_return
        ;;
      6)
        bash -c "bash <(curl -sL https://raw.githubusercontent.com/LeoJyenn/node/main/MTProto.sh/MTProto.sh)"
        pause_return
        ;;
      0)
        break
        ;;
      *)
        warn "无效选择: $sub_choice"
        pause_return
        ;;
    esac
  done
}

get_remote_version() {
  curl -fsSL https://raw.githubusercontent.com/LeoJyenn/vpstool/main/vpstool.sh \
    | awk -F'"' '/^VERSION=/{print $2; exit}'
}

update_script() {
  require_root || return 1

  update_target=/usr/local/bin/vps
  if [ ! -w "$update_target" ]; then
    error "请先安装到 /usr/local/bin/vps 再更新"
    pause_return
    return 1
  fi

  remote_version=$(get_remote_version || true)
  if [ -z "${remote_version:-}" ]; then
    error "获取远程版本失败。"
    pause_return
    return 1
  fi

  if [ "$remote_version" = "$VERSION" ]; then
    warn "已是最新版本: $VERSION"
    pause_return
    return 0
  fi

  tmp_file=$(mktemp)
  if ! curl -fsSL https://raw.githubusercontent.com/LeoJyenn/vpstool/main/vpstool.sh -o "$tmp_file"; then
    rm -f "$tmp_file"
    error "下载更新失败。"
    pause_return
    return 1
  fi

  if ! grep -q "^VERSION=\"$remote_version\"" "$tmp_file"; then
    rm -f "$tmp_file"
    error "版本校验失败，取消更新。"
    pause_return
    return 1
  fi

  mv "$tmp_file" "$update_target"
  chmod 755 "$update_target"
  info "更新成功: $VERSION -> $remote_version"
  pause_return
}

install_script() {
  require_root || return 1

  install_target=/usr/local/bin/vps
  if ! curl -fsSL https://raw.githubusercontent.com/LeoJyenn/vpstool/main/vpstool.sh -o "$install_target"; then
    error "下载安装失败。"
    pause_return
    return 1
  fi

  chmod 755 "$install_target"
  if [ -x "$install_target" ]; then
    info "安装成功，快捷命令为 vps"
    pause_return
    return 0
  fi

  error "安装失败。"
  pause_return
  return 1
}

uninstall_script() {
  require_root || return 1

  script_path=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/$(basename -- "$0")
  install_target=/usr/local/bin/vps

  if [ -e "$install_target" ]; then
    rm -f "$install_target"
  fi

  if [ -e "$script_path" ]; then
    rm -f "$script_path"
  fi

  info "已卸载脚本。"
  pause_return
}

show_menu() {
  clear
  print_banner
  printf '%s\n' ""
  title_main "功能区"
  printf '%-32s %-32s\n' "1) 系统信息" "2) 系统更新"
  printf '%-32s %-32s\n' "3) 系统清理" "4) Docker管理 ▶"
  printf '%-32s %-32s\n' "5) ip质检" "6) warp (快捷命令warp)"
  printf '%-32s %-32s\n' "7) 流媒体检测" ""
  section
  title_main "合集区"
  printf '%-32s %-32s\n' "a) 节点搭建合集 ▶" ""
  section
  printf '%b' "${COLOR_GREEN}00) 更新脚本${COLOR_RESET}"
  printf '%b\n' "  ${COLOR_RED}88) 卸载脚本${COLOR_RESET}"
  section
  printf '%s\n' "0) 退出"
  printf '%s' "请选择: "
}

run_ip_check() {
  bash -c "bash <(curl -Ls https://Check.Place) -I"
  pause_return
}

run_warp_menu() {
  if command -v wget >/dev/null 2>&1; then
    wget -N https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh \
      && bash menu.sh [option] [lisence/url/token]
  else
    error "未找到 wget，请先安装"
  fi
  pause_return
}

run_media_check() {
  bash -c "bash <(curl -L -s check.unlock.media)"
  pause_return
}

case "${1-}" in
  info)
    run_sysinfo
    exit 0
    ;;
  uninstall)
    uninstall_script
    exit 0
    ;;
  install)
    install_script
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
    error "Unknown command: $1"
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
      update_system
      ;;
    3)
      clean_system
      ;;
    4)
      docker_menu
      ;;
    5)
      run_ip_check
      ;;
    6)
      run_warp_menu
      ;;
    7)
      run_media_check
      ;;
    a)
      node_menu
      ;;
    00)
      update_script
      ;;
    88)
      uninstall_script
      ;;
    0)
      exit 0
      ;;
    *)
      warn "无效选择: $choice"
      pause_return
      ;;
  esac
done
