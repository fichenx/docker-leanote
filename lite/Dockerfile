FROM alpine:3.12
MAINTAINER zcw
ENV TZ=Asia/Shanghai

# 可用 --build-arg LEANOTE_SHA256=<sha256> 校验安装包完整性
ARG LEANOTE_VERSION=2.6.1
ARG LEANOTE_URL=http://static.axboy.cn/leanote/leanote-linux-amd64-v${LEANOTE_VERSION}.bin.tar.gz
ARG LEANOTE_SHA256=

RUN apk update && apk add tzdata && \
    cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    mkdir /data/ && \
    wget "$LEANOTE_URL" -O /root/leanote.tar.gz && \
    if [ -n "$LEANOTE_SHA256" ]; then echo "$LEANOTE_SHA256  /root/leanote.tar.gz" | sha256sum -c -; fi && \
    tar -xzf /root/leanote.tar.gz -C /data/ && \
    chmod a+x /data/leanote/bin/run.sh && \
    rm -f /root/leanote.tar.gz

EXPOSE 9000
VOLUME ["/data/leanote/conf", "/data/leanote/files", "/data/leanote/public/upload"]
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD wget -q -O /dev/null --timeout=5 http://127.0.0.1:9000/login || exit 1
CMD ["/data/leanote/bin/run.sh"]