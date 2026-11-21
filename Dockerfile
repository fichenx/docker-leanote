FROM mongo:4.2.7-bionic
MAINTAINER zcw
ENV TZ=Asia/Shanghai

# 安全加固说明：
# 1. 只暴露应用端口，mongod 由 run.sh 绑定到 127.0.0.1，不再对外暴露 27017
# 2. 下载 Leanote 安装包时可用 --build-arg LEANOTE_SHA256=<sha256> 校验完整性
# 3. 声明数据卷，配合 HEALTHCHECK 判断服务是否真正可用
ARG LEANOTE_VERSION=2.6.1
ARG LEANOTE_URL=http://static.axboy.cn/leanote/leanote-linux-amd64-v${LEANOTE_VERSION}.bin.tar.gz
ARG LEANOTE_SHA256=

ADD run.sh /root/
RUN set -ex; \
    apt-get update; \
    apt-get install -y --no-install-recommends wget tar vim ca-certificates; \
    \
    # install font
    apt-get install -y xvfb libXrender* libfontconfig*; \
    apt-get install -y \
        fonts-arphic-bkai00mp \
        fonts-arphic-bsmi00lp \
        fonts-arphic-gbsn00lp \
        fonts-arphic-gkai00mp \
        fonts-arphic-ukai \
        fonts-arphic-uming \
        ttf-wqy-zenhei \
        ttf-wqy-microhei \
        xfonts-wqy; \
    rm -rf /var/lib/apt/lists/*; \
    \
    # download wkhtmltopdf
    wget -q https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.4/wkhtmltox-0.12.4_linux-generic-amd64.tar.xz; \
    tar -xvf wkhtmltox-0.12.4_linux-generic-amd64.tar.xz; \
    cp wkhtmltox/bin/wkhtmltopdf /usr/local/bin/wkhtmltopdf; \
    chmod +x /usr/local/bin/wkhtmltopdf; \
    rm -rf wkhtmltox wkhtmltox-0.12.4_linux-generic-amd64.tar.xz ;\
    \
    #download leanote (上游仅提供 http 源, 建议通过 LEANOTE_SHA256 传入校验值)
    wget "$LEANOTE_URL" -O /root/leanote.tar.gz; \
    if [ -n "$LEANOTE_SHA256" ]; then \
        echo "$LEANOTE_SHA256  /root/leanote.tar.gz" | sha256sum -c -; \
    else \
        echo "WARNING: 未校验 Leanote 安装包, 建议构建时传入 --build-arg LEANOTE_SHA256=<sha256>"; \
    fi; \
    tar -xzf /root/leanote.tar.gz -C /root/ ;\
    rm -f /root/leanote.tar.gz ;\
    chmod a+x /root/run.sh ;\
    chmod a+x /root/leanote/bin/run.sh ;\
    echo 'export QT_QPA_PLATFORM=offscreen' >> ~/.bashrc ;\
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime ;\
    echo $TZ > /etc/timezone

# 只对应用端口开放, 数据库仅监听容器内回环地址
EXPOSE 9000

VOLUME ["/data/db", "/data/leanote/conf", "/data/leanote/files", "/data/leanote/public/upload"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
    CMD wget -q -O /dev/null --timeout=5 http://127.0.0.1:9000/login || exit 1

# exec 形式, 让 run.sh 中的 exec 能把 Leanote 作为 PID 1 接管信号
CMD ["/bin/bash", "/root/run.sh"]
