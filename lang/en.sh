#!/bin/bash
# -*- coding: utf-8 -*-

# 向 MESSAGES 数组中添加键值对
MESSAGES[menu_title]="USB Device Manager"
MESSAGES[menu_1]="Listen for new devices"
MESSAGES[menu_2]="View recorded devices"
MESSAGES[menu_3]="Show detailed device information"
MESSAGES[menu_4]="Delete device record"
MESSAGES[menu_5]="Rename device alias"
MESSAGES[menu_6]="Exit"
MESSAGES[choose_option]="Please choose an option (1-6): "
MESSAGES[invalid_choice]="Invalid choice, please try again."
MESSAGES[sudo_required]="Error: This script requires sudo privileges to run."
MESSAGES[config_missing]="Warning: Both user and default configuration files are missing."
MESSAGES[config_created]="Created user configuration file from default template."
MESSAGES[waiting_device]="Waiting for USB device connection..."
MESSAGES[device_removed]="Unable to get new device info, the device may have been removed."
MESSAGES[enter_alias]="Please specify an alias for this device: "
MESSAGES[write_error]="Unable to write to device record file."
MESSAGES[config_error]="Error in configuration file. Using default values."
MESSAGES[new_device_detected]="New device detected..."
MESSAGES[new_device]="New device:"
MESSAGES[device_info]="Device information:"
MESSAGES[device_recorded]="This device has already been recorded."
MESSAGES[recording_device]="Recording new device..."
MESSAGES[device_alias_applied]="Device recorded and alias applied:"
MESSAGES[waiting_symlink]="Waiting for device symlink creation..."
MESSAGES[symlink_created]="Symlink created and permissions set:"
MESSAGES[symlink_failed]="Symlink creation failed, the device may have been unplugged."
MESSAGES[no_devices]="No devices recorded yet."
MESSAGES[recorded_devices]="Recorded devices:"
MESSAGES[return_menu]="Return to main menu"
MESSAGES[delete_device]="Enter the number of the device to delete, or choose to return: "
MESSAGES[confirm_delete]="Confirm deletion? (y/n): "
MESSAGES[delete_cancelled]="Deletion cancelled."
MESSAGES[device_deleted]="Device record deleted:"
MESSAGES[device_not_found]="Specified device record not found."
MESSAGES[rename_device]="Enter the number of the device to rename, or choose to return: "
MESSAGES[new_alias]="Enter the new alias: "
MESSAGES[device_renamed]="Device renamed from"
MESSAGES[to]="to"
MESSAGES[detailed_info]="Detailed information for recorded devices:"
MESSAGES[alias]="Alias:"
MESSAGES[vendor_id]="Vendor ID:"
MESSAGES[product_id]="Product ID:"
MESSAGES[status_connected]="Status: Connected"
MESSAGES[status_disconnected]="Status: Not connected"
MESSAGES[serial_number]="Serial Number:"
MESSAGES[alias_in_use]="Alias is already in use. Please choose another alias."
MESSAGES[invalid_alias]="Invalid alias. Please use only letters, numbers, underscores, and hyphens."
MESSAGES[alias_too_long]="Alias too long. Please limit to 32 characters."
MESSAGES[backup_failed]="Failed to backup udev rules file. Operation cancelled."
MESSAGES[reload_failed]="Failed to reload udev rules."
MESSAGES[update_alias]="Do you want to update this device's alias? (y/n): "
MESSAGES[keep_alias]="Keeping the existing alias."
MESSAGES[creating_device_record]="Creating device record file:"
MESSAGES[create_file_error]="Unable to create device record file."
MESSAGES[set_permission_error]="Unable to set permissions for device record file."
MESSAGES[another_instance]="Error: Another instance is running."
MESSAGES[stale_lock]="Warning: Detected a stale lock file. Cleaning up..."
MESSAGES[cleaning_up]="Cleaning up and exiting..."
MESSAGES[backup_success]="Backed up udev rules file to"
MESSAGES[old_backups_deleted]="Old backup files have been deleted."
MESSAGES[existing_alias]="Existing alias:"
MESSAGES[chosen_delete]="You've chosen to delete:"
MESSAGES[delete_failed]="Failed to delete device record."
MESSAGES[chosen_rename]="You've chosen to rename:"
MESSAGES[rename_failed]="Failed to rename device alias."
MESSAGES[retrieving_info]="Retrieving detailed information for all recorded devices..."
MESSAGES[trigger_failed]="Failed to trigger udev events."
MESSAGES[rules_reloaded]="Reloaded udev rules"
MESSAGES[incomplete_record_removed]="Incomplete record removed from configuration file."
MESSAGES[detection_complete]="Device detection complete."
MESSAGES[config_error_details]="Unable to find configuration file or default configuration file."
MESSAGES[config_expected_location]="Expected configuration file location:"
MESSAGES[default_config_expected_location]="Expected default configuration file location:"
MESSAGES[program_terminating]="Program terminating due to configuration error."
MESSAGES[waiting_device_settle]="Waiting for device tree to settle..."
MESSAGES[udevadm_settle_failed]="Failed to settle device tree."
MESSAGES[waiting_for_device]="Waiting for device node to become available..."
MESSAGES[device_ready]="Device is ready:"
MESSAGES[device_not_ready]="Device is not ready after retries."
MESSAGES[udevadm_missing]="udevadm command is missing. Please install it to proceed."
MESSAGES[serial_not_found]="Serial number not found for the device."
MESSAGES[udevadm_settle_failed]="udevadm settle command failed."
MESSAGES[device_processed]="Device successfully processed:"
MESSAGES[device_processing_busy]="Another device is being processed. Skipping this device."
MESSAGES[exiting_program]="Exiting the program."
