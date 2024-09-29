# 设备别名管理器

[English](README.md) | [日本語](README_ja.md)

设备别名管理器是一个用于管理USB设备别名的Bash脚本工具。它允许用户检测新设备、查看已记录的设备、显示设备详细信息、删除设备记录以及重命名设备别名。

## 功能

- 检测新的（USB）设备连接
- 为新设备分配别名
- 查看已记录的设备列表
- 显示设备详细信息
- 删除设备记录
- 重命名设备别名
- 多语言支持（英语、中文、日语）
- 自动语言检测
- 可配置的设置
- 日志功能
- udev规则的备份管理

## 安装

1. 克隆仓库：
   ```bash
   git clone https://github.com/XKHoshizora/dev-mgmt-tools.git
   ```
2. 进入项目目录：
   ```bash
   cd dev-mgmt-tools
   ```
3. 确保脚本具有执行权限：
   ```bash
   chmod +x dev_alias_manager.sh
   ```

## 使用方法

运行脚本：

```bash
sudo ./dev_alias_manager.sh
```

注意：某些操作（例如修改 udev 规则）需要 `root` 权限，因此建议使用 `sudo` 运行脚本。

根据屏幕提示选择操作：

1. 检测新设备
2. 查看已记录的设备
3. 显示设备详细信息
4. 删除设备记录
5. 重命名设备别名
6. 退出

## 配置

配置文件位于 `config/dev_alias_manager.conf`，可以自定义以下设置：

- `MAX_RETRIES`：创建符号链接的最大重试次数
- `TIMEOUT`：设备操作的超时时间
- `DEVICE_RECORD_FILE`：udev 规则文件的位置
- `LOG_LEVEL`：日志级别（DEBUG、INFO、WARNING、ERROR）
- `AUTO_NAMING`：启用/禁用自动设备命名
- `AUTO_NAME_PREFIX`：自动生成名称的前缀
- `LANGUAGE`：强制指定语言（en、zh、ja）
- `MAX_BACKUPS`：保留的备份文件的最大数量

默认配置文件 `dev_alias_manager.conf.default` 可作为模板使用。

## 日志

日志文件位于 `logs/dev_alias_manager.log`。

## 语言支持

脚本会自动检测系统语言，并根据需要显示英语、中文或日语的提示信息。如果您的系统语言不在支持列表中，将默认使用英语。您也可以在配置文件中手动设置语言。

## 备份

脚本在修改 `udev` 规则文件之前会创建备份。备份文件存储在 `backups` 目录中，可以配置保留的备份数量。

## 注意事项

- 此脚本会修改系统的 `udev` 规则，请谨慎使用。
- 每次操作前都会创建 `udev` 规则文件的备份。
- 如果遇到问题，请查看日志文件获取更多信息。
- 脚本使用锁文件来防止多个实例同时运行。

## 贡献

欢迎通过问题和拉取请求帮助改进此项目。

## 许可证

此项目根据 MIT 许可证授权，详细信息请参见 [LICENSE](LICENSE) 文件。