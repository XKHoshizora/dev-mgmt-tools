#!/bin/bash
# -*- coding: utf-8 -*-

declare -A MESSAGES

# 配置
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CONFIG_DIR="$SCRIPT_DIR/config"
CONFIG_FILE="$CONFIG_DIR/dev_alias_manager.conf"
DEFAULT_CONFIG_FILE="$CONFIG_DIR/dev_alias_manager.conf.default"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/dev_alias_manager.log"
TMP_DIR="$SCRIPT_DIR/tmp"
LOCK_FILE="$TMP_DIR/dev_alias_manager.lock"
BACKUP_DIR="$SCRIPT_DIR/backups"
LANG_DIR="$SCRIPT_DIR/lang"

# 检查sudo权限
check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        echo "$(get_message "sudo_required")"
        exit 1
    fi
}

# 创建必要的目录和文件
create_directories_and_files() {
    mkdir -p "$CONFIG_DIR" "$LOG_DIR" "$TMP_DIR" "$BACKUP_DIR"
    
    if [ ! -f "$CONFIG_FILE" ] && [ -f "$DEFAULT_CONFIG_FILE" ]; then
        cp "$DEFAULT_CONFIG_FILE" "$CONFIG_FILE"
        echo "$(get_message "config_created")"
    elif [ ! -f "$CONFIG_FILE" ] && [ ! -f "$DEFAULT_CONFIG_FILE" ]; then
        echo "$(get_message "config_missing")"
        echo "$(get_message "config_error_details")"
        echo "$(get_message "config_expected_location") $CONFIG_FILE"
        echo "$(get_message "default_config_expected_location") $DEFAULT_CONFIG_FILE"
        echo "$(get_message "program_terminating")"
        exit 1
    fi
    
    touch "$LOG_FILE"
}

# 加载和验证配置
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        echo "$(get_message "config_error")"
        exit 1
    fi

    # 设置默认值并验证配置
    MAX_RETRIES=${MAX_RETRIES:-5}
    TIMEOUT=${TIMEOUT:-10}
    DEVICE_RECORD_FILE=${DEVICE_RECORD_FILE:-"/etc/udev/rules.d/99-usb.rules"}
    LOG_LEVEL=${LOG_LEVEL:-"INFO"}
    AUTO_NAMING=${AUTO_NAMING:-false}
    AUTO_NAME_PREFIX=${AUTO_NAME_PREFIX:-"usb-dev-"}
    LANGUAGE=${LANGUAGE:-""}
    MAX_BACKUPS=${MAX_BACKUPS:-5}

    # 验证配置值
    if ! [[ "$MAX_RETRIES" =~ ^[0-9]+$ ]] || [ "$MAX_RETRIES" -lt 1 ]; then
        log "ERROR" "$(get_message "config_error")"
        MAX_RETRIES=5
    fi
    if ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]] || [ "$TIMEOUT" -lt 1 ]; then
        log "ERROR" "$(get_message "config_error")"
        TIMEOUT=10
    fi
    if [ ! -w "$(dirname "$DEVICE_RECORD_FILE")" ]; then
        log "ERROR" "$(get_message "config_error")"
        DEVICE_RECORD_FILE="/etc/udev/rules.d/99-usb.rules"
    fi
    if [[ ! "$LOG_LEVEL" =~ ^(DEBUG|INFO|WARNING|ERROR)$ ]]; then
        log "ERROR" "$(get_message "config_error")"
        LOG_LEVEL="INFO"
    fi
    if [[ ! "$AUTO_NAMING" =~ ^(true|false)$ ]]; then
        log "ERROR" "$(get_message "config_error")"
        AUTO_NAMING=false
    fi
    if [ -z "$AUTO_NAME_PREFIX" ]; then
        log "ERROR" "$(get_message "config_error")"
        AUTO_NAME_PREFIX="usb-dev-"
    fi
    if ! [[ "$MAX_BACKUPS" =~ ^[0-9]+$ ]] || [ "$MAX_BACKUPS" -lt 1 ]; then
        log "ERROR" "$(get_message "config_error")"
        MAX_BACKUPS=5
    fi
}

