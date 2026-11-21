#!/bin/sh
# Leanote 启动脚本：-srcPath 指定打包布局，Revel 据此定位框架与应用目录
set -e
cd /data/leanote/bin
exec ./leanote -importPath github.com/leanote/leanote -srcPath /opt/gopath/src "$@"
