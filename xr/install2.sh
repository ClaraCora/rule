#!/bin/bash

#=================================================
#               日志和颜色定义
#=================================================
Green="\033[32m"
Red="\033[31m"
Yellow='\033[33m'
Blue='\033[34m'
Font="\033[0m"
INFO_PREFIX="[${Green}INFO${Font}]"
ERROR_PREFIX="[${Red}ERROR${Font}]"
WARN_PREFIX="[${Yellow}WARN${Font}]"
BLUE_PREFIX="[${Blue}BLUE${Font}]"

function INFO() {
    echo -e "${INFO_PREFIX} ${1}" >&2
}
function ERROR() {
    echo -e "${ERROR_PREFIX} ${1}" >&2
}
function WARN() {
    echo -e "${WARN_PREFIX} ${1}" >&2
}
function DEBUG() {
    if [[ "$DEBUG_MODE" == "true" ]]; then
        echo -e "${BLUE_PREFIX} ${1}" >&2
    fi
}


#=================================================
#               全局变量
#=================================================
# 如果任何命令失败，立即退出脚本
set -e

cur_dir=$(pwd)

# 安装模式: install / update-config / update-geo / update-core
INSTALL_MODE="install"
# 全局 github token；会被各部分覆盖
GITHUB_TOKEN=""
# 是否需要安装 acme
IS_ACME=false
# 调试模式
DEBUG_MODE=false

#================
# XrayR 仓库信息
#================
# XrayR 仓库
XRAYR_REPO_URL=""
# XrayR 仓库访问令牌
XRAYR_TOKEN=""
# XrayR 版本标签
XRAYR_RELEASE_TAG="latest"
# 强制指定下载的 release 文件名（覆盖自动识别），例如: XrayR-linux-64.zip
XRAYR_ASSET_NAME_OVERRIDE=""
# 自定义下载地址：可以是完整 zip URL，或目录 URL（会自动拼接文件名）
XRAYR_DOWNLOAD_URL=""
# XrayR 安装路径
XRAYR_BIN_DIR="/usr/local/XrayR"

#================
# 配置文件仓库信息
#================
# 配置文件仓库访问令牌
CONFIG_REPO_URL=""
# 配置文件仓库访问令牌
CONFIG_TOKEN=""
# XrayR 配置文件路径
CONFIG_DIR="/etc/XrayR"
# 忽略更新的配置文件列表
CONFIG_IGNORE_FILES=()
# 仅更新指定的配置文件列表
CONFIG_ONLY_FILES=()

#================
# geoip 与 geosite 的仓库地址
#================
# geo 内置默认公开库
GEO_REPO_URL="https://github.com/MetaCubeX/meta-rules-dat"
# geo 仓库访问令牌
GEO_TOKEN=""
# geo 版本标签
GEO_RELEASE_TAG="latest"

BRANCH="main"


#=================================================
#               函数定义
#=================================================

# 打印用法提示
function print_usage() {
    echo "用法: $0 [options]"
    echo "选项:"
    echo "  -m; --mode                  可选, 安装模式, 可选值: install(安装，全局执行)、 update-core、update-config(仅更新配置文件)、 update-geo(仅更新 geoip 与 geosite.dat); 默认: ${INSTALL_MODE}"
    echo "  -t; --token                 可选, 全局 GitHub 仓库访问令牌，用于访问私有仓库或增加 API 限额（不会回显）; 当有更具体的仓库 token 参数时，优先使用具体的仓库 token"
    echo "  -a; --acme                  可选, 设置为 true 则安装 acme.sh 与 安装带证书认证的 XrayR, 用于自动申请 TLS 证书，默认: ${IS_ACME}"
    echo "  -d; --debug                 可选, 启用调试模式，输出更详细的日志"
    echo "  -h; --help                  显示此帮助信息"
    echo ""
    echo "  xrayr:"
    echo "  -rr; --xrayr-repo           必选, XrayR 仓库地址 (例如: https://github.com/owner/repo 或 git@github.com:owner/repo.git), 默认: ${XRAYR_REPO_URL:-未设置}"
    echo "  -rt; --xrayr-token          可选, XrayR GitHub 仓库访问令牌，用于访问私有仓库或增加 API 限额（不会回显）"
    echo "  -rv; --xrayr-version        可选, 指定要安装的版本，默认: ${XRAYR_RELEASE_TAG}，可选值: latest 或具体版本号 (例如: v0.10.0 或 0.10.0)"
    echo "  -rp; --xrayr-install-path   可选; 安装路径, 默认: ${XRAYR_BIN_DIR:-未设置}"
    echo "  -ra; --xrayr-asset          可选, 强制指定下载的 Release 文件名（覆盖自动识别），例如: XrayR-linux-64.zip"
    echo "  -ru; --xrayr-url            可选, 自定义下载地址（HTTP/HTTPS）。可为完整 zip URL，或目录 URL（会自动拼接文件名）"
    echo ""
    echo " config:"
    echo "  -cr; --config-repo          可选, 配置文件仓库地址 (例如: https://github.com/owner/repo 或 git@github.com:owner/repo.git), 默认不使用外部配置仓库"
    echo "  -ct; --config-token         可选, 配置文件仓库访问令牌，用于访问私有仓库或增加 API 限额（不会回显）"
    echo "  -cp; --config-install-path  可选, 配置文件路径, 默认: ${CONFIG_DIR:-未设置}"
    echo "  -ci; --config-ignore        可选, 是否忽略部分配置文件的更新；支持多个值，用逗号分隔，例如: file1.yml,file2.yml"
    echo "  -co; --config-only          可选, 仅更新指定的配置文件；支持多个值，用逗号分隔，例如: file1.yml,file2.yml"
    echo ""
    echo "  geo:"
    echo "  -gr; --geo-repo             可选, geoip 与 geosite.dat 仓库地址, 默认: ${GEO_REPO_URL}"
    echo "  -gt; --geo-token            可选, 暂时仅支持公开库; geoip 与 geosite.dat 仓库访问令牌，用于访问私有仓库或增加 API 限额（不会回显）"
    echo ""
    echo "示例: $0 --xrayr-repo https://github.com/you/YourFork --xrayr-token ghp_xxx"
}

# 解析 XrayR 仓库 URL
# 输出:
#   - 设置全局变量 OWNER, REPO
function parse_xrayr_repo_url() {
    if [[ -z "$XRAYR_REPO_URL" ]]; then
        ERROR "XrayR 仓库地址 (XRAYR_REPO_URL) 不能为空。"
        exit 1
    fi

    # 移除 .git 后缀并统一处理
    local url=${XRAYR_REPO_URL%.git}

    if [[ $url =~ https?://[^/]+/([^/]+)/([^/]+) ]]; then
        OWNER="${BASH_REMATCH[1]}"
        REPO="${BASH_REMATCH[2]}"
    elif [[ $url =~ git@([^:]+):([^/]+)/([^/]+) ]]; then
        OWNER="${BASH_REMATCH[2]}"
        REPO="${BASH_REMATCH[3]}"
    else
        ERROR "无法解析 XrayR 仓库 URL: $XRAYR_REPO_URL"
        exit 1
    fi

    DEBUG "解析 XrayR 仓库: ${OWNER}/${REPO}"
}

# 构建 GitHub API 请求的认证头
# 功能:
#   1. 根据传入的 token 类型，优先选择特定的 token。
#   2. 如果特定 token 不存在，则回退到全局 GITHUB_TOKEN。
#   3. 将结果存入全局数组变量 auth_header_args 中。
# 参数:
#   $1 - Token 类型 (可选), 例如: "xrayr", "config", "geo"。
function build_auth_header() {
    local token_type="$1"
    local specific_token=""

    # 根据类型选择特定的 token
    case "$token_type" in
        xrayr)
            specific_token="$XRAYR_TOKEN"
            ;;
        config)
            specific_token="$CONFIG_TOKEN"
            ;;
        geo)
            specific_token="$GEO_TOKEN"
            ;;
        *)
            specific_token=""
            ;;
    esac

    # 重置全局数组
    auth_header_args=()

    # 优先使用传入的特定 token
    if [[ -n "$specific_token" ]]; then
        auth_header_args=(-H "Authorization: Bearer $specific_token")
    # 如果没有特定 token，则使用全局的 GITHUB_TOKEN
    elif [[ -n "$GITHUB_TOKEN" ]]; then
        auth_header_args=(-H "Authorization: Bearer $GITHUB_TOKEN")
    fi
    # 如果都没有，auth_header_args 将保持为空数组，curl 会发送无认证的请求
}

