# syntax=docker/dockerfile:1
# full: 完整功能，内置 MongoDB
# 支持 linux/amd64、linux/arm64（mongo:4.2.7-bionic 官方镜像同时提供两种架构）

# ---------- 编译 Leanote ----------
# 用构建机架构运行 Go 工具链，再交叉编译出目标架构的静态二进制
FROM --platform=$BUILDPLATFORM golang:1.15-buster AS builder
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT
ARG LEANOTE_VERSION=2.6.2-hardened
# 使用修复后的分支（安全加固），模块模式构建
ENV GO111MODULE=on \
    GOFLAGS=-mod=mod \
    CGO_ENABLED=0 \
    GOPROXY=https://goproxy.cn,https://proxy.golang.org,direct

RUN git clone --depth 1 --branch ${LEANOTE_VERSION} https://github.com/fichenx/leanote.git /src
WORKDIR /src
RUN go mod download
# 该分支的 app/cmd 只生成 app/tmp/main.go、app/tmp/run/run.go、app/routes/routes.go
RUN cd app/cmd && go build -o /usr/local/bin/leanote-gen . && leanote-gen build -v ../../ ./tmptmp && rm -rf ./tmptmp
RUN mkdir -p /out && \
    GOOS=${TARGETOS} GOARCH=${TARGETARCH} GOARM=${TARGETVARIANT#v} \
    go build -trimpath -ldflags "-s -w" -o /out/leanote ./app/tmp
# Revel 运行时要读框架源码里的 conf/mime-types.conf 与 templates，
# 否则启动报 cannot find package "github.com/revel/revel"
RUN mkdir -p /out/gopath/src/github.com/revel && \
    cp -r /go/pkg/mod/github.com/revel/revel@v1.0.0 /out/gopath/src/github.com/revel/revel && \
    chmod -R u+rwX,go+rX /out/gopath

# ---------- 运行镜像 ----------
FROM mongo:4.2.7-bionic

ARG LEANOTE_VERSION=2.6.2-hardened
ENV TZ=Asia/Shanghai \
    QT_QPA_PLATFORM=offscreen \
    LEANOTE_VERSION=${LEANOTE_VERSION}

# mongo 镜像内置的 4.2 apt 源签名密钥已过期，且镜像里已装好 mongod，直接移除该源
RUN set -eux; \
    sed -i '/repo.mongodb.org/d' /etc/apt/sources.list /etc/apt/sources.list.d/*.list || true; \
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
COPY --from=builder /src/app/views /opt/leanote/app/views
COPY --from=builder /src/public /opt/leanote/public
COPY --from=builder /src/conf /opt/leanote/conf
COPY --from=builder /src/messages /opt/leanote/messages
COPY --from=builder /src/mongodb_backup /opt/leanote/mongodb_backup
# Revel 打包布局：框架源码 + 指向数据目录的应用软链
COPY --from=builder /out/gopath /opt/gopath
RUN mkdir -p /opt/gopath/src/github.com/leanote && \
    ln -s /data/leanote /opt/gopath/src/github.com/leanote/leanote
COPY run.sh start.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/run.sh /usr/local/bin/start.sh

EXPOSE 9000
VOLUME ["/data"]
HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
    CMD wget -q -O /dev/null --timeout=5 http://127.0.0.1:9000/login || exit 1
CMD ["/usr/local/bin/run.sh"]
