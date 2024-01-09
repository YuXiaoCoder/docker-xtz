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

# 声明服务启动命令
COMMAND="/usr/local/bin/octez-node run --rpc-addr=0.0.0.0:8732 --allow-all-rpc=0.0.0.0 --data-dir=${NODE_DATA_PATH}/node/octez-node"

# 声明杀死进程时查询PID的命令
CMD="/usr/local/bin/octez-node"

# 优先使用环境变量中定义的启动命令
if [[ ! -z "${NODE_COMMAND}" ]]; then
    COMMAND="${NODE_COMMAND}"
fi
if [[ ! -z "${NODE_CMD}" ]]; then
    CMD="${NODE_CMD}"
fi

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
