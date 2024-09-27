# 设备别名管理器

[English](README.md) | [日本語](README_ja.md)

设备别名管理器是一个用于管理 USB 设备别名的 Bash 脚本工具。它允许用户监听新设备、查看已记录设备、显示设备详细信息、删除设备记录以及重命名设备别名。

## 功能

- 监听新 USB 设备的接入
- 为新设备分配别名
- 查看已记录的设备列表
- 显示设备的详细信息
- 删除设备记录
- 重命名设备别名
- 多语言支持（英语、中文、日语）
- 自动语言检测
- 可配置的设置
- 日志功能
- udev 规则的备份管理

## 安装

1. 克隆仓库：
   ```
   git clone https://github.com/XKHoshizora/dev-mgmt-tools.git
   ```
2. 进入项目目录：
   ```
   cd dev-mgmt-tools
   ```
3. 确保脚本有执行权限：
   ```
   chmod +x dev_alias_manager.sh
   ```

## 使用方法

运行脚本：

```
sudo ./dev_alias_manager.sh
```

注意：某些操作（如修改 udev 规则）需要 root 权限，因此建议使用 sudo 运行脚本。

按照屏幕上的提示选择操作：

1. 监听新设备
2. 查看已记录设备
3. 显示所有设备详细信息
4. 删除设备记录
5. 重命名设备别名
6. 退出

## 配置

配置文件位于 `config/dev_alias_manager.conf`。您可以自定义以下设置：

- `MAX_RETRIES`：符号链接创建的最大重试次数
- `TIMEOUT`：设备操作的超时时间
- `DEVICE_RECORD_FILE`：udev 规则文件的位置
- `LOG_LEVEL`：日志级别（DEBUG, INFO, WARNING, ERROR）
- `AUTO_NAMING`：启用/禁用自动设备命名
- `AUTO_NAME_PREFIX`：自动生成名称的前缀
- `LANGUAGE`：强制使用特定语言（en, zh, ja）
- `MAX_BACKUPS`：保留的最大备份文件数量

我们提供了一个默认的配置文件模板 `dev_alias_manager.conf.default`。

## 日志

日志文件位于 `logs/dev_alias_manager.log`。

## 语言支持

脚本会自动检测您的系统语言，并相应地以英语、中文或日语显示消息。如果您的系统语言不是这些语言之一，将使用英语作为默认语言。您也可以在配置文件中手动设置语言。

## 备份

脚本在进行更改之前会创建 udev 规则文件的备份。备份存储在 `backups` 目录中。可以配置保留的备份数量。

## 注意事项

- 本脚本修改系统 udev 规则，请谨慎使用。
- 在进行任何操作之前，脚本会创建 udev 规则文件的备份。
- 如遇到问题，请查看日志文件以获取更多信息。
- 脚本使用锁文件来防止多个实例同时运行。

## 贡献

欢迎提交 Issues 和 Pull Requests 来帮助改进这个项目。

## 许可

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。