# 检查并创建 DEVICE_RECORD_FILE
check_device_record_file() {
    if [ ! -f "$DEVICE_RECORD_FILE" ]; then
        log "INFO" "$(get_message "creating_device_record")"
        if ! sudo touch "$DEVICE_RECORD_FILE" 2>/dev/null; then
            log "ERROR" "$(get_message "create_file_error")"
            exit 1
        fi
        if ! sudo chmod 644 "$DEVICE_RECORD_FILE" 2>/dev/null; then
            log "ERROR" "$(get_message "set_permission_error")"
            exit 1
        fi
    fi
}

# 初始化函数
initialize() {
    # echo "Debug: Starting initialization"
    set_language  # 设置语言
    # echo "Debug: Language set, MESSAGES array:"
    # declare -p MESSAGES

    check_sudo  # 检查sudo权限
    
    # 检查 udevadm 是否存在
    if ! command -v udevadm &> /dev/null; then
        echo "$(get_message "udevadm_missing")"
        exit 1
    fi

    create_directories_and_files  # 创建必要的目录和文件
    load_config  # 加载和验证配置
    check_device_record_file  # 检查并创建 DEVICE_RECORD_FILE
    check_and_clean_lock  # 检查并清理锁文件
}

# 检查和清理锁文件
check_and_clean_lock() {
    if [ -f "$LOCK_FILE" ]; then
        if [ -s "$LOCK_FILE" ] && ps -p $(cat "$LOCK_FILE") > /dev/null 2>&1; then
            echo "$(get_message "another_instance")"
            exit 1
        else
            echo "$(get_message "stale_lock")"
            rm -f "$LOCK_FILE"
        fi
    fi
}

# 设置语言
set_language() {
    # echo "Debug: Setting language, LANGUAGE=$LANGUAGE"
    # 优先使用配置文件中的 LANGUAGE，如果为空则使用系统 LANG 变量
    if [ -z "$LANGUAGE" ]; then
        if [ -n "$LANG" ]; then
            LANGUAGE="${LANG%%_*}"
        else
            LANGUAGE="en"  # 如果 LANG 也为空，默认使用英文
        fi
    fi

    # 基于 LANGUAGE 变量来选择语言文件
    case "$LANGUAGE" in
        zh|zh_CN|zh_TW) LANGUAGE="zh" ;;
        ja|ja_JP) LANGUAGE="ja" ;;
        *) LANGUAGE="en" ;;
    esac

    # 加载语言文件
    local lang_file="$LANG_DIR/${LANGUAGE}.sh"
    if [ -f "$lang_file" ]; then
        echo "Loading language file: $lang_file"  # 调试日志
        source "$lang_file"
    else
        echo "Warning: Language file not found. Using English as default."
        source "$LANG_DIR/en.sh"
    fi

    # # debug 输出
    # if [ -f "$lang_file" ]; then
    #     echo "Debug: Loading language file: $lang_file"
    #     source "$lang_file"
    #     echo "Debug: MESSAGES array after loading:"
    #     declare -p MESSAGES
    # else
    #     echo "Error: Language file not found: $lang_file"
    # fi
}

# 获取本地化消息
get_message() {
    local key="$1"
    # echo "Debug: Getting message for key '$key'"
    local message="${MESSAGES[$key]}"
    # echo "Debug: Retrieved message: '$message'"
    
    if [ -z "$message" ]; then
        message="$key"  # 如果没有找到翻译，使用键名作为消息
    fi
    echo "$message"
}