# 通用下载函数
# 功能:
#   1. 使用 curl 下载指定 URL 的文件。
#   2. 支持可选的 GitHub 访问令牌进行认证。
# 参数:
#   $1 - 下载链接 URL。
#   $2 - 输出文件路径。
#   $3 - 可选的 GitHub 访问令牌类型。
function download_file() {
    local url="$1"
    local out="$2"
    local token_type="$3"
    build_auth_header "$token_type"

    DEBUG "准备下载 $url 到 $out"

    # 对 GitHub API 的 release assets 下载需要 application/octet-stream；
    # 对普通直链/镜像地址则不强制设置该 Accept，避免某些源不兼容。
    local accept_args=()
    if [[ "$url" =~ ^https://api\.github\.com/ ]] || [[ "$url" =~ /releases/assets/ ]]; then
        accept_args=(-H "Accept: application/octet-stream")
    fi

    # 直接检查 curl 的退出码，-f 选项会处理HTTP错误
    if ! curl -fsSL "${accept_args[@]}" "${auth_header_args[@]}" -o "$out" "$url"; then
        ERROR "文件下载失败: $url"
        exit 1
    fi

    # 检查文件是否为空
    if [[ ! -s "$out" ]]; then
        ERROR "文件下载失败: $out 为空。"
        rm -f "$out" # 清理空文件
        exit 1
    fi
    DEBUG "文件下载成功: $out"
}

# 检查操作系统和架构
# 功能:
#   1. 检测当前的操作系统 (Linux, macOS, Windows 等)。
#   2. 检测当前的 CPU 架构 (x86_64, arm64, mips 等)。
#   3. 将检测结果映射为与 GitHub Release 文件名相匹配的后缀。
#
# 输出:
#   - 设置全局变量 OS_NAME: 例如 "linux", "macos", "windows"。
#   - 设置全局变量 ARCH_SUFFIX: 例如 "64", "arm64-v8a", "mips32le"。
function check_os_arch() {
    # 使用 uname 获取操作系统和架构信息，这是最标准、最可移植的方法
    local os
    local arch
    os=$(uname -s)
    arch=$(uname -m)

    # 1. 判断操作系统 (OS)
    case "$os" in
        Linux)
            if [[ -n "$PREFIX" ]] && [[ "$PREFIX" == *com.termux* ]]; then
                OS_NAME="android"
            else
                OS_NAME="linux"
            fi
            ;;
        Darwin)
            OS_NAME="macos"
            ;;
        FreeBSD)
            OS_NAME="freebsd"
            ;;
        OpenBSD)
            OS_NAME="openbsd"
            ;;
        DragonFly)
            OS_NAME="dragonfly"
            ;;
        # 识别在 Windows 上运行的 shell 环境 (如 Git Bash, Cygwin)
        *CYGWIN*|*MINGW*|*MSYS*)
            OS_NAME="windows"
            ;;
        *)
            ERROR "不支持的操作系统: $os"
            WARN "本脚本仅支持 Linux, Android, macOS, Windows, FreeBSD, OpenBSD, DragonFly BSD。"
            exit 1
            ;;
    esac

    # 2. 判断 CPU 架构并映射为文件名后缀
    case "$arch" in
        x86_64|amd64)
            ARCH_SUFFIX="64"
            ;;
        i[3-6]86|x86)
            ARCH_SUFFIX="32"
            ;;
        aarch64|arm64|armv8*)
            # 苹果 M 系列芯片和很多现代 ARM 服务器/设备都是这个架构
            ARCH_SUFFIX="arm64-v8a"
            ;;
        armv7*)
            ARCH_SUFFIX="arm32-v7a"
            ;;
        armv6*)
            ARCH_SUFFIX="arm32-v6"
            ;;
        armv5*)
            ARCH_SUFFIX="arm32-v5"
            ;;
        mips64le)
            ARCH_SUFFIX="mips64le"
            ;;
        mips64)
            ARCH_SUFFIX="mips64"
            ;;
        mipsle)
            # mipsle 通常指 32 位小端
            ARCH_SUFFIX="mips32le"
            ;;
        mips)
            # mips 通常指 32 位大端
            ARCH_SUFFIX="mips32"
            ;;
        ppc64le)
            ARCH_SUFFIX="ppc64le"
            ;;
        PPC64)
            ARCH_SUFFIX="ppc64"
            ;;
        riscv64)
            ARCH_SUFFIX="riscv64"
            ;;
        s390x)
            ARCH_SUFFIX="s390x"
            ;;
        *)
            ERROR "不支持的 CPU 架构: $arch"
            WARN "无法自动匹配对应的发布文件，请从 Release 页面手动下载。"
            exit 1
            ;;
    esac

    DEBUG "检测到系统: ${OS_NAME}"
    DEBUG "检测到架构: ${arch} -> 映射为: ${ARCH_SUFFIX}"
}

