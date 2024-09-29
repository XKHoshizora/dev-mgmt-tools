#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import subprocess
import time
import fcntl
import signal
import json
import re
import shutil
import glob
from typing import Dict, Any
import pyudev

# 全局变量
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_DIR = os.path.join(SCRIPT_DIR, "config")
CONFIG_FILE = os.path.join(CONFIG_DIR, "dev_alias_manager.conf")
DEFAULT_CONFIG_FILE = os.path.join(CONFIG_DIR, "dev_alias_manager.conf.default")
LOG_DIR = os.path.join(SCRIPT_DIR, "logs")
LOG_FILE = os.path.join(LOG_DIR, "dev_alias_manager.log")
TMP_DIR = os.path.join(SCRIPT_DIR, "tmp")
LOCK_FILE = os.path.join(TMP_DIR, "dev_alias_manager.lock")
BACKUP_DIR = os.path.join(SCRIPT_DIR, "backups")
LANG_DIR = os.path.join(SCRIPT_DIR, "lang")

# 配置
config: Dict[str, Any] = {}
MESSAGES: Dict[str, str] = {}

def check_sudo():
    if os.geteuid() != 0:
        print(get_message("sudo_required"))
        sys.exit(1)

def create_directories_and_files():
    os.makedirs(CONFIG_DIR, exist_ok=True)
    os.makedirs(LOG_DIR, exist_ok=True)
    os.makedirs(TMP_DIR, exist_ok=True)
    os.makedirs(BACKUP_DIR, exist_ok=True)
    
    if not os.path.exists(CONFIG_FILE) and os.path.exists(DEFAULT_CONFIG_FILE):
        with open(DEFAULT_CONFIG_FILE, 'r') as default_file, open(CONFIG_FILE, 'w') as config_file:
            config_file.write(default_file.read())
        print(get_message("config_created"))
    elif not os.path.exists(CONFIG_FILE) and not os.path.exists(DEFAULT_CONFIG_FILE):
        print(get_message("config_missing"))
        print(get_message("config_error_details"))
        print(f"{get_message('config_expected_location')} {CONFIG_FILE}")
        print(f"{get_message('default_config_expected_location')} {DEFAULT_CONFIG_FILE}")
        print(get_message("program_terminating"))
        sys.exit(1)
    
    open(LOG_FILE, 'a').close()

def load_config():
    global config
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, 'r') as f:
            config = json.load(f)
    else:
        print(get_message("config_error"))
        sys.exit(1)

    # 设置默认值并验证配置
    config['MAX_RETRIES'] = config.get('MAX_RETRIES', 5)
    config['TIMEOUT'] = config.get('TIMEOUT', 10)
    config['DEVICE_RECORD_FILE'] = config.get('DEVICE_RECORD_FILE', "/etc/udev/rules.d/99-usb.rules")
    config['LOG_LEVEL'] = config.get('LOG_LEVEL', "INFO")
    config['AUTO_NAMING'] = config.get('AUTO_NAMING', False)
    config['AUTO_NAME_PREFIX'] = config.get('AUTO_NAME_PREFIX', "usb-dev-")
    config['LANGUAGE'] = config.get('LANGUAGE', "")
    config['MAX_BACKUPS'] = config.get('MAX_BACKUPS', 5)

    # 验证配置值
    if not isinstance(config['MAX_RETRIES'], int) or config['MAX_RETRIES'] < 1:
        log("ERROR", get_message("config_error"))
        config['MAX_RETRIES'] = 5
    if not isinstance(config['TIMEOUT'], int) or config['TIMEOUT'] < 1:
        log("ERROR", get_message("config_error"))
        config['TIMEOUT'] = 10
    if not os.access(os.path.dirname(config['DEVICE_RECORD_FILE']), os.W_OK):
        log("ERROR", get_message("config_error"))
        config['DEVICE_RECORD_FILE'] = "/etc/udev/rules.d/99-usb.rules"
    if config['LOG_LEVEL'] not in ["DEBUG", "INFO", "WARNING", "ERROR"]:
        log("ERROR", get_message("config_error"))
        config['LOG_LEVEL'] = "INFO"
    if not isinstance(config['AUTO_NAMING'], bool):
        log("ERROR", get_message("config_error"))
        config['AUTO_NAMING'] = False
    if not config['AUTO_NAME_PREFIX']:
        log("ERROR", get_message("config_error"))
        config['AUTO_NAME_PREFIX'] = "usb-dev-"
    if not isinstance(config['MAX_BACKUPS'], int) or config['MAX_BACKUPS'] < 1:
        log("ERROR", get_message("config_error"))
        config['MAX_BACKUPS'] = 5

