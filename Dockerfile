# syntax=docker/dockerfile:1
# full: 完整功能，内置 MongoDB
# 支持 linux/amd64、linux/arm64（mongo:4.2.7-bionic 官方镜像同时提供两种架构）

# ---------- 编译 Leanote ----------
# 用构建机架构运行 Go 工具链，再交叉编译出目标架构的静态二进制
FROM --platform=$BUILDPLATFORM golang:1.15-buster AS builder
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT
ARG LEANOTE_VERSION=2.6.1
# Leanote 2.6.1 是 GOPATH + vendor 布局，没有 go.mod
ENV GO111MODULE=off \
    CGO_ENABLED=0 \
    GOPATH=/go

RUN git clone --depth 1 --branch ${LEANOTE_VERSION} https://github.com/leanote/leanote.git /go/src/github.com/leanote/leanote
WORKDIR /go/src/github.com/leanote/leanote
# app/cmd 默认引用 vendor 中未修正的 revel harness，会生成带 vendor/ 前缀的 import；
# 改用仓库内已修正路径处理的 cmd/harness
RUN sed -i 's#"github.com/revel/cmd/harness"#"github.com/leanote/leanote/cmd/harness"#' app/cmd/main.go
# 生成器用构建机原生架构编译，再由它为目标架构生成 app/tmp 并编译
RUN go build -o /usr/local/bin/leanote-gen github.com/leanote/leanote/app/cmd
RUN mkdir -p /out && \
    GOOS=${TARGETOS} GOARCH=${TARGETARCH} GOARM=${TARGETVARIANT#v} leanote-gen && \
    cp /go/bin/revel.d/github.com/leanote/leanote/leanote /out/leanote

# ---------- 运行镜像 ----------
FROM mongo:4.2.7-bionic

ARG LEANOTE_VERSION=2.6.1
ENV TZ=Asia/Shanghai \
    QT_QPA_PLATFORM=offscreen \
    LEANOTE_VERSION=${LEANOTE_VERSION}

# mongo 镜像内置的 4.2 apt 源签名密钥已过期，且镜像里已装好 mongod，直接移除该源
RUN set -eux; \
    rm -f /etc/apt/sources.list.d/mongodb-org-*.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates wget tzdata \
        wkhtmltopdf xvfb \
        fonts-wqy-zenhei fonts-wqy-microhei; \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime; \
    echo $TZ > /etc/timezone; \
    rm -rf /var/lib/apt/lists/*

# 程序与静态资源模板，首次启动时复制到 /data/leanote
COPY --from=builder /out/leanote /opt/leanote/bin/leanote
COPY --from=builder /go/src/github.com/leanote/leanote/app/views /opt/leanote/app/views
COPY --from=builder /go/src/github.com/leanote/leanote/public /opt/leanote/public
COPY --from=builder /go/src/github.com/leanote/leanote/conf /opt/leanote/conf
COPY --from=builder /go/src/github.com/leanote/leanote/messages /opt/leanote/messages
COPY --from=builder /go/src/github.com/leanote/leanote/mongodb_backup /opt/leanote/mongodb_backup
COPY run.sh start.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/run.sh /usr/local/bin/start.sh

EXPOSE 9000
VOLUME ["/data"]
HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
    CMD wget -q -O /dev/null --timeout=5 http://127.0.0.1:9000/login || exit 1
CMD ["/usr/local/bin/run.sh"]
