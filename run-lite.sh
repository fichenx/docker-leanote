#!/bin/bash
# lite: 只有 Leanote 程序，无 PDF 导出、无数据库备份工具
set -euo pipefail

mkdir -p /data/leanote/conf /data/leanote/bin /data/leanote/app /data/leanote/public/upload /data/leanote/files
if [ ! -f /data/leanote/conf/app.conf ]; then
    cp /opt/leanote/conf/app.conf /data/leanote/conf/app.conf
    echo "first run, replace secret"
    secret="$(cat /proc/sys/kernel/random/uuid)$(cat /proc/sys/kernel/random/uuid)"
    sed -i "s|^app.secret=.*|app.secret=${secret}|" /data/leanote/conf/app.conf
    echo "请把 /data/leanote/conf/app.conf 里的 db.host 改成你的 MongoDB 地址"
fi

# conf/routes 每次都要同步，缺失会导致 Revel 路由初始化失败、进程反复重启
cp -f /opt/leanote/conf/routes /data/leanote/conf/routes
cp -f /opt/leanote/bin/leanote /data/leanote/bin/leanote
cp -rf /opt/leanote/app/views /data/leanote/app/
cp -rf /opt/leanote/messages /data/leanote/
cp -rf /opt/leanote/public/. /data/leanote/public/

echo "$(date '+%Y-%m-%d %H:%M:%S') >>>>>> start leanote service"
exec /usr/local/bin/start.sh