def check_device_record_file():
    if not os.path.exists(config['DEVICE_RECORD_FILE']):
        log("INFO", get_message("creating_device_record"))
        try:
            open(config['DEVICE_RECORD_FILE'], 'w').close()
            os.chmod(config['DEVICE_RECORD_FILE'], 0o644)
        except Exception as e:
            log("ERROR", f"{get_message('create_file_error')}: {str(e)}")
            sys.exit(1)

def initialize():
    set_language()
    check_sudo()
    
    if not shutil.which('udevadm'):
        print(get_message("udevadm_missing"))
        sys.exit(1)

    create_directories_and_files()
    load_config()
    check_device_record_file()
    check_and_clean_lock()

def set_language():
    global MESSAGES
    language = config.get('LANGUAGE', '')
    if not language:
        language = os.environ.get('LANG', 'en').split('_')[0]

    if language in ['zh', 'zh_CN', 'zh_TW']:
        language = 'zh'
    elif language in ['ja', 'ja_JP']:
        language = 'ja'
    else:
        language = 'en'

    lang_file = os.path.join(LANG_DIR, f"{language}.json")
    if os.path.exists(lang_file):
        with open(lang_file, 'r', encoding='utf-8') as f:
            MESSAGES = json.load(f)
    else:
        print(f"Warning: Language file not found. Using English as default.")
        with open(os.path.join(LANG_DIR, "en.json"), 'r', encoding='utf-8') as f:
            MESSAGES = json.load(f)

def get_message(key):
    return MESSAGES.get(key, key)

def log(level, message):
    log_levels = {"DEBUG": 1, "INFO": 2, "WARNING": 3, "ERROR": 4}
    if log_levels[level] >= log_levels[config['LOG_LEVEL']]:
        with open(LOG_FILE, 'a') as f:
            f.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')} - [{level}] {message}\n")
        print(f"[{level}] {message}")

def handle_error(message):
    log("ERROR", message)
    sys.exit(1)

def create_lock():
    try:
        with open(LOCK_FILE, 'w') as f:
            fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
            f.write(str(os.getpid()))
    except IOError:
        print(get_message("another_instance"))
        sys.exit(1)

def release_lock():
    if os.path.exists(LOCK_FILE):
        os.remove(LOCK_FILE)

def cleanup(signum, frame):
    log("INFO", get_message("cleaning_up"))
    release_lock()
    sys.exit(0)

signal.signal(signal.SIGINT, cleanup)
signal.signal(signal.SIGTERM, cleanup)

def check_and_clean_lock():
    if os.path.exists(LOCK_FILE):
        try:
            with open(LOCK_FILE, 'r') as f:
                pid = int(f.read().strip())
            os.kill(pid, 0)
        except (OSError, ValueError):
            print(get_message("stale_lock"))
            os.remove(LOCK_FILE)
        else:
            print(get_message("another_instance"))
            sys.exit(1)

def backup_udev_rules():
    check_sudo()
    backup_file = os.path.join(BACKUP_DIR, f"udev_rules_{time.strftime('%Y%m%d_%H%M%S')}.bak")
    try:
        shutil.copy2(config['DEVICE_RECORD_FILE'], backup_file)
        log("INFO", f"{get_message('backup_success')} {backup_file}")
    except Exception as e:
        log("ERROR", f"{get_message('backup_failed')}: {str(e)}")
        return False

    # 删除旧的备份文件
    backups = sorted(glob.glob(os.path.join(BACKUP_DIR, "udev_rules_*.bak")))
    if len(backups) > config['MAX_BACKUPS']:
        for old_backup in backups[:-config['MAX_BACKUPS']]:
            os.remove(old_backup)
        log("INFO", get_message("old_backups_deleted"))

    return True

def validate_alias(alias):
    if not re.match(r'^[a-zA-Z0-9_-]+$', alias):
        log("ERROR", get_message("invalid_alias"))
        return False
    if len(alias) > 32:
        log("ERROR", get_message("alias_too_long"))
        return False
    return True

