#!/bin/bash
set -euo pipefail

# 数据库只监听容器内回环地址, 即使误映射端口也无法从外部直连
mkdir -p /data/db
echo "start mongod (bind 127.0.0.1 only)"
mongod --bind_ip 127.0.0.1 --logpath /data/db/mongod.log --logappend --fork

# 等待 mongod 真正可连接, 最多 60 秒, 避免恢复数据时抢跑
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

# 数据库未导入
if [ ! -f "/data/db/do_not_delete" ]; then
    echo "Initial mongo data"
    mongorestore -h 127.0.0.1 -d leanote --dir /root/leanote/mongodb_backup/leanote_install_data/
    # 只有恢复成功(set -e 已保证)才写完成标记, 避免以后永久跳过初始化
    echo "do not delete this file" >> /data/db/do_not_delete
    chmod 400 /data/db/do_not_delete
fi

# conf不存在
if [ ! -f '/data/leanote/conf/app.conf' ]; then
    mkdir -p /data/leanote/conf/
    cp /root/leanote/conf/app.conf /data/leanote/conf/app.conf

    echo "first run, replace secret"
    # 整行替换, 不依赖 grep 的输出格式; 拼接两个 uuid 保证长度足够
    secret="$(cat /proc/sys/kernel/random/uuid)$(cat /proc/sys/kernel/random/uuid)"
    sed -i "s|^app.secret=.*|app.secret=${secret}|" /data/leanote/conf/app.conf
fi

# 只补齐缺失文件, 不覆盖已有的 conf / files / public/upload
cp -rn /root/leanote/. /data/leanote/
rm -rf /root/leanote/

echo "$(date '+%Y-%m-%d %H:%M:%S') >>>>>> start leanote service"
# exec 让 Leanote 接管 PID 1, 容器收到 SIGTERM 时可以优雅退出
exec /data/leanote/bin/run.sh
