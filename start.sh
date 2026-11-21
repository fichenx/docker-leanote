#!/bin/sh
# Leanote 启动脚本：-srcPath 指定打包布局，Revel 据此定位框架与应用目录
# /opt/gopath/src/github.com/revel/revel      框架源码（conf、templates）
# /opt/gopath/src/github.com/leanote/leanote  软链到 /data/leanote
set -e
cd /data/leanote/bin
exec ./leanote -importPath github.com/leanote/leanote -srcPath /opt/gopath/src "$@"