def detect_new_device():
    log("INFO", get_message("waiting_device"))
    context = pyudev.Context()
    monitor = pyudev.Monitor.from_netlink(context)
    monitor.filter_by(subsystem='usb')

    for device in iter(monitor.poll, None):
        if device.action == 'add':
            log("INFO", get_message("new_device_detected"))
            device_path = device.sys_path
            log("DEBUG", f"Detected device at path: {device_path}")

            if not device_path:
                log("WARNING", get_message("device_path_not_found"))
                continue

            open(os.path.join(TMP_DIR, "device_processing.lock"), 'w').close()

            log("INFO", get_message("waiting_device_settle"))
            try:
                subprocess.run(["udevadm", "settle"], check=True, timeout=config['TIMEOUT'])
            except subprocess.SubprocessError:
                log("ERROR", get_message("udevadm_settle_failed"))
                time.sleep(3)
                os.remove(os.path.join(TMP_DIR, "device_processing.lock"))
                continue

            get_device_info(device_path)

            os.remove(os.path.join(TMP_DIR, "device_processing.lock"))
            log("INFO", f"{get_message('device_processed')} {device_path}")

    log("INFO", get_message("detection_complete"))

def get_device_info(device_path):
    device = pyudev.Device.from_sys_path(pyudev.Context(), device_path)
    log("DEBUG", f"Full device info: {device.properties}")

    devname = device.get('DEVNAME')
    log("DEBUG", f"Device node: {devname}")

    subsystem = device.subsystem
    idVendor = device.get('ID_VENDOR_ID')
    idProduct = device.get('ID_MODEL_ID')
    serial = device.get('ID_SERIAL_SHORT')
    model = device.get('ID_MODEL')

    if not serial:
        serial = device.get('ID_SERIAL') or device.get('ID_SERIAL_SHORT')

    if not idVendor or not idProduct:
        parent = device.find_parent(subsystem='usb', device_type='usb_device')
        if parent:
            idVendor = parent.get('ID_VENDOR_ID')
            idProduct = parent.get('ID_MODEL_ID')

    log("INFO", "Device Information:")
    log("INFO", f"Device Node: {devname}")
    log("INFO", f"Subsystem: {subsystem}")
    log("INFO", f"Vendor ID: {idVendor}")
    log("INFO", f"Product ID: {idProduct}")
    log("INFO", f"Serial: {serial}")
    log("INFO", f"Model: {model}")

    if idVendor and idProduct:
        with open(config['DEVICE_RECORD_FILE'], 'r') as f:
            if f"{idVendor}.*{idProduct}" in f.read():
                log("INFO", get_message("device_recorded"))
                handle_existing_device(idVendor, idProduct)
            else:
                record_new_device(idVendor, idProduct, serial, model, devname)
    else:
        log("WARNING", "Unable to determine vendor and product ID for this device")

def handle_existing_device(idVendor, idProduct):
    with open(config['DEVICE_RECORD_FILE'], 'r') as f:
        content = f.read()
    match = re.search(f"{idVendor}.*{idProduct}.*SYMLINK\\+=\"([^\"]+)\"", content)
    if match:
        existing_alias = match.group(1)
        log("INFO", f"{get_message('existing_alias')} {existing_alias}")
        
        update_choice = input(get_message("update_alias"))
        if update_choice.lower() == "y":
            rename_device_alias(existing_alias)
        else:
            log("INFO", get_message("keep_alias"))
    else:
        log("WARNING", "Failed to find existing alias in device record file")

def record_new_device(idVendor, idProduct, serial, model, devname):
    log("INFO", get_message("recording_device"))
    
    while True:
        alias_name = input(f"{get_message('enter_alias')} [{model}]: ").strip()
        log("DEBUG", f"User input alias: {alias_name}")

        if not alias_name:
            confirm = input(f"No alias entered. Do you want to use the model name [{model}] as the alias? (y/n): ")
            if confirm.lower() == "y":
                alias_name = model
            else:
                log("INFO", "Please enter a valid alias.")
                continue
        
        log("DEBUG", f"Alias after default handling: {alias_name}")

        if validate_alias(alias_name):
            log("DEBUG", f"Valid alias: {alias_name}")

            if not check_name_conflict(alias_name):
                break
            else:
                log("ERROR", f"Alias conflict: {alias_name} already in use. Please choose another alias.")
        else:
            log("ERROR", f"Invalid alias entered: {alias_name}. Please use only letters, numbers, underscores, and hyphens.")

    check_sudo()
    if not backup_udev_rules():
        log("ERROR", get_message("backup_failed"))
        return

    rule = f'SUBSYSTEM=="tty", ATTRS{{idVendor}}=="{idVendor}", ATTRS{{idProduct}}=="{idProduct}"'
    if serial:
        rule += f', ATTRS{{serial}}=="{serial}"'
    rule += f', SYMLINK+="{alias_name}"'

    try:
        with open(config['DEVICE_RECORD_FILE'], 'a') as f:
            f.write(rule + '\n')
    except IOError:
        log("ERROR", get_message("write_error"))
        return

    if not reload_udev_rules():
        log("ERROR", get_message("reload_failed"))
        return

    log("INFO", f"{get_message('device_alias_applied')} /dev/{alias_name}")

    wait_for_symlink(alias_name, devname)

