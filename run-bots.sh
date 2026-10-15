#!/usr/bin/env bash
# 容器启动脚本:预览状态页 + 飞书命令机器人(monkeycode App)+ cc-connect(monkey 套 11 台)。
# 由 .vscode/preview.yml 在 IDE 打开时触发;保活 Worker 的恢复链依赖本脚本自启服务。
# 基底:icgsqq 的 run-new-api.sh —— 去掉 new-api 段(新容器不装 new-api),其余启动语义保持一比一。
set -Eeuo pipefail
umask 077

APP_DIR="${APP_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)}"
LOG_DIR="$APP_DIR/logs"
PY_LIBS="$APP_DIR/pylibs"
PREVIEW_DIR="$APP_DIR/preview-page"
cd "$APP_DIR"

mkdir -p "$LOG_DIR"

# ---- 预览状态页(端口 3000,秒级就绪):preview.yml 的 mainPort 承接 ----
if command -v python3 >/dev/null 2>&1 && ! pgrep -f "http.server 3000" >/dev/null 2>&1; then
  setsid python3 -m http.server 3000 --directory "$PREVIEW_DIR" >>"$LOG_DIR/preview.log" 2>&1 </dev/null &
fi

# ---- 飞书命令机器人(monkeycode App):文件齐全时随服务启动,崩溃自动重启 ----
# setsid 让守护循环脱离 VS Code task 进程树,IDE 会话结束时不会被连带清理。
# lark-oapi 缓存在 /workspace/pylibs:容器每次重启系统 site-packages 都会重置,
# 不缓存则每次恢复都要重新 pip install(1 核机器上可达 20 分钟以上);
# 缓存命中时跳过安装直接启动,机器人在恢复后数秒内就绪。
if [[ -f "$APP_DIR/feishu-bot.py" && -f "$APP_DIR/feishu-bot-config.json" ]] \
   && command -v python3 >/dev/null 2>&1 \
   && ! pgrep -f "feishu-bot.py" >/dev/null 2>&1; then
  echo "Starting feishu command bot..."
  if ! PYTHONPATH="$PY_LIBS" python3 -c "import lark_oapi" >/dev/null 2>&1; then
    python3 -m pip install --quiet --disable-pip-version-check \
      --target "$PY_LIBS" \
      -i https://mirrors.cloud.tencent.com/pypi/simple lark-oapi \
      || python3 -m pip install --quiet --disable-pip-version-check \
        --target "$PY_LIBS" lark-oapi \
      || echo "WARN: lark-oapi 安装失败,跳过飞书机器人" >&2
  fi
  if PYTHONPATH="$PY_LIBS" python3 -c "import lark_oapi" >/dev/null 2>&1; then
    export APP_DIR LOG_DIR PY_LIBS
    setsid bash -c 'while true; do PYTHONPATH="$PY_LIBS" python3 "$APP_DIR/feishu-bot.py" >>"$LOG_DIR/feishu-bot.log" 2>&1; echo "$(date "+%F %T") bot exited, restart in 10s" >>"$LOG_DIR/feishu-bot.log"; sleep 10; done' </dev/null >/dev/null 2>&1 &
  fi
fi

# ---- cc-connect(飞书 codex/claude 机器人,monkey 套):随服务启动,幂等 ----
# 装在 /workspace/cc-connect(见部署包);目录不在时静默跳过。
if [[ -f /workspace/cc-connect/start-all.sh ]]; then
  setsid bash /workspace/cc-connect/start-all.sh </dev/null >/dev/null 2>&1 &
fi

# task 前台保持一个交互 shell:
# 1. 终端里始终有 shell 读 stdin,云端浏览器可直连此终端执行运维命令
#    (Cloud Studio 的快捷键在无头浏览器里不可靠,不能依赖"新建终端");
# 2. task 主进程不退出,进程树不会被 VS Code 清理。
exec bash
