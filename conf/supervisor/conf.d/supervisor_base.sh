#!/usr/bin/env bash

##
## supervisor的一些基础变量或者方法，用于supervisor脚本共享
##

# supervisor的目录
SUPERVISOR_PATH=$(dirname $(readlink -f "$0"))

# 节点服务的名字，如btc，/opt/btcmain/supervisor --> btc
if [[ -z ${NODE_NAME} ]]; then
    NODE_NAME=$(echo "${SUPERVISOR_PATH}" | awk -F'/' '{print $3}' | awk -F'main' '{print $1}')
fi

# 设置基础目录
export NODE_CODE_PATH=/opt/${NODE_NAME}main
export NODE_DATA_PATH=/mnt/${NODE_NAME}main

# supervisor脚本日志文件
function get_supervisor_log() {
    if [[ -d ${NODE_DATA_PATH} ]]; then
        if [[ ! -d ${NODE_DATA_PATH}/log ]]; then
            mkdir -p ${NODE_DATA_PATH}/log
        fi
        supervisor_log=${NODE_DATA_PATH}/log/supervisor.log
    else
        supervisor_log=${SUPERVISOR_PATH}/supervisor.log
    fi
    echo ${supervisor_log}
}

# 屏幕输出函数，带日期，并打印日志保存
function print() {
    local message="$*"
    supervisor_log=$(get_supervisor_log)
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${0##*/}] ${message}" | tee -a ${supervisor_log}
}

# supervisor脚本日志清理
function clean_supervisor_log() {
    supervisor_log=$(get_supervisor_log)
    if [[ ! -f ${supervisor_log} ]]; then
        return 0
    fi
    # 文件大小字节数，单位Byte
    log_size=$(stat -c "%s" ${supervisor_log})
    # 10485760 = 10*1024*1024 = 10MB
    if [[ ${log_size} -ge 10485760 ]]; then
        true > ${supervisor_log}
        print "the supervisor log [${supervisor_log}] size is greater than 10MB"
    fi
}

# 获取服务的命令名，用于查询PID
function get_service_command() {
    # 先用短命令名，再用长命令名，防止长命令名乱序、变化查询不到进程
    if [[ ! -z "${CMD}" ]]; then
        command="${CMD}"
    elif [[ ! -z "${COMMAND}" ]]; then
        command="${COMMAND}"
    else
        # command的默认值设置成魔法值，防止误杀
        command="xxxyyyzzz"
    fi
    echo ${command}
}

# 获取服务进程号
function get_service_pid() {
    command=$(get_service_command)
    # 如果PPID为1或者此脚本主进程，则此进程为服务进程
    ppid=$$
    service_pid=$(ps -ef | grep -E "${command}" | grep -v grep | awk -v ppid=$ppid '$3==ppid || $3==1 {print $2}')
    # 如果通过严格判定获取不到pid，则全机搜索
    if [[ -z "${service_pid}" ]]; then
        service_pid=$(ps -ef | grep -E "${command}" | grep -v grep | awk -F' ' '{print $2}')
    fi
    echo ${service_pid}
}

# 主进程收到退出信号，优雅停止服务
function service_exit() {
    print "receive the service exit signal"
    # 服务进程杀死尝试次数，默认值为3
    if [[ -z ${KILL_TRY_COUNT} ]]; then
        kill_try_count=3
    else
        kill_try_count=${KILL_TRY_COUNT}
    fi
    # 服务进程杀死等待时间，默认值为10秒
    if [[ -z ${KILL_WAIT_TIME} ]]; then
        kill_wait_time=10
    else
        kill_wait_time=${KILL_WAIT_TIME}
    fi
    # 服务进程杀死信号值，默认值为15
    if [[ -z ${KILL_SIGNAL} ]]; then
        kill_signal=15
    else
        kill_signal=${KILL_SIGNAL}
    fi
    # -15信号杀死服务，尝试几次
    for ((i=1; i<=${kill_try_count}; i++))
    do
        command=$(get_service_command)
        service_pid=$(get_service_pid)
        if [[ ! -z "${service_pid}" ]]; then
            print "get service pid [${service_pid}] by command [${command}]"
            print "exec command [kill -${kill_signal} ${service_pid}], try count [$i]"
            kill -${kill_signal} ${service_pid}
            sleep ${kill_wait_time}
        else
            print "the command [${command}] has been killed"
            break
        fi
    done
}
