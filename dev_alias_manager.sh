#!/bin/bash
# -*- coding: utf-8 -*-

# 设置锁文件
LOCK_FILE="/tmp/usb_alias_manager.lock"

# 设置目录
CONFIG_DIR="./config"
LOG_DIR="./logs"
TMP_DIR="./tmp"
BACKUP_DIR="./backups"
LANG_DIR="./lang"
DEFAULT_CONFIG_FILE="${CONFIG_DIR}/dev_alias_manager.conf.default"
LOG_FILE="${LOG_DIR}/usb_alias_manager.log"

# 默认的初始加载消息，不依赖语言文件
DEFAULT_LOADING_CONFIG="Loading config..."
DEFAULT_ATTEMPTING_LOAD_LANG="Attempting to load language file..."
DEFAULT_LANGUAGE_NOT_FOUND="Language file not found, defaulting to English."

# 初始化脚本目录
function init_directories() {
    mkdir -p "${CONFIG_DIR}" "${LOG_DIR}" "${TMP_DIR}" "${BACKUP_DIR}" "${LANG_DIR}"

    if [ ! -f "${DEFAULT_CONFIG_FILE}" ]; then
        echo "Creating default config file."
        echo "LANGUAGE=en" > "${DEFAULT_CONFIG_FILE}"
        echo "RETRY_LIMIT=3" >> "${DEFAULT_CONFIG_FILE}"
        echo "TIMEOUT=10" >> "${DEFAULT_CONFIG_FILE}"
    fi
}

# 初始化日志
function log() {
    local log_level="$1"
    local message="$2"
    echo "$(date +'%Y-%m-%d %H:%M:%S') [${log_level}] ${message}" >> "${LOG_FILE}"
}

# 脚本退出时的清理工作
function cleanup() {
    log "INFO" "Cleaning up and exiting."
    rm -f "${LOCK_FILE}"
    exit 0
}

# 检查是否有 sudo 权限
function check_sudo() {
    if [ "$EUID" -ne 0 ]; then
        echo "Please run as root (use sudo)."
        exit 1
    fi
}

# 使用 udevadm 获取设备信息
function get_device_info() {
    local device="$1"
    udevadm info --query=all --name="${device}" | grep -E 'ID_VENDOR_ID|ID_MODEL|ID_SERIAL|ID_PRODUCT'
}

# 检查设备是否已记录
function device_exists() {
    local serial_to_check="$1"
    if grep -q "ATTR{idSerial}==\"$serial_to_check\"" /etc/udev/rules.d/99-usb-alias.rules 2>/dev/null; then
        return 0  # 设备已存在
    else
        return 1  # 设备不存在
    fi
}

# 检查别名是否已存在
function alias_exists() {
    local alias_to_check="$1"
    if grep -q "SYMLINK+=\"$alias_to_check\"" /etc/udev/rules.d/99-usb-alias.rules 2>/dev/null; then
        return 0  # 别名已存在
    else
        return 1  # 别名不存在
    fi
}

# 验证别名是否合法
function validate_alias() {
    local alias="$1"
    if [[ ! "${alias}" =~ ^[a-zA-Z0-9_-]{1,32}$ ]]; then
        echo "${INVALID_ALIAS}"
        return 1
    fi
    return 0
}

