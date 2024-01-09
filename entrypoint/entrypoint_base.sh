#!/usr/bin/env bash

##
## entrypoint脚本的一些公共变量或者方法
##

# entrypoint脚本工作目录，如/entrypoint
ENTRYPOINT_PATH=$(dirname $(readlink -f "$0"))

# entrypoint脚本日志文件
function get_entrypoint_log() {
    if [ -d "${NODE_DATA_PATH}" ]; then
        # 建立数据目录的日志目录
        if [ ! -d ${NODE_DATA_PATH}/log ]; then
            mkdir -p ${NODE_DATA_PATH}/log
        fi
        entrypoint_log=${NODE_DATA_PATH}/log/entrypoint.log
    else
        entrypoint_log=${ENTRYPOINT_PATH}/entrypoint.log
    fi
    echo ${entrypoint_log}
}

# 屏幕输出函数，带日期，并打印日志保存
function print() {
    local message="$*"
    entrypoint_log=$(get_entrypoint_log)
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${0##*/}] ${message}" | tee -a ${entrypoint_log}
}

# entrypoint脚本日志清理
function clean_entrypoint_log() {
    entrypoint_log=$(get_entrypoint_log)
    if [ ! -f ${entrypoint_log} ]; then
        return 0
    fi
    # 文件大小字节数，单位Byte
    log_size=$(stat -c "%s" ${entrypoint_log})
    # 10485760 = 10*1024*1024 = 10MB
    if [ ${log_size} -ge 10485760 ]; then
        true > ${entrypoint_log}
        print "the entrypoint log [${entrypoint_log}] size is greater than 10MB"
    fi
}

# 启动supervisord服务
function start_supervisord() {
    print "start supervisord daemon"
    /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
    if [ $? -ne 0 ]; then
        print "start supervisord daemon failed"
        exit 1
    fi
    # pid文件需要几秒生成，索性等待4秒，等到ssh服务running
    sleep 4
    # 如果supervisord进程没有启动，直接退出
    if [ ! -f /var/run/supervisord.pid ]; then
        print "supervisord pid file not exists"
        exit 1
    fi
}

# 停止supervisord服务
function stop_supervisord() {
    # 没有进程pid描述文件，直接返回
    if [ ! -f /var/run/supervisord.pid ]; then
        return 0
    fi
    # 先尽力停止所托管的服务
    supervisorctl stop all
    # -15信号杀死服务，尝试几次
    kill_try_count=3
    for ((i=1; i<=${kill_try_count}; i++))
    do
        kill -15 $(cat /var/run/supervisord.pid)
        sleep 3
        if [ ! -f /var/run/supervisord.pid ]; then
            print "the supervisor service has been killed"
            break
        fi
    done
    # 如果依旧存在，直接将pid描述文件删除
    if [ -f /var/run/supervisord.pid ]; then
        mv -f /var/run/supervisord.pid /tmp/supervisord.pid
    fi
}

# 如果运行成功打印日志，运行失败打印日志并退出
function safe_run() {
    local cmd="$*"
    $cmd
    if [[ $? -eq 0 ]]; then
        print "run the cmd [$cmd] successfully"
    else
        print "run the cmd [$cmd] failed"
        exit 1
    fi
}

# 加载节点服务的服务信息
function load_node_services() {
    # 导入supervisor的基础脚本，获取服务启停信息
    if [ -f /etc/supervisor/conf.d/supervisor_service.sh ]; then
        source /etc/supervisor/conf.d/supervisor_service.sh
    fi

    # 获取supervisor配置里的节点服务列表
    program_node_conf=/etc/supervisor/conf.d/program_node.conf
    if [ -f ${program_node_conf} ]; then
        node_services=$(grep "program:" ${program_node_conf} | awk -F':' '{print $2}' | awk -F']' '{print $1}')
        # 倒序一下节点服务，用于stop
        node_services_reversed=$(echo ${node_services} | awk '{for(i=NF;i>=1;i--) printf "%s ",$i}')
        node_services_reversed=${node_services_reversed::-1}
    else
        node_services=""
        node_services_reversed=""
    fi

    # 尽力补全supervisor管理的节点服务列表
    if [ -z "${NODE_SERVICES}" ]; then
        NODE_SERVICES=${node_services}
    fi
    if [ -z "${NODE_SERVICES_START}" ]; then
        NODE_SERVICES_START=${node_services}
    fi
    if [ -z "${NODE_SERVICES_STOP}" ]; then
        NODE_SERVICES_STOP=${node_services_reversed}
    fi
    if [ -z ${NODE_SERVICES_START_INTERVAL} ]; then
        NODE_SERVICES_START_INTERVAL=0
    fi
    if [ -z ${NODE_SERVICES_STOP_INTERVAL} ]; then
        NODE_SERVICES_STOP_INTERVAL=0
    fi
}
