**注意：本仓库已删除大文件并强制提交。**

**Attention: this repo has removed big file and force commited.**

---

# Docker运行[蚂蚁笔记](https://leanote.com/ '官网')

![Screen shot](./leanote-cn.png)

- [简体中文](./README.md)

- [English](./README-EN.md)

镜像提供三个变体，由 GitHub Actions 使用 buildx 构建多架构 manifest：`linux/amd64`、`linux/arm64`，`lite` 额外支持 `linux/arm/v7`，构建阶段用 Go 1.15 交叉编译，ARM 上不依赖 QEMU 模拟。

**注意：本仓库的镜像名是 `fichenx/leanote`，不是 axboy/leanote。**

## 版本与标签

- 稳定版：保持上游 `leanote/leanote` 2.6.1 原样，标签 `<变体>`、`2.6.1-<变体>`，`latest` 指向 full。
- 修复版：跟随 GitHub Release 版本号打标签，源码取自 `fichenx/leanote` 同名 tag（默认密钥校验、Cookie 加固、导出 PDF 签名校验、API 越权修复、文档导航修复等）。

| 变体 | 稳定版标签 | 修复版标签（以 2.6.1-hardened 为例） |
| --- | --- | --- |
| full | `full`、`latest`、`2.6.1-full` | `2.6.1-hardened`、`2.6.1-hardened-full` |
| nodb | `nodb`、`2.6.1-nodb` | `2.6.1-hardened-nodb` |
| lite | `lite`、`2.6.1-lite` | `2.6.1-hardened-lite` |

| 变体 | 数据库 | PDF 导出 | 数据库备份 | 架构 |
| --- | --- | --- | --- | --- |
| full | 内置 MongoDB 4.2 | ✅ | ✅ | amd64 / arm64 |
| nodb | 需外接 | ✅ | ✅（需能连到 mongodump 可用环境） | amd64 / arm64 |
| lite | 需外接 | ❌ | ❌ | amd64 / arm64 / armv7 |

## 快速开始

```bash
# full：一条命令跑起来，数据在 leanote-data 卷里
docker run -d --name leanote -p 9000:9000 -v leanote-data:/data fichenx/leanote:full

# nodb / lite：数据目录挂出来，首次启动后按需改 conf/app.conf 里的 db.host
docker run -d --name leanote -p 9000:9000 -v $PWD/leanote-data:/data/leanote fichenx/leanote:nodb

# 修复版（安全加固 + 文档导航修复），标签跟随 GitHub Release 版本号
docker run -d --name leanote -p 9000:9000 -v leanote-data:/data fichenx/leanote:2.6.1-hardened
```

默认管理员 `admin / abc123`，登录后请立即修改密码。首次启动会自动生成随机 `app.secret`（长度 72），不要把它改回默认值，否则启用了启动校验的 Leanote 构建会拒绝启动。

## 数据库配置(nodb/lite版使用)