# 管理别名
function manage_alias() {
    echo -e "${WAITING_NEW_DEVICE}\n"

    # 启动监听，将输出重定向到日志文件，保持界面清洁
    udevadm monitor --subsystem-match=usb --property &> "${LOG_DIR}/udevadm_monitor.log" &

    # 获取当前已连接的 USB 设备列表
    lsusb > "${TMP_DIR}/before_devices.txt"

    # 持续监控设备插入（自动检测）
    while true; do
        sleep 2  # 定期检查

        # 列出插入后的 USB 设备列表
        lsusb > "${TMP_DIR}/after_devices.txt"

        # 比较前后的设备列表，找出新插入的设备
        new_devices=$(diff "${TMP_DIR}/before_devices.txt" "${TMP_DIR}/after_devices.txt" | grep ">" | sed 's/> //')

        # 检查是否有新设备
        if [ -n "$new_devices" ]; then
            echo -e "${NEW_DEVICE_DETECTED}\n"
            echo "$new_devices"
            break  # 跳出循环，进入操作流程
        fi
    done

    # 提取新插入设备的编号
    bus_device=$(echo "$new_devices" | awk '{print $2, $4}')

    # 获取设备路径
    device=$(ls /dev/bus/usb/$(echo $bus_device | awk '{print $1}')/$(echo $bus_device | awk '{print $2}' | sed 's/:$//') 2>/dev/null)

    if [ -z "$device" ]; then
        echo "${DEVICE_NOT_FOUND}"
        return
    fi

    # 使用 udevadm 获取设备信息
    local info=$(udevadm info --query=all --name="${device}" | grep -E 'ID_VENDOR_ID|ID_MODEL|ID_SERIAL|ID_PRODUCT|ID_SERIAL_SHORT')

    # 提取设备的唯一标识符（如序列号）
    local serial_number=$(echo "$info" | grep 'ID_SERIAL_SHORT=' | cut -d '=' -f2)

    # 检查设备是否已记录
    if device_exists "$serial_number"; then
        echo -e "${DEVICE_ALREADY_RECORDED}\n"
        return
    fi

    # 显示操作菜单并允许多次操作直到用户选择退出
    while true; do
        # 显示可执行操作的菜单
        echo -e "\n${OPERATION_PROMPT}\n"
        echo "1) ${OPERATION_SET_ALIAS}"
        echo "2) ${OPERATION_SHOW_INFO}"
        echo "3) ${OPERATION_EXIT}"
        read -p "${OPERATION_CHOICE}" operation

        # 根据用户选择执行相应操作
        case $operation in
            1)  # 设置别名
                while true; do
                    echo -e "\n${DEVICE_PROMPT}"
                    read -p "> " alias

                    # 验证别名是否合法
                    if validate_alias "${alias}"; then
                        if alias_exists "${alias}"; then
                            echo -e "${ALIAS_EXISTS}"
                        else
                            echo "${ALIAS_VALID} ${alias}"
                            # 将新规则追加到文件中
                            echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"$(echo "${info}" | grep ID_VENDOR_ID | cut -d'=' -f2)\", ATTR{idSerial}==\"$serial_number\", SYMLINK+=\"${alias}\"" >> /etc/udev/rules.d/99-usb-alias.rules
                            log "INFO" "${ALIAS_CREATED} ${alias}."
                            break
                        fi
                    else
                        echo "${INVALID_ALIAS}"
                    fi
                done
                ;;
            2)  # 显示设备详细信息
                echo -e "\n${DEVICE_INFO}\n"
                echo "$info" | sed 's/E: //g'  # 去掉 "E: " 前缀
                ;;
            3)  # 退出
                echo -e "${EXITING}\n"
                break
                ;;
            *)  # 无效输入
                echo -e "${INVALID_OPTION}\n"
                ;;
        esac
    done
}

# 查看已记录的设备
function view_recorded_devices() {
    echo -e "\n${LISTING_RECORDED_DEVICES}"
    if [ -f "/etc/udev/rules.d/99-usb-alias.rules" ] && [ -s "/etc/udev/rules.d/99-usb-alias.rules" ]; then
        # 逐行读取并格式化显示
        i=1
        while IFS= read -r line; do
            alias=$(echo "$line" | grep -oP 'SYMLINK\+="\K[^"]+')
            idVendor=$(echo "$line" | grep -oP 'ATTR\{idVendor\}=="\K[^"]+')
            subsystem=$(echo "$line" | grep -oP 'SUBSYSTEM=="\K[^"]+')
            echo "$i. $alias: $subsystem, ATTR{idVendor}==$idVendor"
            ((i++))
        done < /etc/udev/rules.d/99-usb-alias.rules
    else
        echo "${NO_RECORDED_DEVICES}"
    fi
    echo
}

# 显示所有 USB 设备
function show_all_devices() {
    echo -e "\n${LISTING_ALL_DEVICES}"
    lsusb
    echo
}

# 删除设备记录
function delete_device_record() {
    echo -e "\n${DELETING_DEVICE_RECORD}"
    if [ -f "/etc/udev/rules.d/99-usb-alias.rules" ] && [ -s "/etc/udev/rules.d/99-usb-alias.rules" ]; then
        # 列出已记录的设备
        i=1
        declare -A device_map
        while IFS= read -r line; do
            alias=$(echo "$line" | grep -oP 'SYMLINK\+="\K[^"]+')
            idVendor=$(echo "$line" | grep -oP 'ATTR\{idVendor\}=="\K[^"]+')
            subsystem=$(echo "$line" | grep -oP 'SUBSYSTEM=="\K[^"]+')
            device_map[$i]="$line"
            echo "$i. $alias: $subsystem, ATTR{idVendor}==$idVendor"
            ((i++))
        done < /etc/udev/rules.d/99-usb-alias.rules

        # 让用户选择要删除的记录
        echo
        read -p "${DELETE_DEVICE_PROMPT}" device_number

        if [[ -n "${device_map[$device_number]}" ]]; then
            # 删除选中的设备记录
            sed -i "/${device_map[$device_number]}/d" /etc/udev/rules.d/99-usb-alias.rules
            echo "${DEVICE_RECORD_DELETED}"
        else
            echo "${INVALID_SELECTION}"
        fi
    else
        echo "${NO_DEVICE_TO_DELETE}"
    fi
    echo
}