def reload_udev_rules():
    check_sudo()
    try:
        subprocess.run(["udevadm", "control", "--reload-rules"], check=True)
        subprocess.run(["udevadm", "trigger"], check=True)
        log("INFO", get_message("rules_reloaded"))
        return True
    except subprocess.CalledProcessError:
        log("ERROR", get_message("reload_failed"))
        return False

def wait_for_symlink(alias_name, devname):
    counter = 0
    while not os.path.exists(f"/dev/{alias_name}") and counter < config['MAX_RETRIES']:
        log("INFO", f"{get_message('waiting_symlink')} ({counter + 1}/{config['MAX_RETRIES']})")
        time.sleep(1)
        counter += 1

    if os.path.exists(f"/dev/{alias_name}"):
        try:
            os.chmod(f"/dev/{alias_name}", 0o666)
        except OSError:
            log("WARNING", get_message("set_permission_error"))
        log("INFO", f"{get_message('symlink_created')} /dev/{alias_name}")
    else:
        log("WARNING", get_message("symlink_failed"))
        # 清理不完整的配置
        with open(config['DEVICE_RECORD_FILE'], 'r') as f:
            lines = f.readlines()
        with open(config['DEVICE_RECORD_FILE'], 'w') as f:
            f.writelines([line for line in lines if f'SYMLINK+="{alias_name}"' not in line])
        log("INFO", get_message("incomplete_record_removed"))

def view_recorded_devices():
    log("INFO", get_message("recorded_devices"))
    try:
        with open(config['DEVICE_RECORD_FILE'], 'r') as f:
            content = f.read()
        devices = re.findall(r'SYMLINK\+="([^"]+)"', content)
        if not devices:
            log("INFO", get_message("no_devices"))
        else:
            for device in devices:
                print(device)
    except IOError:
        log("ERROR", f"Unable to read {config['DEVICE_RECORD_FILE']}")

def delete_device_record():
    try:
        with open(config['DEVICE_RECORD_FILE'], 'r') as f:
            content = f.read()
        devices = re.findall(r'SYMLINK\+="([^"]+)"', content)
        if not devices:
            log("INFO", get_message("no_devices"))
            return

        log("INFO", get_message("recorded_devices"))
        for i, alias in enumerate(devices, 1):
            print(f"{i}) {alias}")

        print(f"{len(devices) + 1}) {get_message('return_menu')}")

        while True:
            try:
                choice = int(input(get_message("delete_device")))
                if 1 <= choice <= len(devices) + 1:
                    break
                else:
                    log("ERROR", get_message("invalid_choice"))
            except ValueError:
                log("ERROR", get_message("invalid_choice"))

        if choice == len(devices) + 1:
            log("INFO", get_message("return_menu"))
            return

        alias_to_delete = devices[choice - 1]
        
        log("INFO", f"{get_message('chosen_delete')} {alias_to_delete}")
        confirm = input(get_message("confirm_delete"))
        if confirm.lower() != "y":
            log("INFO", get_message("delete_cancelled"))
            return

        check_sudo()
        if not backup_udev_rules():
            log("ERROR", get_message("backup_failed"))
            return

        with open(config['DEVICE_RECORD_FILE'], 'r') as f:
            lines = f.readlines()
        with open(config['DEVICE_RECORD_FILE'], 'w') as f:
            f.writelines([line for line in lines if f'SYMLINK+="{alias_to_delete}"' not in line])

        if not reload_udev_rules():
            log("ERROR", get_message("reload_failed"))
            return

        log("INFO", f"{get_message('device_deleted')} {alias_to_delete}")
    except IOError:
        log("ERROR", get_message("delete_failed"))

