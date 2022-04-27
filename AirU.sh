#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

version="v1.0.0"

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误: ${plain} 必须使用root用户运行此脚本！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [默认$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "是否重启Air-Universe" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}按回车返回主菜单: ${plain}" && read temp
    show_menu
}

install() {
    bash -c "$(curl -L https://github.com/crossfw/Xray-install/raw/main/install-release.sh)" @ install
    bash <(curl -Ls https://raw.githubusercontent.com/crossfw/Air-Universe-install/master/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}
update_xray(){
  bash -c "$(curl -L https://github.com/crossfw/Xray-install/raw/main/install-release.sh)" @ install
  return 0
}
update() {
    if [[ $# == 0 ]]; then
        echo && echo -n -e "输入指定版本(默认最新版): " && read version
    else
        version=$2
    fi
#    confirm "本功能会强制重装当前最新版，数据不会丢失，是否继续?" "n"
#    if [[ $? != 0 ]]; then
#        echo -e "${red}已取消${plain}"
#        if [[ $1 != 0 ]]; then
#            before_show_menu
#        fi
#        return 0
#    fi
    bash <(curl -Ls https://raw.githubusercontent.com/crossfw/Air-Universe-install/master/install.sh) $version
    if [[ $? == 0 ]]; then
        echo -e "${green}更新完成，已自动重启 Air-Universe，请使用菜单页内的查看日志查看运行日志${plain}"
        exit
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

config() {
    cat /usr/local/etc/au/au.json
}

uninstall() {
    confirm "确定要卸载 Air-Universe 吗?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop au
    systemctl disable au
    rm /etc/systemd/system/au.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /usr/local/etc/au/ -rf
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove
    echo ""
    echo -e "卸载成功，如果你想删除此脚本，则退出脚本后运行 ${green}rm /usr/bin/airu -f${plain} 进行删除"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}Air-Universe已运行，无需再次启动，如需重启请选择重启${plain}"
    else
        systemctl start au
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green}Air-Universe 启动成功，请使用查看运行日志${plain}"
        else
            echo -e "${red}Air-Universe可能启动失败，请稍后使用菜单查看日志信息${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    systemctl stop au
    sleep 2
    check_status
    if [[ $? == 1 ]]; then
        echo -e "${green}Air-Universe 停止成功${plain}"
    else
        echo -e "${red}Air-Universe停止失败，可能是因为停止时间超过了两秒，请稍后查看日志信息${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart au
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${green}Air-Universe 重启成功，请使用菜单查看运行日志${plain}"
    else
        echo -e "${red}Air-Universe可能启动失败，请稍后使用菜单查看日志信息${plain}"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status au --no-pager -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable au
    if [[ $? == 0 ]]; then
        echo -e "${green}Air-Universe 设置开机自启成功${plain}"
    else
        echo -e "${red}Air-Universe 设置开机自启失败${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable au
    if [[ $? == 0 ]]; then
        echo -e "${green}Air-Universe 取消开机自启成功${plain}"
    else
        echo -e "${red}Air-Universe 取消开机自启失败${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u au.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

install_bbr() {
    bash <(curl -L -s https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh)
    #if [[ $? == 0 ]]; then
    #    echo ""
    #    echo -e "${green}安装 bbr 成功，请重启服务器${plain}"
    #else
    #    echo ""
    #    echo -e "${red}下载 bbr 安装脚本失败，请检查本机能否连接 Github${plain}"
    #fi

    #before_show_menu
}

update_shell() {
    wget -O /usr/bin/airu -N --no-check-certificate https://raw.githubusercontent.com/crossfw/Air-Universe-install/master/AirU.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red}下载脚本失败，请检查本机能否连接 Github${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/airu
        echo -e "${green}升级脚本成功，请重新运行脚本${plain}" && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/au.service ]]; then
        return 2
    fi
    temp=$(systemctl status au | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled au)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1;
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        echo -e "${red}Air-Universe已安装，请不要重复安装${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        echo -e "${red}请先安装Air-Universe${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

acme() {
  mkdir -p /usr/local/share/au/
  chmod -R 755 /usr/local/share/au
  cert_path="/usr/local/share/au/server.crt"
  key_path="/usr/local/share/au/server.key"
  rm /usr/local/share/au/server.key
  rm /usr/local/share/au/server.crt
  curl  https://get.acme.sh | sh
  alias acme.sh=~/.acme.sh/acme.sh
  source ~/.bashrc
  
  ~/.acme.sh/acme.sh --set-default-ca  --server  letsencrypt
  read -r -p "Input domain: " domain

  echo && echo -e "Choose type:
  1. http
  2. dns (only support cloudflare)"
  read -r -p "Choose type: " issue_type

  if [ "$issue_type" == "1" ]; then
    echo && echo -e "Choose HTTP type:
    1. web path
    2. nginx
    3. apache
    4. use 80 port"
    read -r -p "Choose type: " http_type

    if [ "$http_type" == "1" ]; then
      read -r -p "Input web path: " web_path
      ~/.acme.sh/acme.sh  --issue  -d "${domain}" --webroot  "${web_path}" --fullchain-file "${cert_path}" --key-file "${key_path}" --force
      return 0
    elif [ "$http_type" == "2" ]; then
      ~/.acme.sh/acme.sh  --issue  -d "${domain}" --nginx --fullchain-file "${cert_path}" --key-file "${key_path}" --force
      return 0
    elif [ "$http_type" == "3" ]; then
      read -r -p "Input web path: " web_path
      ~/.acme.sh/acme.sh  --issue  -d "${domain}" --apache --fullchain-file "${cert_path}" --key-file "${key_path}" --force
      return 0
    elif [ "$http_type" == "4" ]; then
      ~/.acme.sh/acme.sh  --issue  -d "${domain}" --standalone --fullchain-file "${cert_path}" --key-file "${key_path}" --force
      return 0
    fi

  fi

  if [ "$issue_type" == "2" ]; then
    echo && echo -e "Choose a DNS provider:
    1. CloudFlare
    2. AliYun
    3. DNSPod(Tencent)"
    read -r -p "Choose: " dns_type

    if [ "$dns_type" == "1" ]; then
      read -r -p "Input your CloudFlare Email: " cf_email
      export CF_Email="${cf_email}"
      read -r -p "Input your CloudFlare Global API Key: " cf_key
      export CF_Key="${cf_key}"

      ~/.acme.sh/acme.sh  --issue  -d "${domain}" --dns dns_cf --fullchain-file "${cert_path}" --key-file "${key_path}" --force
    elif [ "$dns_type" == "2" ]; then
      read -r -p "Input your Ali Key: " Ali_Key
      export Ali_Key="${Ali_Key}"
      read -r -p "Input your Ali Secret: " Ali_Secret
      export Ali_Secret="${Ali_Secret}"

      ~/.acme.sh/acme.sh  --issue  -d "${domain}" --dns dns_ali --fullchain-file "${cert_path}" --key-file "${key_path}" --force
    elif [ "$dns_type" == "3" ]; then
      read -r -p "Input your DNSPod ID: " DP_Id
      export DP_Id="${DP_Id}"
      read -r -p "Input your DNSPod Key: " DP_Key
      export DP_Key="${DP_Key}"

      ~/.acme.sh/acme.sh  --issue  -d "${domain}" --dns dns_dp --fullchain-file "${cert_path}" --key-file "${key_path}" --force
    fi

  fi

  chmod -R 755 /usr/local/share/au/
}

identify_the_operating_system_and_architecture() {
  if [[ "$(uname)" == 'Linux' ]]; then
    case "$(uname -m)" in
      'i386' | 'i686')
        MACHINE='32'
        ;;
      'amd64' | 'x86_64')
        MACHINE='64'
        ;;
      'armv5tel')
        MACHINE='arm32-v5'
        ;;
      'armv6l')
        MACHINE='arm32-v6'
        grep Features /proc/cpuinfo | grep -qw 'vfp' || MACHINE='arm32-v5'
        ;;
      'armv7' | 'armv7l')
        MACHINE='arm32-v7a'
        grep Features /proc/cpuinfo | grep -qw 'vfp' || MACHINE='arm32-v5'
        ;;
      'armv8' | 'aarch64')
        MACHINE='arm64-v8a'
        ;;
      'mips')
        MACHINE='mips32'
        ;;
      'mipsle')
        MACHINE='mips32le'
        ;;
      'mips64')
        MACHINE='mips64'
        ;;
      'mips64le')
        MACHINE='mips64le'
        ;;
      'ppc64')
        MACHINE='ppc64'
        ;;
      'ppc64le')
        MACHINE='ppc64le'
        ;;
      'riscv64')
        MACHINE='riscv64'
        ;;
      's390x')
        MACHINE='s390x'
        ;;
      *)
        echo "error: The architecture is not supported."
        exit 1
        ;;
    esac
    if [[ ! -f '/etc/os-release' ]]; then
      echo "error: Don't use outdated Linux distributions."
      exit 1
    fi
    # Do not combine this judgment condition with the following judgment condition.
    ## Be aware of Linux distribution like Gentoo, which kernel supports switch between Systemd and OpenRC.
    if [[ -f /.dockerenv ]] || grep -q 'docker\|lxc' /proc/1/cgroup && [[ "$(type -P systemctl)" ]]; then
      true
    elif [[ -d /run/systemd/system ]] || grep -q systemd <(ls -l /sbin/init); then
      true
    else
      echo "error: Only Linux distributions using systemd are supported."
      exit 1
    fi
    if [[ "$(type -P apt)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='apt -y --no-install-recommends install'
      PACKAGE_MANAGEMENT_REMOVE='apt purge'
      package_provide_tput='ncurses-bin'
    elif [[ "$(type -P dnf)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='dnf -y install'
      PACKAGE_MANAGEMENT_REMOVE='dnf remove'
      package_provide_tput='ncurses'
    elif [[ "$(type -P yum)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='yum -y install'
      PACKAGE_MANAGEMENT_REMOVE='yum remove'
      package_provide_tput='ncurses'
    elif [[ "$(type -P zypper)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='zypper install -y --no-recommends'
      PACKAGE_MANAGEMENT_REMOVE='zypper remove'
      package_provide_tput='ncurses-utils'
    elif [[ "$(type -P pacman)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='pacman -Syu --noconfirm'
      PACKAGE_MANAGEMENT_REMOVE='pacman -Rsn'
      package_provide_tput='ncurses'
    else
      echo "error: The script does not support the package manager in this operating system."
      exit 1
    fi
  else
    echo "error: This operating system is not supported."
    exit 1
  fi
}

get_latest_au_version() {
  # Get Xray latest release version number
  local tmp_file
  tmp_file="$(mktemp)"
  if ! curl -x "${PROXY}" -sS -H "Accept: application/vnd.github.v3+json" -o "$tmp_file" 'https://api.github.com/repos/crossfw/Air-Universe/releases/latest'; then
    "rm" "$tmp_file"
    echo 'error: Failed to get release list, please check your network.'
    exit 1
  fi
  RELEASE_LATEST="$(sed 'y/,/\n/' "$tmp_file" | grep 'tag_name' | awk -F '"' '{print $4}')"
  if [[ -z "$RELEASE_LATEST" ]]; then
    if grep -q "API rate limit exceeded" "$tmp_file"; then
      echo "error: github API rate limit exceeded"
    else
      echo "error: Failed to get the latest release version."
      echo "Welcome bug report:https://github.com/crossfw/Air-Universe/issues"
    fi
    "rm" "$tmp_file"
    exit 1
  fi
  "rm" "$tmp_file"
  VERSION="v${RELEASE_LATEST#v}"
}

update_au() {
  airuniverse_url="https://github.com/crossfw/Air-Universe/releases/download/${VERSION}/Air-Universe-linux-${MACHINE}.zip"

  wget -N  ${airuniverse_url} -O ./au.zip
  unzip ./au.zip -d /usr/local/bin/
  rm ./au.zip
  rm /usr/local/bin/au
  mv /usr/local/bin/Air-Universe /usr/local/bin/au
  chmod +x /usr/local/bin/au
}

show_status() {
    check_status
    case $? in
        0)
            echo -e "Air-Universe状态: ${green}已运行${plain}"
            show_enable_status
            ;;
        1)
            echo -e "Air-Universe状态: ${yellow}未运行${plain}"
            show_enable_status
            ;;
        2)
            echo -e "Air-Universe状态: ${red}未安装${plain}"
    esac
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "是否开机自启: ${green}是${plain}"
    else
        echo -e "是否开机自启: ${red}否${plain}"
    fi
}

show_Air-Universe_version() {
    echo -n "Air-Universe 版本："
    /usr/local/bin/au -v
    /usr/local/bin/xray -v
    echo ""
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

open_xray_config(){
  echo "如遇报错请安装vi"
  vi /usr/local/etc/xray/config.json
}

open_au_config(){
  echo "如遇报错请安装vi"
  vi  /usr/local/etc/au/au.json
}

show_usage() {
    echo "Air-Universe 管理脚本使用方法: "
    echo "------------------------------------------"
    echo "Air-Universe              - 显示管理菜单 (功能更多)"
    echo "Air-Universe start        - 启动 Air-Universe"
    echo "Air-Universe stop         - 停止 Air-Universe"
    echo "Air-Universe restart      - 重启 Air-Universe"
    echo "Air-Universe status       - 查看 Air-Universe 状态"
    echo "Air-Universe enable       - 设置 Air-Universe 开机自启"
    echo "Air-Universe disable      - 取消 Air-Universe 开机自启"
    echo "Air-Universe log          - 查看 Air-Universe 日志"
    echo "Air-Universe update x.x.x - 更新 Air-Universe 指定版本"
    echo "Air-Universe install      - 安装 Air-Universe"
    echo "Air-Universe uninstall    - 卸载 Air-Universe"
    echo "Air-Universe version      - 查看 Air-Universe 版本"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}Air-Universe 后端管理脚本，${plain}${red}不适用于docker${plain}
--- https://github.com/crossfw/Air-Universe ---
  ${green}0.${plain} 退出脚本
————————————————
  ${green}1.${plain} 安装 Air-Universe
  ${green}2.${plain} 使用ACME获取SSL证书
  ${green}3.${plain} 卸载 Air-Universe
————————————————
  ${green}4.${plain} 启动 Air-Universe
  ${green}5.${plain} 停止 Air-Universe
  ${green}6.${plain} 重启 Air-Universe
  ${green}7.${plain} 查看 Air-Universe 状态
  ${green}8.${plain} 查看 Air-Universe 日志
————————————————
  ${green}9.${plain} 设置 Air-Universe 开机自启
 ${green}10.${plain} 取消 Air-Universe 开机自启
————————————————
 ${green}11.${plain} 一键安装 bbr (最新内核)
 ${green}12.${plain} 查看 Air-Universe & Xray 版本
 ${green}13.${plain} 升级Xray内核
 ${green}14.${plain} 升级Air-Universe
 ————————————————
 ${green}15.${plain} 编辑Xray配置文件
 ${green}16.${plain} 编辑Air-Universe配置文件
 "
 #后续更新可加入上方字符串中
    show_status
    echo && read -p "请输入选择 [0-16]: " num

    case "${num}" in
        0) exit 0
        ;;
        1) check_uninstall && install
        ;;
        2) check_install && acme && restart
        ;;
        3) check_install && uninstall
        ;;
        4) check_install && start
        ;;
        5) check_install && stop
        ;;
        6) check_install && restart
        ;;
        7) check_install && status
        ;;
        8) check_install && show_log
        ;;
        9) check_install && enable
        ;;
        10) check_install && disable
        ;;
        11) install_bbr
        ;;
        12) check_install && show_Air-Universe_version
        ;;
        13) check_install && update_xray && restart
        ;;
        14) check_install && identify_the_operating_system_and_architecture && get_latest_au_version && update_au && restart
        ;;
        15) check_install && open_xray_config
        ;;
        16) check_install && open_au_config
        ;;
        *) echo -e "${red}请输入正确的数字 [0-16]${plain}"
        ;;
    esac
}


if [[ $# > 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0
        ;;
        "stop") check_install 0 && stop 0
        ;;
        "restart") check_install 0 && restart 0
        ;;
        "status") check_install 0 && status 0
        ;;
        "enable") check_install 0 && enable 0
        ;;
        "disable") check_install 0 && disable 0
        ;;
        "log") check_install 0 && show_log 0
        ;;
        "update") check_install 0 && update 0 $2
        ;;
        "config") config $*
        ;;
        "install") check_uninstall 0 && install 0
        ;;
        "uninstall") check_install 0 && uninstall 0
        ;;
        "version") check_install 0 && show_Air-Universe_version 0
        ;;
        "update_shell") update_shell
        ;;
        *) show_usage
    esac
else
    show_menu
fi
