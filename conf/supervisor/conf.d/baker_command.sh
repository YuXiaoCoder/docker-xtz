#!/usr/bin/env bash
# set -x

# 引入supervisor基础依赖
SUPERVISOR_PATH=$(dirname $(readlink -f "$0"))
source ${SUPERVISOR_PATH}/supervisor_base.sh

# 尽力清理supervisor日志
clean_supervisor_log

# 声明服务杀死尝试次数
KILL_TRY_COUNT=8
# 声明服务杀死等待时间
KILL_WAIT_TIME=10

# TERM相当于kill -15信号，INT相当于Control-C信号，kill -9信号无法捕获
# trap里的函数执行不结束，整个进程退出卡住，函数执行完成后，主进程才会自动退出
trap service_exit TERM INT

# 判断节点服务是否就绪
if [[ ! -z "${EXTERNAL_ENDPOINT}" ]]; then
    INTERNAL_HEIGHT=0
    EXTERNAL_HEIGHT=1
    while [[ ${INTERNAL_HEIGHT} -lt ${EXTERNAL_HEIGHT} ]]; do
        echo "INTERNAL_HEIGHT: ${INTERNAL_HEIGHT}, EXTERNAL_HEIGHT: ${EXTERNAL_HEIGHT}, waiting for node to sync..."
        INTERNAL_HEIGHT=$(curl -s -X GET -H 'accept: application/json' http://127.0.0.1:8732/chains/main/blocks/head | jq -r .header.level)
        EXTERNAL_HEIGHT=$(curl -s -X GET -H 'accept: application/json' ${EXTERNAL_ENDPOINT}/chains/main/blocks/head | jq -r .header.level)
        sleep 3
    done
fi

# 判断签名服务是否就绪
while [[ ! -S ${NODE_DATA_PATH}/node/octez-signer/socket ]]; do
    print "waiting for octez-signer to be available..."
    sleep 3
done

SIGNER_PUBLIC_KEY_HASHS=$(cat ${NODE_DATA_PATH}/node/octez-signer/public_key_hashs | jq -r .[0].value)

# 导入客户端密钥
if [[ ! -f ${NODE_DATA_PATH}/node/octez-client/secret_keys ]]; then
    /usr/local/bin/octez-client import secret key baker unix:${NODE_DATA_PATH}/node/octez-signer/socket?pkh=${SIGNER_PUBLIC_KEY_HASHS}
fi

BAKER_BIN=""
CURRENT_PROTOCOL=$(curl -s -X GET -H 'accept: application/json' http://127.0.0.1:8732/chains/main/blocks/head | jq -r .protocol)
for filename in /usr/local/bin/octez-baker-*
do
    if [[ "${CURRENT_PROTOCOL}" == "${filename##*-}"* ]]; then
        BAKER_BIN="${filename}"
    fi
done

if [[ -z "${BAKER_BIN}" ]]; then
    print "no available baker commands found, current protocol: ${CURRENT_PROTOCOL}"
    exit 1
fi

# 声明服务启动命令
COMMAND="${BAKER_BIN} -R unix:${NODE_DATA_PATH}/node/octez-signer/socket?pkh=${SIGNER_PUBLIC_KEY_HASHS} run with local node ${NODE_DATA_PATH}/node/octez-node baker --liquidity-baking-toggle-vote on"

# 声明杀死进程时查询PID的命令
CMD="${BAKER_BIN}"

# 是否是后台运行的命令，0或者1
IS_DAEMON_CMD="0"

# 启动服务并守护进程
if [[ "x${IS_DAEMON_CMD}" == "x0" ]]; then
    # 启动服务，进程直接前台运行
    # 这种守护方式效率更高，只要被守护进程被kill，主进程立即退出
    print "exec command [${COMMAND}]"
    ${COMMAND} &

    # 持续守护此进程
    service_pid=$!
    wait ${service_pid}
else
    # 启动服务，进程直接进入后台
    # 这种守护方式通用性更强，但被守护进程被kill，主进程最迟10秒才退出
    print "exec command [${COMMAND}]"
    ${COMMAND}

    # 需要等一段时间才能将需要守护的进程创建出来
    sleep 10

    # 持续守护此进程
    # $!仅仅能获取此进程的子进程PID，wait也只能wait此进程的子进程
    while true
    do
        service_pid=$(get_service_pid)
        if [[ -z ${service_pid} ]]; then
            print "detect the service process exit"
            exit 1
        fi
        sleep 10
    done
fi
