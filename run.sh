#!/bin/bash
set -euo pipefail

# 数据库只监听容器内回环地址，即使误映射端口也无法从外部直连
mkdir -p /data/db
echo "start mongod (bind 127.0.0.1 only)"
mongod --bind_ip 127.0.0.1 --logpath /data/db/mongod.log --logappend --fork

# 等待 mongod 真正可连接，避免恢复数据时抢跑
echo "wait for mongod..."
for i in $(seq 1 60); do
    if mongo --quiet --host 127.0.0.1 --eval 'db.runCommand({ping:1}).ok' admin >/dev/null 2>&1; then
        echo "mongod is ready"
        break
    fi
    if [ "$i" -eq 60 ]; then
        echo "mongod not ready after 60s" >&2
        exit 1
    fi
    sleep 1
done

# 首次启动导入初始数据，成功后才写完成标记
if [ ! -f /data/db/do_not_delete ]; then
    echo "Initial mongo data"
    mongorestore -h 127.0.0.1 -d leanote --dir /opt/leanote/mongodb_backup/leanote_install_data/
    echo "do not delete this file" > /data/db/do_not_delete
    chmod 400 /data/db/do_not_delete
fi

# 首次启动生成配置，并替换默认密钥
mkdir -p /data/leanote/conf /data/leanote/bin /data/leanote/app /data/leanote/public/upload /data/leanote/files
if [ ! -f /data/leanote/conf/app.conf ]; then
    cp /opt/leanote/conf/app.conf /data/leanote/conf/app.conf
    echo "first run, replace secret"
    secret="$(cat /proc/sys/kernel/random/uuid)$(cat /proc/sys/kernel/random/uuid)"
    sed -i "s|^app.secret=.*|app.secret=${secret}|" /data/leanote/conf/app.conf
fi

# 程序与静态资源跟随镜像更新，用户配置与上传文件保留
cp -f /opt/leanote/bin/leanote /data/leanote/bin/leanote
cp -rf /opt/leanote/app/views /data/leanote/app/
cp -rf /opt/leanote/messages /data/leanote/
cp -rf /opt/leanote/public/. /data/leanote/public/

echo "$(date '+%Y-%m-%d %H:%M:%S') >>>>>> start leanote service"
exec /usr/local/bin/start.sh
