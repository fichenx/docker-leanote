# 蚂蚁笔记 Leanote

[Leanote](https://leanote.com)（蚂蚁笔记）是一款开源的知识管理工具，集笔记、博客、分享与协作于一体，支持 Markdown 与富文本编辑、笔记本树、标签、全文搜索、附件管理、公开博客、笔记分享与团队协作，可用于搭建个人知识库或团队文档平台。

![Leanote 界面](https://raw.githubusercontent.com/fichenx/docker-leanote/master/leanote-cn.png)

- 项目地址：https://github.com/leanote/leanote
- 镜像仓库：https://github.com/fichenx/docker-leanote

## 镜像版本

本仓库同时提供两套镜像：

- **官方原版**：`2.6.1` 系列，源码取自上游 `leanote/leanote` 2.6.1，未做任何修改。
- **修复版**：`2.6.1-hardened` 系列，在官方 2.6.1 基础上修复网页版文档导航与安全问题；从下一个版本起直接使用版本号（如 `2.6.2`），不再带 `hardened` 后缀。

| 变体 | 说明 | 官方原版标签 | 修复版标签 |
| --- | --- | --- | --- |
| full | 完整功能，内置 MongoDB | `2.6.1-full` | `2.6.1-hardened`、`2.6.1-hardened-full` |
| nodb | 完整功能，不含数据库，需外接 MongoDB | `2.6.1-nodb` | `2.6.1-hardened-nodb` |
| lite | 仅 leanote 程序，网页版不支持导出 PDF 和备份数据库，供客户端使用 | `2.6.1-lite` | `2.6.1-hardened-lite` |

`latest` 指向修复版 `2.6.1-hardened-nodb`（需自备 MongoDB）。稳定版保留 `full`、`nodb`、`lite` 等短标签，均基于官方原版 2.6.1。

| 变体 | 数据库 | 网页导出 PDF | 数据库备份 | 架构 |
| --- | --- | --- | --- | --- |
| full | 内置 MongoDB 4.2（仅监听 127.0.0.1） | 支持 | 支持 | amd64 / arm64 |
| nodb | 外接 | 支持 | 支持（需能连到 mongodump 可用环境） | amd64 / arm64 |
| lite | 外接 | 不支持 | 不支持 | amd64 / arm64 / armv7 |

## 使用方法

```bash
# full：内置数据库，一条命令启动，数据保存在 leanote-data 卷
docker run -d --name leanote -p 9000:9000 -v leanote-data:/data fichenx/leanote:2.6.1-hardened

# nodb / lite：把数据目录挂出来，首次启动后按需修改 conf/app.conf 的 db.host
docker run -d --name leanote -p 9000:9000 -v $PWD/leanote-data:/data/leanote fichenx/leanote:2.6.1-hardened-nodb
```

访问 `http://服务器地址:9000`，默认管理员 `admin / abc123`，登录后请立即修改密码。

- full 首次启动会自动导入初始数据；`/data` 内含数据库、配置、附件与上传文件，备份该目录即可。
- nodb / lite 需要先准备 MongoDB 并导入初始数据，再把 `conf/app.conf` 中的 `db.host` 指向数据库。
- 首次启动会生成随机 `app.secret`；启用了启动校验的修复版在 `app.secret` 为默认值时会拒绝启动，请勿改回默认值。

## 最新更新（2.6.1-hardened）

- **修复网页版文档导航点击无效**：Markdown 目录与富文本目录点击后可正常滚动到对应标题，标题含括号、引号时不再报错
- **安全加固**：`app.secret` 默认值校验、Cookie `HttpOnly`、导出 PDF 与 API 归属校验、附件打包 zip-slip 防护、搜索正则注入防护、服务端请求 SSRF 限制、评论与历史版本 XSS 修复、常用查询索引

> `2.6.1` 为官方原版，不含上述修复。