# 日志函数
log() {
    local level=$1
    local message=$2

    if [[ "$LOG_LEVEL" == "DEBUG" ]] ||
       [[ "$LOG_LEVEL" == "INFO" && "$level" != "DEBUG" ]] ||
       [[ "$LOG_LEVEL" == "WARNING" && "$level" =~ ^(WARNING|ERROR)$ ]] ||
       [[ "$LOG_LEVEL" == "ERROR" && "$level" == "ERROR" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - [$level] $message" >> "$LOG_FILE"
        echo "[$level] $message"
    fi
}


# 错误处理函数
handle_error() {
    log "ERROR" "$1"
    exit 1
}

# 检查root权限
check_root() {
    if [ "$(id -u)" != "0" ]; then
        handle_error "$(get_message "sudo_required")"
    fi
}

# 创建锁文件
create_lock() {
    echo $$ > "$LOCK_FILE"
}

# 释放锁文件
release_lock() {
    rm -f "$LOCK_FILE"
}

# 清理函数
cleanup() {
    log "INFO" "$(get_message "cleaning_up")"
    release_lock
    exit 0
}

# 设置清理陷阱
trap cleanup EXIT SIGINT SIGTERM SIGHUP

# 备份udev规则文件
backup_udev_rules() {
    check_root
    local backup_file="${BACKUP_DIR}/udev_rules_$(date +%Y%m%d_%H%M%S).bak"
    if ! cp "$DEVICE_RECORD_FILE" "$backup_file"; then
        log "ERROR" "$(get_message "backup_failed")"
        return 1
    fi
    log "INFO" "$(get_message "backup_success") $backup_file"

    # 删除旧的备份文件
    local old_backups=$(ls -t ${BACKUP_DIR}/udev_rules_*.bak 2>/dev/null | tail -n +$((MAX_BACKUPS + 1)))
    if [ ! -z "$old_backups" ]; then
        echo "$old_backups" | xargs -r rm -f
        log "INFO" "$(get_message "old_backups_deleted")"
    fi
}

# 验证别名
validate_alias() {
    local alias=$1
    if [[ ! $alias =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log "ERROR" "$(get_message "invalid_alias")"
        return 1
    fi
    if [ ${#alias} -gt 32 ]; then
        log "ERROR" "$(get_message "alias_too_long")"
        return 1
    fi
    return 0
}

# 检测新设备接入的函数
detect_new_device() {
    log "INFO" "$(get_message "waiting_device")"

    # 使用 timeout 命令来限制 udevadm monitor 的运行时间
    timeout "$TIMEOUT" udevadm monitor --subsystem-match=usb --property | while read -r line; do
        if [[ $line == *"add"* ]]; then
            log "INFO" "$(get_message "new_device_detected")"

            # 检查是否已锁定，确保每次只能处理一个设备
            if [ -f "$TMP_DIR/device_processing.lock" ]; then
                log "INFO" "$(get_message "device_processing_busy")"
                continue  # 如果已经有设备在处理，跳过该设备
            fi

            # 创建临时锁文件，防止并发设备处理
            touch "$TMP_DIR/device_processing.lock"

            # 等待设备树稳定，确保所有设备准备就绪
            log "INFO" "$(get_message "waiting_device_settle")"
            if ! udevadm settle; then
                log "ERROR" "$(get_message "udevadm_settle_failed")"
                sleep 2  # 增加额外等待时间
                rm -f "$TMP_DIR/device_processing.lock"  # 释放锁
                continue  # 继续检测下一个设备
            fi

            # 获取设备信息
            # new_device_info=$(udevadm info -e | grep -Pzo '(?s)P: .*?\n\n' | grep -a 'SUBSYSTEM=="tty"' | tail -n 1)
            new_device_info=$(udevadm info -e | tr -d '\000' | grep -Pzo '(?s)P: .*?\n\n' | tail -n 1)
            echo "Debug: Device info captured: $new_device_info"
            if [ -z "$new_device_info" ]; then
                log "WARNING" "$(get_message "device_removed")"
                rm -f "$TMP_DIR/device_processing.lock"  # 释放锁
                continue
            fi
            
            device_node=$(echo "$new_device_info" | grep 'DEVNAME=' | cut -d'=' -f2)
            log "INFO" "$(get_message "new_device") $device_node"

            # 使用重试机制等待设备节点准备好
            local max_retries=5
            local retry_interval=1  # 每次等待1秒
            local retries=0

            while [ ! -e "$device_node" ] && [ $retries -lt $max_retries ]; do
                log "INFO" "$(get_message "waiting_for_device") ($((retries + 1))/$max_retries)"
                sleep $retry_interval
                retries=$((retries + 1))
            done

            if [ -e "$device_node" ]; then
                log "INFO" "$(get_message "device_ready") $device_node"
                get_device_info "$device_node"
            else
                log "ERROR" "$(get_message "device_not_ready")"
            fi

            # 处理完该设备后，继续检测下一个设备，释放锁
            rm -f "$TMP_DIR/device_processing.lock"
            log "INFO" "$(get_message "device_processed") $device_node"
        fi
    done

    log "INFO" "$(get_message "detection_complete")"
}

# 获取设备信息的函数
get_device_info() {
    local device_node=$1
    local device_info
    
    device_info=$(udevadm info -a -n "$device_node")
    if [ -z "$device_info" ]; then
        log "WARNING" "$(get_message "device_removed")"
        return
    fi

    local idVendor=$(echo "$device_info" | grep -m1 'idVendor' | awk -F '"' '{print $2}')
    local idProduct=$(echo "$device_info" | grep -m1 'idProduct' | awk -F '"' '{print $2}')
    local serial=$(echo "$device_info" | grep -m1 'serial' | awk -F '"' '{print $2}')

    # 如果找不到 serial，尝试其他可能的属性名
    if [ -z "$serial" ]; then
        log "WARNING" "$(get_message "serial_not_found")"
        serial=$(echo "$device_info" | grep -m1 -E 'serial|SerialNumber' | awk -F '"' '{print $2}')
    fi

    log "INFO" "$(get_message "device_info")"
    log "INFO" "idVendor: $idVendor"
    log "INFO" "idProduct: $idProduct"
    log "INFO" "serial: $serial"

    if grep -q "$idVendor.*$idProduct" "$DEVICE_RECORD_FILE"; then
        log "INFO" "$(get_message "device_recorded")"
        handle_existing_device "$idVendor" "$idProduct"
    else
        record_new_device "$idVendor" "$idProduct" "$serial"
    fi
}

# 处理已存在的设备
handle_existing_device() {
    local idVendor=$1
    local idProduct=$2
    local existing_alias=$(grep "$idVendor.*$idProduct" "$DEVICE_RECORD_FILE" | sed 's/.*SYMLINK+="//; s/".*//')
    log "INFO" "$(get_message "existing_alias") $existing_alias"
    
    read -p "$(get_message "update_alias")" update_choice
    if [[ $update_choice == "y" ]]; then
        rename_device_alias "$existing_alias"
    else
        log "INFO" "$(get_message "keep_alias")"
    fi
}

# 记录新设备的函数
record_new_device() {
    local idVendor=$1
    local idProduct=$2
    local serial=$3

    log "INFO" "$(get_message "recording_device")"
    local alias_name

    if [ "$AUTO_NAMING" = true ]; then
        alias_name="${AUTO_NAME_PREFIX}${idVendor}_${idProduct}"
    else
        while true; do
            read -p "$(get_message "enter_alias")" alias_name
            if validate_alias "$alias_name"; then
                if ! check_name_conflict "$alias_name"; then
                    break
                fi
            fi
        done
    fi

    check_root
    if ! backup_udev_rules; then
        log "ERROR" "$(get_message "backup_failed")"
        return
    fi
    if ! echo "SUBSYSTEM==\"tty\", ATTRS{idVendor}==\"$idVendor\", ATTRS{idProduct}==\"$idProduct\", SYMLINK+=\"$alias_name\"" | sudo tee -a "$DEVICE_RECORD_FILE" > /dev/null; then
        log "ERROR" "$(get_message "write_error")"
        return
    fi
    if ! reload_udev_rules; then
        log "ERROR" "$(get_message "reload_failed")"
        return
    fi
    log "INFO" "$(get_message "device_alias_applied") /dev/$alias_name"
    
    wait_for_symlink "$alias_name"
}

# 重新加载udev规则
reload_udev_rules() {
    check_root
    if ! sudo udevadm control --reload-rules; then
        log "ERROR" "$(get_message "reload_failed")"
        return 1
    fi
    if ! sudo udevadm trigger; then
        log "ERROR" "$(get_message "trigger_failed")"
        return 1
    fi
    log "INFO" "$(get_message "rules_reloaded")"
    return 0
}

# 等待符号链接创建
wait_for_symlink() {
    local alias_name=$1
    local counter=0
    while [ ! -e "/dev/$alias_name" ] && [ $counter -lt $MAX_RETRIES ]; do
        log "INFO" "$(get_message "waiting_symlink") ($(($counter + 1))/$MAX_RETRIES)"
        sleep 1
        counter=$((counter + 1))
    done

    if [ -e "/dev/$alias_name" ]; then
        if ! sudo chmod 666 "/dev/$alias_name" 2>/dev/null; then
            log "WARNING" "$(get_message "set_permission_error")"
        fi
        log "INFO" "$(get_message "symlink_created") /dev/$alias_name"
    else
        log "WARNING" "$(get_message "symlink_failed")"
        # 清理不完整的配置
        sudo sed -i "/SYMLINK+=\"$alias_name\"/d" "$DEVICE_RECORD_FILE"
        log "INFO" "$(get_message "incomplete_record_removed")"
    fi
}

# 查看已记录设备
view_recorded_devices() {
    log "INFO" "$(get_message "recorded_devices")"
    local devices=$(grep 'SYMLINK+=' "$DEVICE_RECORD_FILE" | sed 's/.*SYMLINK+="//; s/".*//')
    if [ -z "$devices" ]; then
        log "INFO" "$(get_message "no_devices")"
    else
        echo "$devices"
    fi
}

# 删除设备记录
delete_device_record() {
    local devices=$(grep 'SYMLINK+=' "$DEVICE_RECORD_FILE" | sed 's/.*SYMLINK+="//; s/".*//')
    if [ -z "$devices" ]; then
        log "INFO" "$(get_message "no_devices")"
        return
    fi

    log "INFO" "$(get_message "recorded_devices")"
    local i=1
    while IFS= read -r alias; do
        echo "$i) $alias"
        i=$((i+1))
    done <<< "$devices"

    echo "$i) $(get_message "return_menu")"

    local choice
    while true; do
        read -p "$(get_message "delete_device")" choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$i" ]; then
            break
        else
            log "ERROR" "$(get_message "invalid_choice")"
        fi
    done

    if [ "$choice" -eq "$i" ]; then
        log "INFO" "$(get_message "return_menu")"
        return
    fi

    local alias_to_delete=$(echo "$devices" | sed -n "${choice}p")
    
    log "INFO" "$(get_message "chosen_delete") $alias_to_delete"
    read -p "$(get_message "confirm_delete")" confirm
    if [ "$confirm" != "y" ]; then
        log "INFO" "$(get_message "delete_cancelled")"
        return
    fi

    if grep -q "SYMLINK+=\"$alias_to_delete\"" "$DEVICE_RECORD_FILE"; then
        check_root
        if ! backup_udev_rules; then
            log "ERROR" "$(get_message "backup_failed")"
            return
        fi
        if ! sudo sed -i "/SYMLINK+=\"$alias_to_delete\"/d" "$DEVICE_RECORD_FILE"; then
            log "ERROR" "$(get_message "delete_failed")"
            return
        fi
        if ! reload_udev_rules; then
            log "ERROR" "$(get_message "reload_failed")"
            return
        fi
        log "INFO" "$(get_message "device_deleted") $alias_to_delete"
    else
        log "WARNING" "$(get_message "device_not_found")"
    fi
}

# 重命名设备别名
rename_device_alias() {
    local old_alias=$1
    local devices

    if [ -z "$old_alias" ]; then
        devices=$(grep 'SYMLINK+=' "$DEVICE_RECORD_FILE" | sed 's/.*SYMLINK+="//; s/".*//')
        if [ -z "$devices" ]; then
            log "INFO" "$(get_message "no_devices")"
            return
        fi

        log "INFO" "$(get_message "recorded_devices")"
        local i=1
        while IFS= read -r alias; do
            echo "$i) $alias"
            i=$((i+1))
        done <<< "$devices"

        echo "$i) $(get_message "return_menu")"

        local choice
        while true; do
            read -p "$(get_message "rename_device")" choice
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$i" ]; then
                break
            else
                log "ERROR" "$(get_message "invalid_choice")"
            fi
        done

        if [ "$choice" -eq "$i" ]; then
            log "INFO" "$(get_message "return_menu")"
            return
        fi

        old_alias=$(echo "$devices" | sed -n "${choice}p")
    fi

    log "INFO" "$(get_message "chosen_rename") $old_alias"

    local new_alias
    while true; do
        read -p "$(get_message "new_alias")" new_alias
        if validate_alias "$new_alias"; then
            if ! check_name_conflict "$new_alias"; then
                break
            fi
        fi
    done

    if grep -q "SYMLINK+=\"$old_alias\"" "$DEVICE_RECORD_FILE"; then
        check_root
        if ! backup_udev_rules; then
            log "ERROR" "$(get_message "backup_failed")"
            return
        fi
        if ! sudo sed -i "s/SYMLINK+=\"$old_alias\"/SYMLINK+=\"$new_alias\"/" "$DEVICE_RECORD_FILE"; then
            log "ERROR" "$(get_message "rename_failed")"
            return
        fi
        if ! reload_udev_rules; then
            log "ERROR" "$(get_message "reload_failed")"
            return
        fi
        log "INFO" "$(get_message "device_renamed") '$old_alias' $(get_message "to") '$new_alias'"
    else
        log "WARNING" "$(get_message "device_not_found")"
    fi
}

# 显示所有设备的详细信息
show_detailed_device_info() {
    log "INFO" "$(get_message "retrieving_info")"
    local devices=$(grep 'SYMLINK+=' "$DEVICE_RECORD_FILE" | sed 's/.*SYMLINK+="//; s/".*//')
    if [ -z "$devices" ]; then
        log "INFO" "$(get_message "no_devices")"
        return
    fi

    log "INFO" "$(get_message "detailed_info")"
    echo "--------------------------------"
    
    local i=1
    while IFS= read -r alias; do
        echo "[$i] $(get_message "alias") $alias"
        local device_rule=$(grep "SYMLINK+=\"$alias\"" "$DEVICE_RECORD_FILE")
        local idVendor=$(echo "$device_rule" | grep -o 'idVendor=="[^"]*' | cut -d'"' -f3)
        local idProduct=$(echo "$device_rule" | grep -o 'idProduct=="[^"]*' | cut -d'"' -f3)
        
        echo "    $(get_message "vendor_id") $idVendor"
        echo "    $(get_message "product_id") $idProduct"
        
        if [ -e "/dev/$alias" ]; then
            echo "    $(get_message "status_connected")"
            local serial=$(udevadm info -a -n "/dev/$alias" | grep -m1 -E 'ATTRS{serial}|ATTRS{SerialNumber}' | cut -d'"' -f2)
            echo "    $(get_message "serial_number") $serial"
        else
            echo "    $(get_message "status_disconnected")"
        fi
        echo "--------------------------------"
        i=$((i+1))
    done <<< "$devices"
}

# 检查名称冲突
check_name_conflict() {
    local alias_name=$1
    if grep -q "SYMLINK+=\"$alias_name\"" "$DEVICE_RECORD_FILE"; then
        log "WARNING" "$(get_message "alias_in_use")"
        return 1
    fi
    return 0
}

# 显示主菜单
show_menu() {
    echo "$(get_message "menu_title")"
    echo "1. $(get_message "menu_1")"
    echo "2. $(get_message "menu_2")"
    echo "3. $(get_message "menu_3")"
    echo "4. $(get_message "menu_4")"
    echo "5. $(get_message "menu_5")"
    echo "6. $(get_message "menu_6")"
    read -p "$(get_message "choose_option")" choice
    case $choice in
        1) detect_new_device ;;
        2) view_recorded_devices ;;
        3) show_detailed_device_info ;;
        4) delete_device_record ;;
        5) rename_device_alias ;;
        6)
            log "INFO" "$(get_message "exiting_program")"  # 添加日志
            exit 0 ;;
        *) echo "$(get_message "invalid_choice")" ;;
    esac
}

# 主程序
main() {
    initialize
    create_lock
    while true; do
        show_menu
    done
}

main