#!/bin/sh
# Leanote 启动脚本：按官方包的 GOPATH 约定定位应用根目录
set -e
cd /data/leanote/bin
export GOPATH=/data/leanote
mkdir -p /data/leanote/src/github.com/leanote
ln -sfn ../../../ /data/leanote/src/github.com/leanote/leanote
exec ./leanote -importPath github.com/leanote/leanote "$@"