[初始化数据库看这里](https://github.com/leanote/leanote/wiki/Leanote-二进制版详细安装教程----Mac-and-Linux#3-导入初始数据)

导入数据库后，以下配置根据实际环境修改

```conf
# mongdb
db.host=192.168.1.20
db.port=27017
db.dbname=leanote # required
db.username= # if not exists, please leave it blank
db.password= # if not exists, please leave it blank
# or you can set the mongodb url for more complex needs the format is:
# mongodb://myuser:mypass@localhost:40001,otherhost:40001/mydb
# db.url=mongodb://root:root123@localhost:27017/leanote
# db.urlEnv=${MONGODB_URL} # set url from env. eg. mongodb://root:root123@localhost:27017/leanote
```

## 数据目录简介

为方便修改配置和迁移数据，建议映射如下文件夹。

```
/data/db                # 内置mongodb的数据目录，nodb版无此目录
/data/leanote/conf      # 笔记的配置文件目录
/data/leanote/files     # 笔记内上传的图片、文件存放目录
/data/leanote/public/upload     # 头像上传路径
```

## 运行

```sh
docker run -d --name leanote \
    -v `pwd`/db:/data/db \
    -v `pwd`/conf/:/data/leanote/conf \
    -v `pwd`/files:/data/leanote/files \
    -v `pwd`/upload:/data/leanote/public/upload \
    -p 9000:9000 \
    fichenx/leanote:full
```

`nodb` / `lite` 没有内置数据库，只挂载 `/data/leanote` 下的 conf/files/upload 即可。

## 备份数据

- 方案一

通过备份文件来备份数据，数据库版本大更时不兼容，比如mongo:3.2到mongo:3.4

- 方案二

使用admin账号到管理后台备份，lite版不支持

- 方案三

自行通过mongodump备份

个人更倾向于方案一，因为数据库不包含上传的文件，不是仅仅备份数据库就行

## 修改时区

默认为北京时间，如需修改，参考如下命令。

```sh
ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo "Asia/Shanghai" > /etc/timezone
```

## 安全说明（本仓库加固内容）

- 容器只暴露 9000，MongoDB 由 `run.sh` 以 `--bind_ip 127.0.0.1` 启动，**不再**对外暴露 27017；
  即使误加 `-p 27017:27017` 也无法从容器外直连数据库。
- 首次启动自动生成随机 `app.secret`（整行替换，不再依赖 grep 的输出），并声明了
  `/data/db`、`/data/leanote/conf`、`/data/leanote/files`、`/data/leanote/public/upload` 数据卷。
- 初始化使用 `set -euo pipefail`，会等待 MongoDB `ping` 成功后再恢复数据，恢复成功才写完成标记；
  升级时只补齐缺失文件，不再覆盖已有的 conf/files/upload。
- 构建时可通过 `--build-arg LEANOTE_SHA256=<sha256>` 校验 Leanote 安装包（上游只提供 http 源）。
- 已内置 `HEALTHCHECK`，`CMD` 使用 exec 形式，Leanote 作为 PID 1 可正常接收退出信号。

## [常见问题](https://github.com/leanote/leanote/wiki/QA)

- 2.6版启动后不能访问

2.6版默认绑定localhost, 不能通过ip访问Leanote,
请修改 app.conf

```
http.addr=0.0.0.0 # listen on all ip addresses
```

重启Leanote

## 其它

- 初始用户

```
user1 username: admin, password: abc123 (管理员, 只有该用户才有权管理后台, 请及时修改密码)
user2 username: demo@leanote.com, password: demo@leanote.com (仅供体验使用)
```

- 禁用demo用户

demo用户就是一个普通用户，能随意操作，建议禁掉，nginx禁用 **/demo** 路径

```
server { 
    # 省略部分

    location / {
        proxy_pass              http://172.17.0.1:9000;
        proxy_set_header        Host            $host;
        proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-For $remote_addr;
    }
    location /demo {
        deny all;
    }
}

```

- 修改site.url

文件conf/app.conf内，修改site.url为你对应的访问路径，否则在个人主页无法退出登录，博客页面的部分资源无法加载

- [ssl](https://github.com/axboy/docker-leanote/issues/5)

```
http.ssl=true
http.sslcert=/data/leanote/conf/xxxxx.pem
http.sslkey=/data/leanote/conf/xxxxx.key
```

## mongodb升级

原有2.6.1的版本，mongodb为3.2，现有的latest的mongodb版本为4.2.7，直接映射文件会导致启动失败。
可使用浏览器登录管理账号，在后台备份数据库，下载到本地并启动一个新版本容器，参考命令如下

```sh
# 将下载的文件拷贝到新容器
docker cp ~/download/backup_leanote_1602120903 new_leanote:/

# 进入容器
docker exec -it new_leanote bash

# 恢复备份的数据库
mongorestore -h localhost -d leanote --dir /backup_leanote_1602120903/  --drop
```

## 补充

- 关于自定义数据库的，可参考[布宝的慕课手记](https://www.imooc.com/article/49225)
