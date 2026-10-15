# cloudstudio-ops2 — 容器自动部署通道(公开)

本仓库是腾讯 Cloud Studio 容器内飞书命令机器人的**自更新通道**。
容器内的 `feishu-bot.py` 每 60 秒轮询本仓库的 `manifest.json`;版本变化时
下载清单文件、逐一 sha256 校验、先落 `.new` 再原子替换;`restart: bot`
时机器人进程退出,由 supervisor 循环在 10 秒内拉起新代码。

**本仓库只含部署脚本,绝不含任何密钥**(凭证全部在容器内本地文件中)。

## 文件

| 文件 | 说明 |
| --- | --- |
| `feishu-bot.py` | 飞书命令机器人:长连接收命令、本地执行、卡片回显 |
| `run-bots.sh` | 容器启动链:状态页 + 机器人 + cc-connect(仅随本通道更新) |
| `manifest.json` | 版本清单:`version` / `files[].sha256` / `restart` |

## 流程

1. 本机更新脚本 → 重新生成 `manifest.json`(sha256 对应新字节)→ 推送本仓库
2. 容器内机器人下一轮轮询(≤60 秒)发现 `version` 变化
3. 下载 → 校验 → 替换 → 按 `restart` 重启自身

回滚:把 `version` 改回旧值并推送对应旧文件即可(同样走校验替换)。