# 将路径转换为绝对路径的跨平台函数
# 输入: 相对路径或绝对路径
# 输出: 绝对路径
function get_absolute_path() {
    local path_to_resolve="$1"
    # 使用 case 语句检查路径是否以 "/" 开头
    case "$path_to_resolve" in
        /*)
            # 如果是，它已经是绝对路径
            echo "$path_to_resolve"
            ;;
        *)
            # 如果不是，将当前工作目录和相对路径拼接起来
            # 注意：不使用 readlink -f，以确保跨平台兼容性
            echo "$(pwd)/$path_to_resolve"
            ;;
    esac
}

# 覆写 配置文件 安装路径
function set_config_install_path() {
    # 如果用户手动指定了配置文件路径，则使用用户指定的路径
    if [[ -n "$CONFIG_DIR" ]]; then
        # 规范化路径，将相对路径转换为绝对路径，避免后续操作出错
        CONFIG_DIR="$(get_absolute_path "$CONFIG_DIR")"
    else
        CONFIG_DIR="/etc/XrayR"
    fi
}

# 覆写 XrayR 安装路径
function set_xrayr_install_path() {
    # 为 MANAGE_SCRIPT_PATH 设置平台默认值
    if [[ "$OS_NAME" == "android" ]]; then
        MANAGE_SCRIPT_PATH="$PREFIX/bin/XrayR"
    else
        MANAGE_SCRIPT_PATH="/usr/bin/XrayR"
    fi

    # 然后，只处理 XRAYR_BIN_DIR
    # 注意：此时 $XRAYR_BIN_DIR 的值要么是全局默认，要么是用户通过 -rp 传入的
    if [[ -n "$XRAYR_BIN_DIR" ]]; then
        # 规范化路径，将相对路径转换为绝对路径
        XRAYR_BIN_DIR="$(get_absolute_path "$XRAYR_BIN_DIR")"
    
    # 仅当用户未指定 -rp 时，才应用 Android 的特殊默认路径
    elif [[ "$OS_NAME" == "android" ]]; then
        XRAYR_BIN_DIR="$PREFIX/usr/local/XrayR"
    fi
    # 如果用户未提供 -rp 且不是 android，XRAYR_BIN_DIR 会保持其全局默认值 /usr/local/XrayR
}

# 覆写 XrayR 下载文件名
function set_xrayr_asset_name() {
    # 如果用户通过参数强制指定了下载文件名，则直接使用
    if [[ -n "$XRAYR_ASSET_NAME_OVERRIDE" ]]; then
        ASSET_NAME="$XRAYR_ASSET_NAME_OVERRIDE"
        INFO "强制指定目标下载文件: ${ASSET_NAME}"
        return 0
    fi

    if [[ "$IS_ACME" == "true" ]]; then
        ASSET_NAME="XrayR-acme-${OS_NAME}-${ARCH_SUFFIX}.zip"
        INFO "目标下载文件 (acme 版本): ${ASSET_NAME}"
    else
        ASSET_NAME="XrayR-${OS_NAME}-${ARCH_SUFFIX}.zip"
        INFO "目标下载文件: ${ASSET_NAME}"
    fi
}

# 安装基础依赖 
# 跨平台自动安装
# 功能:
#   1. 检查必需的命令行工具。
#   2. 如果缺失，则自动检测当前平台的包管理器并尝试安装。
#   3. 如果无法自动安装，则打印指导信息并退出。
function install_dependencies() {
    INFO "正在检查并安装基础依赖..."

    # 定义所有必需的依赖项
    local required_deps=(curl unzip tar socat jq)
    # 根据不同系统，cron 的包名可能不同
    if [[ "$OS_NAME" == "linux" ]]; then
        # 在 CentOS/RHEL 上，包名是 crontabs
        if command -v yum &> /dev/null || command -v dnf &> /dev/null; then
            required_deps+=(crontabs)
        else
            required_deps+=(cron)
        fi
    fi
    
    local missing_deps=()
    local dep
    for dep in "${required_deps[@]}"; do
        # 对于 crontabs，我们检查 crontab 命令是否存在
        local check_cmd="$dep"
        if [[ "$dep" == "crontabs" ]]; then
            check_cmd="crontab"
        fi

        if ! command -v "$check_cmd" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    # 如果没有缺失的依赖，则直接返回成功
    if [ ${#missing_deps[@]} -eq 0 ]; then
        INFO "所有基础依赖均已满足。"
        return 0
    fi

    INFO "检测到以下依赖项缺失，将尝试自动安装: ${missing_deps[*]}"

    # 根据 OS_NAME 和包管理器执行安装命令
    # 使用 sudo 检测用户是否需要提权
    local sudo_cmd=""
    if [[ $EUID -ne 0 ]] && command -v sudo &> /dev/null; then
        sudo_cmd="sudo"
    fi

    case "$OS_NAME" in
        linux)
            if command -v apt &> /dev/null; then
                INFO "检测到 apt 包管理器 (Debian/Ubuntu)，正在更新并安装..."
                $sudo_cmd apt-get update
                $sudo_cmd apt-get install -y "${missing_deps[@]}"
            elif command -v apk &> /dev/null; then
                INFO "检测到 apk (Alpine Linux)，正在更新并安装..."
                $sudo_cmd apk update
                $sudo_cmd apk add "${missing_deps[@]}"
            elif command -v dnf &> /dev/null; then
                INFO "检测到 dnf 包管理器 (Fedora/RHEL 8+)，正在安装..."
                $sudo_cmd dnf install -y "${missing_deps[@]}"
            elif command -v yum &> /dev/null; then
                INFO "检测到 yum 包管理器 (CentOS 7)，正在安装..."
                # CentOS 7 需要 epel-release 来安装某些包
                $sudo_cmd yum install -y epel-release
                $sudo_cmd yum install -y "${missing_deps[@]}"
            elif command -v pacman &> /dev/null; then
                INFO "检测到 pacman 包管理器 (Arch Linux)，正在安装..."
                $sudo_cmd pacman -S --noconfirm "${missing_deps[@]}"
            elif command -v zypper &> /dev/null; then
                INFO "检测到 zypper (SUSE/openSUSE)，正在安装..."
                # zypper 的 -n 选项等同于 -y
                $sudo_cmd zypper install -n "${missing_deps[@]}"
            else
                ERROR "无法检测到您的 Linux 包管理器 (apt, dnf, yum, pacman, apk)。"
                WARN "请手动安装缺失的依赖: ${missing_deps[*]}"
                exit 1
            fi
            ;;
        macos)
            if command -v brew &> /dev/null; then
                INFO "检测到 Homebrew，正在安装..."
                brew install "${missing_deps[@]}"
            else
                ERROR "在 macOS 上需要 Homebrew 来自动安装依赖。"
                WARN "请先访问 https://brew.sh 安装 Homebrew，或手动安装: ${missing_deps[*]}"
                exit 1
            fi
            ;;
        freebsd|dragonfly) 
            INFO "检测到 pkg 包管理器 (FreeBSD/DragonFly)，正在安装..."
            $sudo_cmd pkg install -y "${missing_deps[@]}"
            ;;
        openbsd)
            INFO "检测到 pkg_add 包管理器 (OpenBSD)，正在安装..."
            # 在 OpenBSD 上，doas 是更常见的提权工具
            local doas_cmd=""
            if [[ $EUID -ne 0 ]] && command -v doas &> /dev/null; then
                doas_cmd="doas"
            elif [[ $EUID -ne 0 ]] && command -v sudo &> /dev/null; then
                # 也兼容 sudo
                doas_cmd="sudo"
            fi
            # pkg_add 不支持一次性安装多个包，需要循环
            local dep
            for dep in "${missing_deps[@]}"; do
                $doas_cmd pkg_add "$dep"
            done
            ;;
        android)
            INFO "检测到 Termux 环境 (Android)，正在安装..."
            # Termux 的 pkg 不需要 sudo
            pkg install -y "${missing_deps[@]}"
            ;;
        windows|*) # 将 windows 和所有其他未知情况都归入这里
            ERROR "无法在此操作系统 (${OS_NAME}) 上自动安装依赖。"
            WARN "请手动安装缺失的依赖项: ${missing_deps[*]}"
            exit 1
            ;;
    esac

    # 最后再次检查，确保所有依赖都已成功安装
    local final_missing_deps=()
    for dep in "${required_deps[@]}"; do
        local check_cmd="$dep"
        if [[ "$dep" == "crontabs" ]]; then
            check_cmd="crontab"
        fi
        if ! command -v "$check_cmd" &> /dev/null; then
            final_missing_deps+=("$dep")
        fi
    done

    if [ ${#final_missing_deps[@]} -gt 0 ]; then
        ERROR "自动安装后，以下依赖项仍然缺失: ${final_missing_deps[*]}"
        WARN "请检查上面的安装日志，并尝试手动安装。"
        exit 1
    fi

    INFO "所有基础依赖已成功安装。"
}

# 检查 XrayR 运行状态
# 通过检查 PID 文件来确定服务是否正在运行
# 输出:
#   返回值:
#     0 - 运行中
#     1 - 未运行
#     2 - 未安装
# 注意:
#   该函数假设 XrayR 在不同系统上的 PID 文件位置如下:
#     - Linux: /run/xrayr.pid
#     - macOS: /var/run/xrayr.pid
#     - FreeBSD: /var/run/xrayr.pid
#     - OpenBSD: /var/run/xrayr.pid
#     - Android (Termux): /data/data/com.termux/files/usr/var/run/xrayr.pid
#     - Windows: 由于 Windows 不使用 PID 文件，此函数将始终返回 2 (未安装)
#     - 如果需要支持其他系统，请根据实际情况调整 PID 文件路径。
function check_status_cross_platform() {
    case "$OS_NAME" in
        linux)
            if command -v systemctl &> /dev/null; then
                systemctl is-active --quiet XrayR
            elif command -v rc-service &> /dev/null; then
                rc-service xrayr status
            else
                # 作为最后的备用方案，检查 PID
                [ -f "/run/xrayr.pid" ] && ps -p "$(cat "/run/xrayr.pid")" > /dev/null
            fi
            ;;
        macos)
            # 检查 launchd 服务是否已加载并正在运行
            # grep 的 -q 选项使它在找到匹配项后立即以状态 0 退出
            launchctl list | grep -q "com.xrayr"
            ;;
        freebsd|dragonfly)
            # 使用 service 命令检查状态
            service xrayr status 
            ;;
        openbsd)
            # 使用 rcctl 命令检查状态
            rcctl check xrayr
            ;;
        android)
            # 使用 sv 命令检查状态
            sv status xrayr | grep -q "^run:"
            ;;
        *)
            # 对于未知系统，无法检查，默认返回失败
            return 1
            ;;
    esac
}

# 安装 acme.sh
function install_acme() {
    # 检查 IS_ACME 变量是否为 "true"
    if [[ "$IS_ACME" == "true" ]]; then
        # 如果为 true，则执行安装流程
        INFO "检测到 IS_ACME=true, 正在安装 acme.sh..."
        if ! curl https://get.acme.sh | sh; then
            ERROR "acme.sh 安装失败。"
            exit 1
        fi
        INFO "acme.sh 安装成功。"
    else
        # 如果不为 true（包括为空或为其他任何值），则打印信息并跳过安装
        INFO "检测到 IS_ACME 不为 true, 跳过安装 acme.sh。"
    fi
}

# 下载 geoip.dat 与 geosite.dat (暂时仅支持公开库)
function install_geo() {
    INFO "开始下载/更新 geoip 与 geosite.dat..."
    mkdir -p "$CONFIG_DIR"
    local geoip_url="${GEO_REPO_URL}/releases/latest/download/geoip.dat"
    local geosite_url="${GEO_REPO_URL}/releases/latest/download/geosite.dat"
    local geoip_out="$CONFIG_DIR/geoip.dat"
    local geosite_out="$CONFIG_DIR/geosite.dat"

    download_file "$geoip_url" "$geoip_out" "geo"
    download_file "$geosite_url" "$geosite_out" "geo"
    INFO "geoip.dat 与 geosite.dat 下载/更新完成。"
}

# 获取 release 资源下载链接
function get_release_asset_url() {
    local asset_name="$1"
    local api_endpoint_url
    
    # 1. 根据 TAG 决定 API 端点
    if [[ "$XRAYR_RELEASE_TAG" == "latest" ]]; then
        DEBUG "正在获取最新 (latest) release 的信息..."
        api_endpoint_url="https://api.github.com/repos/$OWNER/$REPO/releases/latest"
    else
        DEBUG "正在获取标签为 '$XRAYR_RELEASE_TAG' 的 release 信息..."
        api_endpoint_url="https://api.github.com/repos/$OWNER/$REPO/releases/tags/$XRAYR_RELEASE_TAG"
    fi
    DEBUG "API 端点: $api_endpoint_url"

    # 指定 token 类型为 "xrayr"
    build_auth_header "xrayr"

    # 2. 获取 API 响应
    local req_json
    req_json=$(curl -sSL \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "${auth_header_args[@]}" \
        "$api_endpoint_url")

    DEBUG "收到的 Release API 响应: $req_json"

    # 3. 验证 API 响应
    if echo "$req_json" | grep -q -E '"message":|"Not Found"|"error"'; then
        ERROR "从 GitHub API 收到了错误的响应。"
        WARN "-------------------- API 响应内容 --------------------"
        WARN "$req_json"
        WARN "------------------------------------------------------"
        ERROR "请检查你的 XRAYR_TOKEN 权限以及 仓库地址 是否正确。"
        exit 1
    fi

    # 4. 解析下载链接
    local download_url # 使用局部变量
    download_url=$(echo "$req_json" | jq -r ".assets[] | select(.name == \"$asset_name\") | .url")

    # 5. 验证解析结果
    if [[ -z "$download_url" || "$download_url" == "null" ]]; then
        ERROR "在 API 响应中未能找到名为 '$asset_name' 的文件链接。"
        WARN "-------------------- 可用的文件列表 --------------------"
        # 打印所有可用的文件名，方便用户排查错误
        echo "$req_json" | jq -r '.assets[] | .name'
        WARN "------------------------------------------------------"
        exit 1
    fi
    echo "$download_url" # 返回下载链接
}

# 下载并解压 XrayR
function download_and_extract_xrayr() {
    INFO "开始安装 XrayR 版本: ${XRAYR_RELEASE_TAG} (文件: ${ASSET_NAME})..."
    
    # 准备临时目录
    local tmp_dir="$XRAYR_BIN_DIR/tmp"
    rm -rf "$tmp_dir"
    mkdir -p "$tmp_dir"
    
    local download_url
    if [[ -n "$XRAYR_DOWNLOAD_URL" ]]; then
        # 支持两种写法：
        # 1) 传入完整 zip URL，例如 https://example.com/XrayR-linux-64.zip
        # 2) 传入目录 URL，例如 https://mirror.example.com/xrayr/ （会自动拼接文件名）
        if [[ "$XRAYR_DOWNLOAD_URL" =~ \.zip($|\?) ]]; then
            download_url="$XRAYR_DOWNLOAD_URL"
        else
            download_url="${XRAYR_DOWNLOAD_URL%/}/$ASSET_NAME"
        fi
        INFO "使用自定义下载地址: $download_url"
    else
        download_url=$(get_release_asset_url "$ASSET_NAME")
    fi
    if [[ -z "$download_url" ]]; then
        ERROR "获取下载链接失败。"
        exit 1
    fi
    DEBUG "成功获取下载链接: $download_url"

    # 下载文件到指定路径
    local zip_path="${XRAYR_BIN_DIR}/${ASSET_NAME}"
    download_file "$download_url" "$zip_path" "xrayr"

    # 解压到临时目录
    if ! unzip -o "$zip_path" -d "$tmp_dir"; then
        ERROR "解压核心文件 '$ASSET_NAME' 失败。"
        exit 1
    fi

    # 打印解压后的文件列表
    DEBUG "解压后的文件列表:"
    if [[ "$DEBUG_MODE" == "true" ]]; then
        ls -l "$XRAYR_BIN_DIR/tmp"
    fi
    # 备份旧的 XrayR 可执行文件（如果存在）
    if [[ -f "$XRAYR_BIN_DIR/XrayR" ]]; then
        INFO "备份旧的 XrayR 可执行文件..."
        # 移除旧的备份文件（如果存在）
        rm -rf "$XRAYR_BIN_DIR/XrayR.bak"
        mv "$XRAYR_BIN_DIR/XrayR" "$XRAYR_BIN_DIR/XrayR.bak"
    fi
    DEBUG "正在将新的 XrayR 从 $tmp_dir 移动到 $XRAYR_BIN_DIR 中..."

    # 移动解压后的文件到目标目录，仅移动 XrayR 可执行文件
    mv "$tmp_dir"/XrayR* "$XRAYR_BIN_DIR/"
    chmod +x "$XRAYR_BIN_DIR/XrayR"*
    
    # 执行 manage_config_files 函数来处理配置文件
    manage_config_files "$tmp_dir"

    # 清理临时目录和压缩包
    rm -rf "$tmp_dir"
    rm -f "$zip_path"

    INFO "核心程序安装完成。"
}

# 设置开机自启服务
# 依据不同操作系统使用不同的方法
# 功能:
#   1. 根据操作系统类型，选择合适的服务管理器 (systemd, launchd, rc.d, termux-services)。
#   2. 创建相应的服务配置文件。
#   3. 启用并启动服务。
# 输出:
#   - 在系统中注册 XrayR 服务，并设置为开机自启。
# 注意:
#   - 该函数假设 XrayR 已安装在 /usr/local/XrayR/ 目录下，配置文件位于 /etc/XrayR/config.yml。
function setup_service() {
    INFO "正在设置开机自启服务..."

    # 根据 OS_NAME 判断使用哪个服务管理器
    case "$OS_NAME" in
        linux)
            if command -v systemctl &> /dev/null; then
                # 处理主流的 systemd 系统
                setup_systemd_service
            elif command -v rc-update &> /dev/null; then
                # 处理 Alpine, Gentoo 等 OpenRC 系统
                setup_openrc_service
            else
                # 对于更古老的 SysVinit 等，回退到警告
                WARN "未检测到 systemd 或 OpenRC, 无法自动设置开机自启。"
                WARN "请手动配置您的 init 系统来运行 /usr/local/XrayR/XrayR。"
            fi
            ;;
        macos)
            # 在 macOS 上，我们创建 a launchd plist 文件
            setup_launchd_service
            ;;
        windows)
            WARN "在 Windows 上，请手动将 XrayR 设置为服务。"
            WARN "您可以使用 nssm (Non-Sucking Service Manager) 等工具。"
            ;;
        freebsd|dragonfly)
            # 在 FreeBSD 上，我们创建一个 rc.d 脚本
            setup_rcd_service_freebsd
            ;;
        android)
            # 在 Android (Termux) 上，我们使用 termux-services
            setup_termux_service
            ;;
        window|*)
            WARN "无法在此操作系统 (${OS_NAME}) 上自动设置开机自启服务。"
            ;;
    esac
}

# Linux - systemd 实现
function setup_systemd_service() {
    INFO "检测到 systemd, 正在创建 service 文件..."
    local service_path="/etc/systemd/system/XrayR.service"
    local priv_cmd=""
    if [[ $EUID -ne 0 ]]; then
        if command -v sudo &> /dev/null; then
            priv_cmd="sudo"
        elif command -v doas &> /dev/null; then
            priv_cmd="doas"
        fi
    fi
    $priv_cmd tee "$service_path" >/dev/null <<-EOF
		[Unit]
		Description=XrayR Service
		After=network.target nss-lookup.target
		[Service]
		User=root
		Type=simple
		Restart=always
		RestartSec=5s
		ExecStart=${XRAYR_BIN_DIR}/XrayR --config ${CONFIG_DIR}/config.yml
		WorkingDirectory=${XRAYR_BIN_DIR}/
		[Install]
		WantedBy=multi-user.target
	EOF
    $priv_cmd chmod 644 "$service_path"
    $priv_cmd systemctl daemon-reload
	$priv_cmd systemctl enable XrayR
    INFO "systemd 服务设置完成。"
}

# Linux (Alpine) - OpenRC 实现
function setup_openrc_service() {
    INFO "检测到 OpenRC, 正在创建 init 脚本..."
    local service_path="/etc/init.d/xrayr"
    local priv_cmd=""
    if [[ $EUID -ne 0 ]]; then
        if command -v sudo &> /dev/null; then
            priv_cmd="sudo"
        elif command -v doas &> /dev/null; then
            priv_cmd="doas"
        fi
    fi
    $priv_cmd tee "$service_path" >/dev/null <<-EOF
		#!/sbin/openrc-run
		command="${XRAYR_BIN_DIR}/XrayR"
		command_args="--config ${CONFIG_DIR}/config.yml"
		command_background=true
		directory="${XRAYR_BIN_DIR}"
		pidfile="/run/\${RC_SVCNAME}.pid"
		depend() { need net; after firewall; }
	EOF
    $priv_cmd chmod +x "$service_path"
    $priv_cmd rc-update add xrayr default
    INFO "OpenRC 服务设置完成。"
}

# macOS - launchd 实现
function setup_launchd_service() {
    INFO "检测到 macOS, 正在创建 launchd plist 文件..."
    local plist_path="/Library/LaunchDaemons/com.xrayr.plist"
    local priv_cmd=""
    if [[ $EUID -ne 0 ]]; then
        if command -v sudo &> /dev/null; then
            priv_cmd="sudo"
        fi
    fi
    $priv_cmd tee "$plist_path" >/dev/null <<-EOF
		<?xml version="1.0" encoding="UTF-8"?>
		<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
		<plist version="1.0">
		<dict>
		    <key>Label</key><string>com.xrayr</string>
		    <key>ProgramArguments</key>
		    <array>
		        <string>${XRAYR_BIN_DIR}/XrayR</string>
		        <string>--config</string>
		        <string>${CONFIG_DIR}/config.yml</string>
		    </array>
		    <key>WorkingDirectory</key><string>${XRAYR_BIN_DIR}/</string>
		    <key>RunAtLoad</key><true/>
		    <key>KeepAlive</key><true/>
		</dict>
		</plist>
	EOF
    $priv_cmd chmod 644 "$plist_path"
    $priv_cmd launchctl unload "$plist_path" 2>/dev/null || true
    INFO "launchd 服务设置完成。"
}

# FreeBSD/DragonFly - rc.d 实现
function setup_rcd_service_freebsd() {
    INFO "检测到 FreeBSD/DragonFly BSD, 正在创建 rc.d 脚本..."
    local rcd_path="/usr/local/etc/rc.d/xrayr"
    local priv_cmd=""
    if [[ $EUID -ne 0 ]]; then
        if command -v sudo &> /dev/null; then
            priv_cmd="sudo"
        fi
    fi
    $priv_cmd tee "$rcd_path" >/dev/null <<-EOF
		#!/bin/sh
		. /etc/rc.subr
		name="xrayr"
		rcvar="xrayr_enable"
		command="${XRAYR_BIN_DIR}/XrayR"
		command_args="--config ${CONFIG_DIR}/config.yml &"
		load_rc_config \$name
		run_rc_command "\$1"
	EOF
    $priv_cmd chmod +x "$rcd_path"
    $priv_cmd sysrc xrayr_enable=YES
    INFO "FreeBSD/DragonFly BSD rc.d 服务设置完成。"
}

# OpenBSD - rc.d 实现
function setup_rcd_service_openbsd() {
    INFO "检测到 OpenBSD，正在创建 rc.d 脚本..."
    local rcd_path="/etc/rc.d/xrayr"
    local priv_cmd=""
    if [[ $EUID -ne 0 ]]; then
        if command -v doas &> /dev/null; then
            priv_cmd="doas" 
        elif command -v sudo &> /dev/null; then
            priv_cmd="sudo"
        fi
    fi
    $priv_cmd tee "$rcd_path" >/dev/null <<-EOF
		#!/bin/ksh
		daemon="${XRAYR_BIN_DIR}/XrayR"
		daemon_flags="--config ${CONFIG_DIR}/config.yml"
		. /etc/rc.d/rc.subr
		rc_cmd "\$1"
	EOF
    $priv_cmd chmod +x "$rcd_path"
    $priv_cmd rcctl enable xrayr
    INFO "OpenBSD rc.d 服务设置完成。"
}

# Android (Termux) - termux-services 实现
function setup_termux_service() {
    INFO "检测到 Termux，正在创建服务..."
    if ! command -v sv-enable &> /dev/null; then
        WARN "依赖 'termux-services' 未安装，无法设置服务。"
        return 1
    fi
    local service_dir="$HOME/.termux/service/xrayr"
    mkdir -p "$service_dir" "$service_dir/log"
    cat > "$service_dir/run" <<-EOF
		#!/data/data/com.termux/files/usr/bin/sh
		exec ${XRAYR_BIN_DIR}/XrayR --config ${CONFIG_DIR}/config.yml
	EOF
    chmod +x "$service_dir/run"
    cat > "$service_dir/log/run" <<-EOF
		#!/data/data/com.termux/files/usr/bin/sh
		exec svlogd -tt ./main
	EOF
    chmod +x "$service_dir/log/run"
    sv-enable xrayr
    INFO "Termux 服务设置完成。"
    WARN "请务必运行 'termux-wake-lock' 以防止 Termux 在后台被系统杀死。"
}

# 启动服务
# 跨平台启动 XrayR 服务
# 功能:
#   1. 根据操作系统类型，选择合适的服务管理器 (systemd, launchd, rc.d, termux-services) 来启动 XrayR 服务
#   2. 处理提权操作（如使用 sudo 或 doas）
function start_service() {
    INFO "正在尝试启动 XrayR 服务..."
    local priv_cmd=""
    if [[ $EUID -ne 0 ]]; then
        if command -v doas &> /dev/null; then
            priv_cmd="doas"
        elif command -v sudo &> /dev/null; then
            priv_cmd="sudo"
        fi
    fi

    case "$OS_NAME" in
        linux)
            if command -v systemctl &> /dev/null; then
                $priv_cmd systemctl restart XrayR
            elif command -v rc-service &> /dev/null; then
                $priv_cmd rc-service xrayr restart
            fi
            ;;
        macos)
            $priv_cmd launchctl unload /Library/LaunchDaemons/com.xrayr.plist 2>/dev/null || true
            $priv_cmd launchctl load /Library/LaunchDaemons/com.xrayr.plist
            ;;
        freebsd|dragonfly)
            $priv_cmd service xrayr restart
            ;;
        openbsd)
            $priv_cmd rcctl restart xrayr
            ;;
        android)
            sv-enable xrayr
            sv restart xrayr
            ;;
        *)
            WARN "无法在此操作系统 (${OS_NAME}) 上自动启动服务。"
            # 对于不支持的系统，直接返回成功，避免后续检查失败
            return 0
            ;;
    esac

    # 使用循环来等待服务启动
    INFO "等待服务稳定..."
    local max_wait_seconds=15
    for ((i=0; i<max_wait_seconds; i++)); do
        if check_status_cross_platform; then
            INFO "XrayR 服务已成功启动。"
            return 0 # 成功，直接返回
        fi
        sleep 1
    done

    # 如果循环结束了服务还没启动，才是真的失败
    ERROR "XrayR 服务在 ${max_wait_seconds} 秒内未能成功启动，请检查日志。"
    # 打印详细的 systemd 日志以帮助调试
    if command -v journalctl &> /dev/null; then
        WARN "--- 最近的 XrayR 服务日志 ---"
        journalctl -u XrayR.service -n 20 --no-pager
        WARN "-----------------------------"
    fi
    exit 1
}

# 管理配置文件
# 功能:
#   1. 检查临时目录下的配置文件。
#   2. 如果配置文件在配置目录中不存在，则复制过去。
#   3. 对于 config.yml.example，特殊处理为 config.yml。
#   4. 提示用户修改 config.yml（如果是全新安装）。
function manage_config_files() {
    # 接收传入的临时目录路径
    local tmp_dir="$1"
    INFO "正在处理配置文件..."

    # 确保配置目录存在
    mkdir -p "$CONFIG_DIR"

    # 优先处理 config.yml.example，确保 config.yml 存在
    if [[ -f "$tmp_dir/config.yml.example" && ! -f "$CONFIG_DIR/config.yml" ]]; then
        INFO "检测到首次安装，正在创建初始配置文件 config.yml..."
        cp "$tmp_dir/config.yml.example" "$CONFIG_DIR/config.yml"
        chmod 644 "$CONFIG_DIR/config.yml"
        WARN "已创建初始配置文件，请务必根据您的需求修改: $CONFIG_DIR/config.yml"
    fi

    # 遍历所有临时文件，只复制目标目录中不存在的文件
    for file in "$tmp_dir/"*; do
        local filename
        filename=$(basename "$file")
        if [[ "$filename" == XrayR* ]]; then
            continue
        fi
        
        if [[ ! -f "$CONFIG_DIR/$filename" ]]; then
            INFO "正在复制新配置文件: $filename"
            cp "$file" "$CONFIG_DIR/"
            chmod 644 "$CONFIG_DIR/$filename"
        fi
    done
}

# 解析配置仓库 URL
# 功能:
#   从多种格式的 GitHub URL 中提取 owner, repo, branch, 和 path。
#   支持:
#     - https://github.com/owner/repo
#     - https://github.com/owner/repo.git
#     - https://github.com/owner/repo/tree/branch/path/to/config
#     - git@github.com:owner/repo.git
# 输出:
#   - 设置全局变量 CONFIG_REPO_OWNER, CONFIG_REPO_NAME, CONFIG_REPO_BRANCH, CONFIG_REPO_PATH
function parse_config_repo_url() {
    if [[ -z "$CONFIG_REPO_URL" ]]; then
        return
    fi

    # 统一移除 .git 后缀以便解析
    local url=${CONFIG_REPO_URL%.git}
    
    # 使用正则表达式匹配不同的 URL 格式
    # 模式1: 匹配 https://... 格式
    #         BASH_REMATCH:   [1]     [2]        [3]                  [4]       [5]
    if [[ $url =~ https?://[^/]+/([^/]+)/([^/]+)(/tree/([^/]+)/?(.*))? ]]; then
        CONFIG_REPO_OWNER="${BASH_REMATCH[1]}"
        CONFIG_REPO_NAME="${BASH_REMATCH[2]}"
        CONFIG_REPO_BRANCH="${BASH_REMATCH[4]}"
        CONFIG_REPO_PATH="${BASH_REMATCH[5]}"
    # 模式2: 匹配 git@... 格式
    #         BASH_REMATCH:   [1]      [2]      [3]
    elif [[ $url =~ git@([^:]+):([^/]+)/([^/]+) ]]; then
        CONFIG_REPO_OWNER="${BASH_REMATCH[2]}"
        CONFIG_REPO_NAME="${BASH_REMATCH[3]}"
        # git@ 格式通常不包含分支和路径，需要设为默认值
        CONFIG_REPO_BRANCH=""
        CONFIG_REPO_PATH=""
    else
        ERROR "无法解析配置文件仓库 URL: $CONFIG_REPO_URL"
        WARN "请确保格式为 https://github.com/{owner}/{repo} 或 git@github.com:{owner}/{repo}.git"
        exit 1
    fi

    # 为分支和路径设置明确的默认值
    if [[ -z "$CONFIG_REPO_BRANCH" ]]; then
        # 如果 URL 中没有指定分支，则使用默认值 'main'
        CONFIG_REPO_BRANCH="main"
    fi
    # 路径可以为空，代表仓库根目录

    INFO "解析配置文件仓库: ${CONFIG_REPO_OWNER}/${CONFIG_REPO_NAME}"
    INFO "分支: ${CONFIG_REPO_BRANCH}, 路径: ${CONFIG_REPO_PATH:-. (根目录)}"
}

# 安装自定义配置文件
function install_config_files() {
    # 存在远程配置文件仓库地址则下载
    if [[ -z "$CONFIG_REPO_URL" ]]; then
        WARN "未提供配置文件仓库地址，跳过自定义配置文件安装。"
        return 0
    fi

    # 先解析 URL
    parse_config_repo_url
    # 确保配置目录存在
    mkdir -p "$CONFIG_DIR"

    local dir_contents_json
    dir_contents_json=$(get_github_dir_contents "$CONFIG_REPO_OWNER" "$CONFIG_REPO_NAME" "$CONFIG_REPO_PATH" "$CONFIG_REPO_BRANCH" "config")
    if [[ $? -ne 0 ]]; then 
        exit 1
    fi

    # 使用 while read 循环安全地处理 jq 的输出
    echo "$dir_contents_json" | jq -c '.[] | select(.type == "file")' | while IFS= read -r file_info; do
        local file_name
        file_name=$(echo "$file_info" | jq -r '.name')

        # 1. 如果白名单 (config-only) 存在
        if [ ${#CONFIG_ONLY_FILES[@]} -gt 0 ]; then
            local should_download=false
            for only_file in "${CONFIG_ONLY_FILES[@]}"; do
                if [[ "$file_name" == "$only_file" ]]; then
                    should_download=true
                    break
                fi
            done
            
            if [[ "$should_download" == "false" ]]; then
                INFO "根据 --config-only (白名单) 参数，跳过文件: $file_name"
                continue # 跳到下一个文件
            fi
        fi
        
        # 2. 如果白名单不存在，再检查黑名单 (config-ignore)
        if [ ${#CONFIG_IGNORE_FILES[@]} -gt 0 ]; then
            local should_ignore=false
            for ignored_file in "${CONFIG_IGNORE_FILES[@]}"; do
                if [[ "$file_name" == "$ignored_file" ]]; then
                    should_ignore=true
                    break
                fi
            done

            if [[ "$should_ignore" == "true" ]]; then
                INFO "根据 --config-ignore (黑名单) 参数，跳过下载文件: $file_name"
                continue # 跳到下一个文件
            fi
        fi

        local file_download_url
        file_download_url=$(echo "$file_info" | jq -r '.download_url')
        
        DEBUG "正在下载配置文件: $file_name"
        download_file "$file_download_url" "$CONFIG_DIR/$file_name"
    done
    
    INFO "自定义配置文件安装完成。"
}

# 获取 GitHub 仓库指定目录的内容列表 (JSON 格式)
# 参数: $1=owner, $2=repo, $3=path, $4=branch, $5=token_type
function get_github_dir_contents() {
    local owner="$1" repo="$2" path="$3" branch="$4" token_type="$5"
    
    INFO "正在获取仓库 ${owner}/${repo} 目录 '${path:-.}' 的文件列表..."
    
    local api_url="https://api.github.com/repos/${owner}/${repo}/contents/${path}?ref=${branch}"
    build_auth_header "$token_type"

    local req_json
    req_json=$(curl -sSL \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "${auth_header_args[@]}" \
        "$api_url")

    DEBUG "收到的 Contents API 响应: $req_json"

    # 验证 API 响应
    if echo "$req_json" | jq -e 'if type=="object" and .message then true else false end' > /dev/null; then
        ERROR "从 GitHub API 获取文件列表失败。URL: $api_url"
        WARN "请检查 Token 权限以及仓库、分支、路径是否正确。"
        return 1
    fi
    
    echo "$req_json"
}

# 从 GitHub 仓库下载单个指定文件
# 参数: $1=owner, $2=repo, $3=path, $4=branch, $5=file_name, $6=dest, $7=token_type
function download_github_file() {
    local owner="$1" repo="$2" path="$3" branch="$4" file_name="$5" dest="$6" token_type="$7"

    # 1. 获取整个目录的内容
    local dir_contents_json
    dir_contents_json=$(get_github_dir_contents "$owner" "$repo" "$path" "$branch" "$token_type")
    if [[ $? -ne 0 ]]; then return 1; fi

    # 2. 从内容列表中查找特定文件并提取其 download_url
    local file_download_url
    file_download_url=$(echo "$dir_contents_json" | jq -r ".[] | select(.type == \"file\" and .name == \"$file_name\") | .download_url")

    if [[ -z "$file_download_url" || "$file_download_url" == "null" ]]; then
        ERROR "在仓库 ${owner}/${repo} 的 '${path:-.}' 目录中未能找到文件 '$file_name'。"
        return 1
    fi

    # 3. 使用通用的 download_file 函数进行下载
    INFO "正在下载文件 '$file_name'..."
    download_file "$file_download_url" "$dest" "$token_type"
}

# 安装管理脚本
# 功能:
#   1. 从用户指定的 XrayR 仓库根目录下载管理脚本。
#   2. 根据操作系统类型，创建适当的软链接以便全局调用。
function install_management_script() {
    INFO "正在安装管理脚本..."
    
    # 确保 OWNER 和 REPO 变量已设置
    if [[ -z "$OWNER" || -z "$REPO" ]]; then
        ERROR "在下载管理脚本之前，必须先解析 XrayR 仓库 URL。"
        WARN "请确保 install_all 或 update_core_only 函数中已调用 parse_xrayr_repo_url。"
        exit 1
    fi

    INFO "正在从仓库 ${OWNER}/${REPO} 的根目录下载 XrayR.sh..."
    
    # 定义管理脚本的安装路径
    download_github_file \
        "$OWNER" \
        "$REPO" \
        "" \
        "$BRANCH" \
        "XrayR.sh" \
        "$MANAGE_SCRIPT_PATH" \
        "xrayr"

    # 如果下载失败，download_github_file 内部的 set -e 会让脚本退出
    
    chmod +x "$MANAGE_SCRIPT_PATH"

    # 根据操作系统创建软链接
    local symlink_target=""
    case "$OS_NAME" in
        linux|macos|freebsd|openbsd|dragonfly)
            symlink_target="/usr/local/bin/xrayr"
            ;;
        *)
            INFO "在 ${OS_NAME} 上，无需创建额外的软链接。"
            INFO "管理脚本安装完成。"
            return 0
            ;;
    esac

    if [[ "$MANAGE_SCRIPT_PATH" == "$symlink_target" ]]; then
        INFO "脚本已安装在标准路径，无需创建软链接。"
    else
        INFO "正在创建软链接以便全局调用: ${symlink_target} -> ${MANAGE_SCRIPT_PATH}"
        local priv_cmd=""
        if [[ $EUID -ne 0 ]]; then
            if command -v sudo &> /dev/null; then priv_cmd="sudo";
            elif command -v doas &> /dev/null; then priv_cmd="doas"; fi
        fi
        $priv_cmd mkdir -p "$(dirname "$symlink_target")"
        $priv_cmd ln -sf "$MANAGE_SCRIPT_PATH" "$symlink_target"
    fi
    
    INFO "管理脚本安装完成。"
}

# 打印管理脚本用法
function print_management_usage() {
    echo ""
    INFO "XrayR 管理脚本使用方法 (兼容使用 xrayr 执行):"
    echo "------------------------------------------"
    echo "XrayR                    - 显示管理菜单 (功能更多)"
    echo "XrayR start              - 启动 XrayR"
    echo "XrayR stop               - 停止 XrayR"
    echo "XrayR restart            - 重启 XrayR"
    echo "XrayR status             - 查看 XrayR 状态"
    echo "XrayR enable             - 设置 XrayR 开机自启"
    echo "XrayR disable            - 取消 XrayR 开机自启"
    echo "XrayR log                - 查看 XrayR 日志"
    echo "XrayR update             - 更新 XrayR"
    echo "XrayR update x.x.x       - 更新 XrayR 指定版本"
    echo "XrayR config             - 显示配置文件内容"
    echo "XrayR install            - 安装 XrayR"
    echo "XrayR uninstall          - 卸载 XrayR"
    echo "XrayR version            - 查看 XrayR 版本"
    echo "------------------------------------------"
}

# 全新安装 XrayR
function install_all() {
    INFO "开始全新安装 XrayR..."
    # 安装基础依赖
    install_dependencies
    # 安装 acme.sh（如果需要）
    install_acme
    # 解析仓库里的 owner 与 repo
    parse_xrayr_repo_url
    # 覆写 XrayR 安装路径、 下载文件名、配置目录
    set_xrayr_install_path
    set_xrayr_asset_name 
    set_config_install_path
    # 下载并解压安装 XrayR
    download_and_extract_xrayr
    # 下载 geoip 与 geosite
    install_geo
    # 安装自定义配置文件
    install_config_files
    # 设置服务
    setup_service
    # 启动服务
    start_service
    # 安装管理脚本
    install_management_script
}

# 仅更新内核
function update_core_only() {
    # 安装基础依赖
    install_dependencies
    # 安装 acme.sh（如果需要）
    install_acme
    # 解析仓库里的 owner 与 repo
    parse_xrayr_repo_url
    # 覆写 XrayR 安装路径、下载文件名、配置目录
    set_xrayr_install_path
    set_xrayr_asset_name
    set_config_install_path
    # 下载并解压安装 XrayR
    download_and_extract_xrayr
    # 设置服务
    setup_service
    # 启动服务
    start_service
    # 安装管理脚本
    install_management_script
}

# 仅更新 geoip 与 geosite
function update_geo_only() {
    # 覆写配置文件安装路径
    set_config_install_path
    # 安装 geoip 与 geosite
    install_geo
    # 需要重启服务
    start_service
}

# 仅更新配置文件
function update_config_only() {
    # 覆写配置文件安装路径
    set_config_install_path
    # 安装自定义配置文件
    install_config_files
    # 需要重启服务
    start_service
}

# 根据安装模式执行不同操作
function run_mode_setup() {
    # 检查操作系统与架构兼容性
    check_os_arch

    case "$INSTALL_MODE" in
        install)
            INFO "安装模式: 全新安装 XrayR。"
            install_all
            ;;
        update-config)
            INFO "安装模式: 仅更新配置文件。"
            update_config_only
            ;;
        update-geo)
            INFO "安装模式: 仅更新 geoip 与 geosite。"
            update_geo_only
            ;;
        update-core)
            INFO "安装模式: 仅更新核心程序。"
            update_core_only
            ;;
        *)
            ERROR "未知的安装模式: $INSTALL_MODE"
            exit 1
            ;;
    esac

    # 返回初始目录
    cd "$cur_dir"
    # 打印管理脚本用法
    print_management_usage
}

#=================================================
#               主函数 (执行逻辑)
#=================================================
function main() {
    # 解析可选参数
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            #=================================================
            # 通用参数
            #=================================================
            -h|--help) 
                print_usage
                exit 0
                ;;
            -d|--debug)
                DEBUG_MODE=true
                ;;
            -m|--mode)
                if [[ -n "$2" && "$2" != -* ]]; then
                    INSTALL_MODE="$2"
                    shift
                else
                    ERROR "缺少安装模式参数值, 请使用 -m <mode> 指定安装模式。"
                    print_usage
                    exit 1
                fi
                ;;
            # GitHub 访问 Token
            -t|--token)
                if [[ -n "$2" && "$2" != -* ]]; then
                    GITHUB_TOKEN="$2"
                    shift
                else
                    ERROR "缺少 GitHub 访问 Token 参数值, 请使用 -t <token> 指定 Token。"
                    print_usage
                    exit 1
                fi
                ;;
            # 是否下载 acme.sh 相关参数
            -a|--acme) 
                IS_ACME=true
                ;;

            #=================================================
            # xrayr 仓库相关参数
            #=================================================
            # XrayR 仓库地址
            -rr|--xrayr-repo)
                if [[ -n "$2" && "$2" != -* ]]; then
                    XRAYR_REPO_URL="$2"
                    shift
                else
                    ERROR "缺少 XrayR 仓库地址参数值, 请使用 -rr <repo_url> 指定仓库地址。"
                    print_usage
                    exit 1
                fi
                ;;
            # XrayR 访问 Token
            -rt|--xrayr-token)
                if [[ -n "$2" && "$2" != -* ]]; then
                    XRAYR_TOKEN="$2"
                    shift
                else
                    ERROR "缺少 XrayR 访问 Token 参数值, 请使用 -rt <token> 指定 Token。"
                    print_usage
                    exit 1
                fi
                ;;
            # XrayR release 标签
            -rv|--xrayr-version)
                if [[ -n "$2" && "$2" != -* ]]; then
                    XRAYR_RELEASE_TAG="$2"
                    shift
                else
                    ERROR "缺少 XrayR release 标签参数值, 请使用 -rv <tag> 指定标签。"
                    print_usage
                    exit 1
                fi
                ;;
            # XrayR 安装路径
            -rp|--xrayr-install-path)
                if [[ -n "$2" && "$2" != -* ]]; then
                    XRAYR_BIN_DIR="$2"
                    shift
                else
                    ERROR "缺少 XrayR 安装路径参数值, 请使用 -rp <path> 指定安装路径。"
                    print_usage
                    exit 1
                fi
                ;;

            # 强制指定下载的 Release 文件名
            -ra|--xrayr-asset)
                if [[ -n "$2" && "$2" != -* ]]; then
                    XRAYR_ASSET_NAME_OVERRIDE="$2"
                    shift
                else
                    ERROR "缺少 XrayR Release 文件名参数值, 请使用 -ra <asset_name> 指定文件名。"
                    print_usage
                    exit 1
                fi
                ;;

            # 自定义下载地址（完整 URL 或目录 URL）
            -ru|--xrayr-url)
                if [[ -n "$2" && "$2" != -* ]]; then
                    XRAYR_DOWNLOAD_URL="$2"
                    shift
                else
                    ERROR "缺少 XrayR 下载地址参数值, 请使用 -ru <url> 指定下载地址。"
                    print_usage
                    exit 1
                fi
                ;;

            #=================================================
            # 自定义配置文件仓库相关参数
            #=================================================
            # 配置文件仓库地址
            -cr|--config-repo)
                if [[ -n "$2" && "$2" != -* ]]; then
                    CONFIG_REPO_URL="$2"
                    shift
                else
                    ERROR "缺少配置文件仓库地址参数值, 请使用 -cr <repo_url> 指定仓库地址。"
                    print_usage
                    exit 1
                fi
                ;;
            # 配置文件仓库访问 Token
            -ct|--config-token)
                if [[ -n "$2" && "$2" != -* ]]; then
                    CONFIG_TOKEN="$2"
                    shift
                else
                    ERROR "缺少配置文件仓库访问 Token 参数值, 请使用 -ct <token> 指定 Token。"
                    print_usage
                    exit 1
                fi
                ;;
            # 配置文件安装路径
            -cp|--config-install-path)
                if [[ -n "$2" && "$2" != -* ]]; then
                    CONFIG_DIR="$2"
                    shift
                else
                    ERROR "缺少配置文件安装路径参数值, 请使用 -cp <path> 指定安装路径。"
                    print_usage
                    exit 1
                fi
                ;;
            # 配置文件忽略列表
            -ci|--config-ignore)
                if [[ -n "$2" && "$2" != -* ]]; then
                    # 获取传入的值，例如 "abc.txt,123.yml" 或 "single.txt"
                    local new_ignores="$2"
                    
                    # 使用 IFS 将这个值按逗号分割成一个临时数组
                    # 即使只有一个文件名（没有逗号），这行代码也能正确工作
                    IFS=',' read -r -a temp_array <<< "$new_ignores"
                    
                    # 将临时数组中的所有元素追加到我们的主忽略文件数组中
                    # `${temp_array[@]}` 会展开成所有文件名
                    CONFIG_IGNORE_FILES+=("${temp_array[@]}")
                    shift
                else
                    ERROR "缺少配置文件忽略列表参数值, 请使用 -ci <file1,file2,...> 指定忽略的文件列表。"
                    print_usage
                    exit 1
                fi
                ;;
            # 配置文件白名单
            -co|--config-only)
                if [[ -n "$2" && "$2" != -* ]]; then
                    # 获取传入的值，例如 "abc.txt,123.yml" 或 "single.txt"
                    local new_only_files="$2"
                    # 使用 IFS 将这个值按逗号分割成一个临时数组
                    # 即使只有一个文件名（没有逗号），这行代码也能正确工作
                    IFS=',' read -r -a temp_array <<< "$new_only_files"

                    # 将临时数组中的所有元素追加到我们的主白名单文件数组中
                    # `${temp_array[@]}` 会展开成所有文件名
                    CONFIG_ONLY_FILES+=("${temp_array[@]}")
                    shift
                else
                    ERROR "缺少配置文件白名单参数值, 请使用 -co <file1,file2,...> 指定仅更新的文件列表。"
                    print_usage
                    exit 1
                fi
                ;;
            #=================================================
            # geoip 与 geosite 仓库相关参数
            #=================================================
            # geoip 与 geosite 仓库参数
            -gr|--geo-repo)
                if [[ -n "$2" && "$2" != -* ]]; then
                    GEO_REPO_URL="$2"
                    shift
                else
                    ERROR "缺少 geoip 与 geosite 仓库地址参数值, 请使用 -gr <repo_url> 指定仓库地址。"
                    print_usage
                    exit 1
                fi
                ;;
            -gt|--geo-token)
                if [[ -n "$2" && "$2" != -* ]]; then
                    GEO_TOKEN="$2"
                    shift
                else
                    ERROR "缺少 geoip 与 geosite 仓库访问 Token 参数值, 请使用 -gt <token> 指定 Token。"
                    print_usage
                    exit 1
                fi
                ;;
            #=================================================
            *) 
                ERROR "未知选项: $1"
                print_usage
                exit 1
                ;;
        esac
        shift
    done   

    # 如果是 install 模式或者 update-core 模式，检查是否传入了 XrayR 仓库地址
    if [[ "$INSTALL_MODE" == "install" || "$INSTALL_MODE" == "update-core" ]]; then
        if [[ -z "$XRAYR_REPO_URL" ]]; then
            ERROR "在安装或更新核心程序时，必须提供 XrayR 仓库地址。"
            WARN "请使用 -rr <repo_url> 参数指定仓库地址。"
            exit 1
        fi
    fi

    # 检查 root 权限
    if [[ $EUID -ne 0 ]] && ! command -v sudo &> /dev/null && ! command -v doas &> /dev/null; then
        ERROR "必须以 root 用户身份运行，或确保系统中安装了 sudo/doas。"
        exit 1
    fi

    run_mode_setup 
}

# 脚本执行入口
main "$@"