def rename_device_alias(old_alias=None):
    if old_alias is None:
        try:
            with open(config['DEVICE_RECORD_FILE'], 'r') as f:
                content = f.read()
            devices = re.findall(r'SYMLINK\+="([^"]+)"', content)
            if not devices:
                log("INFO", get_message("no_devices"))
                return

            log("INFO", get_message("recorded_devices"))
            for i, alias in enumerate(devices, 1):
                print(f"{i}) {alias}")

            print(f"{len(devices) + 1}) {get_message('return_menu')}")

            while True:
                try:
                    choice = int(input(get_message("rename_device")))
                    if 1 <= choice <= len(devices) + 1:
                        break
                    else:
                        log("ERROR", get_message("invalid_choice"))
                except ValueError:
                    log("ERROR", get_message("invalid_choice"))

            if choice == len(devices) + 1:
                log("INFO", get_message("return_menu"))
                return

            old_alias = devices[choice - 1]
        except IOError:
            log("ERROR", "Unable to read device record file")
            return

    log("INFO", f"{get_message('chosen_rename')} {old_alias}")

    while True:
        new_alias = input(get_message("new_alias"))
        if validate_alias(new_alias) and not check_name_conflict(new_alias):
            break

    try:
        with open(config['DEVICE_RECORD_FILE'], 'r') as f:
            content = f.read()
        if f'SYMLINK+="{old_alias}"' in content:
            check_sudo()
            if not backup_udev_rules():
                log("ERROR", get_message("backup_failed"))
                return
            
            new_content = content.replace(f'SYMLINK+="{old_alias}"', f'SYMLINK+="{new_alias}"')
            with open(config['DEVICE_RECORD_FILE'], 'w') as f:
                f.write(new_content)

            if not reload_udev_rules():
                log("ERROR", get_message("reload_failed"))
                return

            log("INFO", f"{get_message('device_renamed')} '{old_alias}' {get_message('to')} '{new_alias}'")
        else:
            log("WARNING", get_message("device_not_found"))
    except IOError:
        log("ERROR", get_message("rename_failed"))

def show_detailed_device_info():
    log("INFO", get_message("retrieving_info"))
    try:
        with open(config['DEVICE_RECORD_FILE'], 'r') as f:
            content = f.read()
        devices = re.findall(r'ATTRS{idVendor}=="([^"]+)".*?ATTRS{idProduct}=="([^"]+)".*?SYMLINK\+="([^"]+)"', content, re.DOTALL)
        if not devices:
            log("INFO", get_message("no_devices"))
            return

        log("INFO", get_message("detailed_info"))
        print("--------------------------------")
        
        for i, (idVendor, idProduct, alias) in enumerate(devices, 1):
            print(f"[{i}] {get_message('alias')} {alias}")
            print(f"    {get_message('vendor_id')} {idVendor}")
            print(f"    {get_message('product_id')} {idProduct}")
            
            if os.path.exists(f"/dev/{alias}"):
                print(f"    {get_message('status_connected')}")
                try:
                    serial = subprocess.check_output(["udevadm", "info", "-a", "-n", f"/dev/{alias}"], 
                                                     universal_newlines=True)
                    serial = re.search(r'ATTRS{serial}=="([^"]*)"', serial)
                    if serial:
                        print(f"    {get_message('serial_number')} {serial.group(1)}")
                except subprocess.CalledProcessError:
                    print(f"    {get_message('serial_not_found')}")
            else:
                print(f"    {get_message('status_disconnected')}")
            print("--------------------------------")
    except IOError:
        log("ERROR", "Unable to read device record file")

def check_name_conflict(alias_name):
    try:
        with open(config['DEVICE_RECORD_FILE'], 'r') as f:
            content = f.read()
        if re.search(rf'SYMLINK\+="

{alias_name}"', content):
            log("WARNING", get_message("alias_in_use"))
            return True
    except IOError:
        log("ERROR", "Unable to read device record file")
    return False

def show_menu():
    print(get_message("menu_title"))
    print("1. " + get_message("menu_1"))
    print("2. " + get_message("menu_2"))
    print("3. " + get_message("menu_3"))
    print("4. " + get_message("menu_4"))
    print("5. " + get_message("menu_5"))
    print("6. " + get_message("menu_6"))
    
    choice = input(get_message("choose_option"))
    if choice == '1':
        detect_new_device()
    elif choice == '2':
        view_recorded_devices()
    elif choice == '3':
        show_detailed_device_info()
    elif choice == '4':
        delete_device_record()
    elif choice == '5':
        rename_device_alias()
    elif choice == '6':
        log("INFO", get_message("exiting_program"))
        sys.exit(0)
    else:
        print(get_message("invalid_choice"))

def main():
    initialize()
    create_lock()
    while True:
        show_menu()

if __name__ == "__main__":
    main()