# 重命名设备别名
function rename_device_alias() {
    echo -e "\n${RENAMING_DEVICE_ALIAS}"
    if [ -f "/etc/udev/rules.d/99-usb-alias.rules" ] && [ -s "/etc/udev/rules.d/99-usb-alias.rules" ]; then
        i=1
        declare -A device_map
        while IFS= read -r line; do
            alias=$(echo "$line" | grep -oP 'SYMLINK\+="\K[^"]+')
            idVendor=$(echo "$line" | grep -oP 'ATTR\{idVendor\}=="\K[^"]+')
            subsystem=$(echo "$line" | grep -oP 'SUBSYSTEM=="\K[^"]+')
            device_map[$i]="$line"
            echo "$i. $alias: $subsystem, ATTR{idVendor}==$idVendor"
            ((i++))
        done < /etc/udev/rules.d/99-usb-alias.rules

        # 提示用户选择要重命名的设备
        echo
        read -p "${RENAME_DEVICE_PROMPT}" device_number

        if [[ -n "${device_map[$device_number]}" ]]; then
            current_alias=$(echo "${device_map[$device_number]}" | grep -oP 'SYMLINK\+="\K[^"]+')
            echo -e "\n${CURRENT_ALIAS} $current_alias"
            while true; do
                echo
                read -p "${NEW_ALIAS_PROMPT}" new_alias
                if alias_exists "${new_alias}"; then
                    echo -e "${ALIAS_EXISTS}"
                else
                    # 更新设备别名
                    sed -i "s/SYMLINK+=\"$current_alias\"/SYMLINK+=\"$new_alias\"/" /etc/udev/rules.d/99-usb-alias.rules
                    echo "${ALIAS_UPDATED}"
                    break
                fi
            done
        else
            echo "${INVALID_SELECTION}"
        fi
    else
        echo "${NO_RECORDED_DEVICES}"
    fi
    echo
}

# 加载配置文件
function load_config() {
    echo "${DEFAULT_LOADING_CONFIG}"
    if [ -f "${DEFAULT_CONFIG_FILE}" ]; then
        # 移除可能的 \r 字符
        tr -d '\r' < "${DEFAULT_CONFIG_FILE}" > "${TMP_DIR}/config.temp"
        source "${TMP_DIR}/config.temp"
        echo "Loaded config: LANGUAGE=${LANGUAGE}"
    else
        echo "Configuration file not found. Exiting."
        exit 1
    fi
}

# 加载语言文件
function load_language() {
    echo -e "${DEFAULT_ATTEMPTING_LOAD_LANG} ${LANG_DIR}/${LANGUAGE}.sh\n"
    local lang_file="${LANG_DIR}/${LANGUAGE}.sh"
    if [ -f "${lang_file}" ]; then
        tr -d '\r' < "${lang_file}" > "${TMP_DIR}/lang.temp"
        source "${TMP_DIR}/lang.temp"
    else
        echo "${DEFAULT_LANGUAGE_NOT_FOUND}"
        tr -d '\r' < "${LANG_DIR}/en.sh" > "${TMP_DIR}/lang.temp"
        source "${TMP_DIR}/lang.temp"
    fi
}

# 初始化语言
function init_language() {
    LANGUAGE=$(grep LANGUAGE "${DEFAULT_CONFIG_FILE}" | cut -d'=' -f2)
    LANGUAGE=$(echo "${LANGUAGE}" | tr -d '\r')  # 确保没有 \r
    if [ -z "${LANGUAGE}" ]; then
        LANGUAGE=${LANG:-"en"}
    fi
    load_language  # 加载语言文件
}

# 主菜单
function main_menu() {
    echo "${MENU_TITLE}"
    while true; do
        echo "1) ${MENU_OPTION_1}"
        echo "2) ${MENU_OPTION_2}"
        echo "3) ${MENU_OPTION_3}"
        echo "4) ${MENU_OPTION_4}"
        echo "5) ${MENU_OPTION_5}"
        echo "6) ${MENU_OPTION_6}"
        read -p "${CHOOSE_OPTION}" option

        case $option in
            1) manage_alias ;;  # 调用管理别名功能
            2) view_recorded_devices ;;  # 调用查看已记录的设备功能
            3) show_all_devices ;;  # 显示所有 USB 设备
            4) delete_device_record ;;  # 调用删除设备记录功能
            5) rename_device_alias ;;  # 调用重命名设备别名功能
            6) cleanup ;;  # 退出程序并清理
            *) echo -e "${INVALID_OPTION}\n" ;;  # 无效选项提示
        esac
    done
}

# 检查是否已有其他实例在运行
function check_lock() {
    if [ -f "${LOCK_FILE}" ]; then
        echo "${LOCK_EXISTS}"
        exit 1
    else
        touch "${LOCK_FILE}"
        trap cleanup EXIT
    fi
}

# 脚本入口
function main() {
    check_sudo
    check_lock
    init_directories
    load_config
    init_language
    main_menu
}

main "$@"
