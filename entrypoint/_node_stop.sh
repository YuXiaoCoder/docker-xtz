#!/usr/bin/env bash

##
## 节点服务的停止脚本，将服务从supervisord守护中移除
##

# 引入基础依赖
ENTRYPOINT_PATH=$(dirname $(readlink -f "$0"))
source ${ENTRYPOINT_PATH}/entrypoint_base.sh

# 判断节点服务是否需要进行启停
if [[ x"${NODE_ENABLE}" == x"0" ]]; then
    print "the node service is disabled by NODE_ENABLE=0 flag"
    exit 0
fi

# 加载supervisor的服务信息
load_node_services

# 依据配置文件描述，逐个停止服务
print "stop the node service from supervisord"

# 将supervisor配置加载进来并尽力更新下
if [ ! -z "${NODE_SERVICES_STOP}" ]; then
    # 如果配置文件没新增或者改变，此步啥也不做
    /usr/bin/supervisorctl reread 2>&1 | tee -a "$(get_op_log)"
    # autostart=false的时候，更新完服务状态为STOPPED
    /usr/bin/supervisorctl update 2>&1 | tee -a "$(get_op_log)"
fi

# 顺序停止服务，服务之间间隔一定时间
supervisor_status=$(/usr/bin/supervisorctl status)
for node_service in ${NODE_SERVICES_STOP}
do
    # echo的信息加双引号，否则无法按行grep
    echo "${supervisor_status}" | grep -w ${node_service} | grep -E "STOPPED"
    if [[ $? -ne 0 ]]; then
        /usr/bin/supervisorctl stop ${node_service} 2>&1 | tee -a "$(get_op_log)"
    fi
    print "the node service [${node_service}] has been stopped"
    # 节点服务间停止间隔时间
    sleep ${NODE_SERVICES_STOP_INTERVAL}
done

# 休息2秒等服务停止
if [ ! -z "${NODE_SERVICES_STOP}" ]; then
    sleep 2
fi

# 检查节点服务停止结果
print "check the node service stop result"

# 如果服务没有停止成功，直接失败退出
supervisor_status=$(/usr/bin/supervisorctl status)
for node_service in ${NODE_SERVICES_STOP}
do
    # echo的信息加双引号，否则无法按行grep
    echo "${supervisor_status}" | grep -w ${node_service} | grep STOPPED
    if [[ $? -ne 0 ]]; then
        print "the node service [${node_service}] stop failed"
        exit 1
    fi
done
