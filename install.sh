#!/bin/bash

VERSION=""
APP_PATH="/usr/local/bin/"
CONFIG_PATH="/usr/local/etc/au/"


create_folders() {
  if [[ ! -e "${APP_PATH}" ]]; then
    mkdir "${APP_PATH}"
  fi
  if [[ ! -e "${CONFIG_PATH}" ]]; then
    mkdir "${CONFIG_PATH}"
  fi

}

panelConfig() {
  echo "Air-Universe $VERSION + Xray"
  echo "########Air-Universe config#######"
  read -r -p "Enter panel domain(Include https:// or http://): " pUrl
  read -r -p "Enter panel token: " nKey
  read -r -p "Enter node_ids, (eg 1,2,3): " nIds
  echo && echo -e "Choose panel type:
  1. SSPanel
  2. V2board
  3. Django-sspanel"
  read -r -p "Choose panel type: " panelnum
  if [ "$panelnum" == "1" ]; then
    panelType="sspanel"
  fi

  if [ "$panelnum" == "2" ]; then
      panelType="v2board"
  fi

  if [ "$panelnum" == "3" ]; then
      panelType="django-sspanel"
  fi

  IFS=', ' read -r -a id_arr <<< "$nIds"

  if [ "$panelnum" == "2" ] || [ "$panelnum" == "3" ]; then
    echo
    echo "Please select node type[0-2]:"
    echo "0. VMess"
    echo "1. ShadowSocks"
    echo "2. Trojan "
    echo

    for id in "${id_arr[@]}"
    do
      while ((1)); do
        read -r -p "Please select node type for id ${id} : " inputNodeType
          if [ "$inputNodeType" == "0"  ]; then
            nType=$nType"\"vmess\","
            break
          elif [ "$inputNodeType" == "1" ]; then
            nType=$nType"\"ss\","
            break
          elif [ "$inputNodeType" == "2" ]; then
            nType=$nType"\"trojan\","
            break
          else
            echo "Input error [0-2]"
          fi
      done

    done
    nType=${nType%?}
  fi
}

check_root() {
  [[ $EUID != 0 ]] && echo -e "${Error} 当前非ROOT账号(或没有ROOT权限)，无法继续操作，请更换ROOT账号或使用 ${Green_background_prefix}sudo su${Font_color_suffix} 命令获取临时ROOT权限（执行后可能会提示输入当前账号的密码）。" && exit 1
}
check_sys() {
  if [[ -f /etc/redhat-release ]]; then
    release="centos"
  elif cat /etc/issue | grep -q -E -i "debian"; then
    release="debian"
  elif cat /etc/issue | grep -q -E -i "ubuntu"; then
    release="ubuntu"
  elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
    release="centos"
  elif cat /proc/version | grep -q -E -i "debian"; then
    release="debian"
  elif cat /proc/version | grep -q -E -i "ubuntu"; then
    release="ubuntu"
  elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
    release="centos"
  fi
  bit=$(uname -m)
}
Installation_dependency() {
  if [[ ${release} == "centos" ]]; then
    yum update -y
    yum install -y gzip ca-certificates curl wget unzip socat
  else
    apt-get update -y
    apt-get install -y ca-certificates curl wget unzip socat
  fi
  cp -f /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
  mkdir /var/log/au
  chown -R nobody /var/log/au
}
download() {
  mkdir /usr/local/etc/au/
  airuniverse_url="https://github.com/crossfw/Air-Universe/releases/download/${VERSION}/Air-Universe-linux-${MACHINE}.zip"
  xray_json_url="https://raw.githubusercontent.com/crossfw/Air-Universe-install/master/xray_config.json"

  mv /usr/local/etc/xray/config.json /usr/local/etc/xray/config.json.bak
  wget -N  ${xray_json_url} -O /usr/local/etc/xray/config.json
  wget -N  ${airuniverse_url} -O ./au.zip
  unzip ./au.zip -d /usr/local/bin/
  rm ./au.zip
  mv /usr/local/bin/Air-Universe /usr/local/bin/au
  chmod +x /usr/local/bin/au

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


get_latest_version() {
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
makeConfig() {
  mkdir -p /usr/lib/systemd/system/
  cat >/usr/local/etc/au/au.json <<EOF
{
  "panel": {
    "type": "${panelType}",
    "url": "${pUrl}",
    "key": "${nKey}",
    "node_ids": [${nIds}],
    "nodes_type": [${nType}]
  },
  "proxy": {
    "type":"xray"
  }
}
EOF
chmod 644 /usr/local/etc/au/au.json
}

createService() {
  service_file="https://raw.githubusercontent.com/crossfw/Air-Universe-install/master/au.service"
  wget -N  -O /etc/systemd/system/au.service ${service_file}
  chmod 644 /etc/systemd/system/au.service
  systemctl daemon-reload
}

check_root
check_sys
Installation_dependency
get_latest_version
identify_the_operating_system_and_architecture
panelConfig
download
makeConfig
createService

systemctl enable au
systemctl restart xray
systemctl start au
