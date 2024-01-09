# GITLAB: https://gitlab.com/tezos/tezos
FROM tezos/tezos:v18.1

# 环境变量
ENV NODE_NAME=xtz

# 声明用户
USER root

# 声明作者
MAINTAINER 1026840746@qq.com

# 优化系统环境
RUN apk update && \
    apk add --virtual .build-deps tzdata && \
    echo "Asia/Shanghai" > /etc/timezone && \
    cp -f /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    apk del .build-deps && \
    apk add bash curl jq vim tmux coreutils supervisor

# 拷贝配置
COPY entrypoint /entrypoint
COPY conf/bash/bashrc /root/.bashrc
COPY conf/supervisor /etc/supervisor

# 声明容器需要暴露的端口
EXPOSE 8732 9732

# 声明工作目录
WORKDIR /mnt/

# 容器进程启动入口
ENTRYPOINT ["/entrypoint/entrypoint.sh"]
