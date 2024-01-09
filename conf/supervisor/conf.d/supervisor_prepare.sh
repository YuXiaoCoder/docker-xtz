#!/usr/bin/env bash

##
## supervisor启动进程服务前需要做的准备工作，主要准备一些数据目录、配置信息等
##

# 引入supervisor基础依赖
SUPERVISOR_PATH=$(dirname $(readlink -f "$0"))
source ${SUPERVISOR_PATH}/supervisor_base.sh

# 在挂载的磁盘上建立数据目录，按需建立
mkdir -p ${NODE_DATA_PATH}/node
mkdir -p ${NODE_DATA_PATH}/conf
mkdir -p ${NODE_DATA_PATH}/log
mkdir -p ${NODE_DATA_PATH}/snapshot

# 持久化数据目录
if [[ ! -L ~/.octez-node ]]; then
    rm -rf ~/.octez-node
    mkdir -p ${NODE_DATA_PATH}/node/octez-node
    ln -sf ${NODE_DATA_PATH}/node/octez-node ~/.tezos-node
    ln -sf ${NODE_DATA_PATH}/node/octez-node ~/.octez-node
fi
if [[ ! -L ~/.octez-signer ]]; then
    rm -rf ~/.octez-signer
    mkdir -p ${NODE_DATA_PATH}/node/octez-signer
    ln -sf ${NODE_DATA_PATH}/node/octez-signer ~/.tezos-signer
    ln -sf ${NODE_DATA_PATH}/node/octez-signer ~/.octez-signer
fi
if [[ ! -L ~/.octez-client ]]; then
    rm -rf ~/.octez-client
    mkdir -p ${NODE_DATA_PATH}/node/octez-client
    ln -sf ${NODE_DATA_PATH}/node/octez-client ~/.tezos-client
    ln -sf ${NODE_DATA_PATH}/node/octez-client ~/.octez-client
fi

# 生成节点身份标识
if [[ ! -f ${NODE_DATA_PATH}/node/octez-node/identity.json ]]; then
    /usr/local/bin/octez-node identity generate --data-dir=${NODE_DATA_PATH}/node/octez-node
fi

# 初始化配置
if [[ ! -f ${NODE_DATA_PATH}/node/octez-node/config.json ]]; then
    /usr/local/bin/octez-node config init --data-dir=${NODE_DATA_PATH}/node/octez-node --network=mainnet
fi
if [[ ! -f ${NODE_DATA_PATH}/node/octez-client/config ]]; then
    BAKER_BIN=($(ls /usr/local/bin/octez-baker-*))
    ${BAKER_BIN[0]} config init
fi

# 导入快照
if [[ ! -d ${NODE_DATA_PATH}/node/octez-node/store ]]; then
    # 删除无效文件
    rm -rf ${NODE_DATA_PATH}/node/octez-node/lock ${NODE_DATA_PATH}/node/octez-node/context
    # 下载快照
    wget https://lambsonacid-octez.s3.us-east-2.amazonaws.com/mainnet/rolling/tezos.snapshot -O ${NODE_DATA_PATH}/snapshot/octez-mainnet.rolling
    # 导入快照
    /usr/local/bin/octez-node snapshot import ${NODE_DATA_PATH}/snapshot/octez-mainnet.rolling --data-dir=${NODE_DATA_PATH}/node/octez-node --no-check
    # 删除快照
    rm -f ${NODE_DATA_PATH}/snapshot/octez-mainnet.rolling
fi

# 生成密钥
if [[ ! -f ${NODE_DATA_PATH}/node/octez-signer/secret_keys ]]; then
    # 生成带密码保护的密钥：/usr/local/bin/octez-signer gen keys baker --encrypted
    /usr/local/bin/octez-signer gen keys baker
fi
