#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# 检查root权限
[[ $EUID -ne 0 ]] && echo -e "${red}错误: ${plain} 必须使用root用户运行此脚本！\n" && exit 1

# 检查是否已安装
check_install() {
    if [[ ! -f /usr/local/XrayR/XrayR ]]; then
        echo -e "${red}错误: XrayR 后端未安装或路径不正确！${plain}"
        exit 1
    fi
}

# 获取状态
show_status() {
    if [[ ! -f /etc/systemd/system/XrayR.service ]]; then
        echo -e "XrayR状态: ${red}未安装为服务${plain}"
        return
    fi
    
    status=$(systemctl is-active XrayR)
    if [[ "${status}" == "active" ]]; then
        echo -e "XrayR状态: ${green}已运行${plain}"
    else
        echo -e "XrayR状态: ${yellow}未运行${plain}"
    fi
}

# 功能函数
start() {
    check_install
    systemctl start XrayR
    echo "正在启动..." && sleep 1
    show_status
}

stop() {
    check_install
    systemctl stop XrayR
    echo "正在停止..." && sleep 1
    show_status
}

restart() {
    check_install
    systemctl restart XrayR
    echo "正在重启..." && sleep 1
    show_status
}

show_log() {
    check_install
    journalctl -u XrayR.service -e --no-pager -f
}

config() {
    check_install
    vi /etc/XrayR/config.yml
    restart
}

update() {
    bash <(curl -Ls https://raw.githubusercontent.com/Sysrous/dnsmasq_sniproxy_install/refs/heads/master/install.sh)
}

uninstall() {
    systemctl stop XrayR
    systemctl disable XrayR
    rm -f /etc/systemd/system/XrayR.service
    systemctl daemon-reload
    rm -rf /etc/XrayR
    rm -rf /usr/local/XrayR
    rm -f /usr/bin/XrayR
    rm -f /usr/bin/xrayr
    echo -e "${green}XrayR 已成功卸载！${plain}"
}

# 主菜单
show_menu() {
    clear
    echo -e "
  ${green}XrayR 后端管理脚本${plain}
---
  ${green}1.${plain} 启动 XrayR
  ${green}2.${plain} 停止 XrayR
  ${green}3.${plain} 重启 XrayR
---
  ${green}4.${plain} 修改配置 (改完自动重启)
  ${green}5.${plain} 查看日志
---
  ${green}6.${plain} 更新 XrayR (重新执行安装脚本)
  ${green}7.${plain} 卸载 XrayR
---
  ${green}0.${plain} 退出脚本
"
    show_status
    echo && read -p "请输入选择 [0-7]: " num

    case "${num}" in
        1) start ;;
        2) stop ;;
        3) restart ;;
        4) config ;;
        5) show_log ;;
        6) update ;;
        7) uninstall ;;
        0) exit 0 ;;
        *) echo -e "${red}请输入正确的数字 [0-7]${plain}" && sleep 2 && show_menu ;;
    esac
}

# 命令模式
if [[ $# > 0 ]]; then
    case $1 in
        "start") start ;;
        "stop") stop ;;
        "restart") restart ;;
        "log") show_log ;;
        "config") config ;;
        "update") update ;;
        "uninstall") uninstall ;;
        *) echo "无效命令: $1" ;;
    esac
else
    show_menu
fi
