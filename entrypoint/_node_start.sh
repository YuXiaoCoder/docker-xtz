#!/usr/bin/env bash

##
## 节点服务的启动脚本，将服务托管给supervisord守护
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

# 依据配置文件描述，逐个启动服务
print "start the node service by supervisord"

# 将supervisor配置加载进来并尽力更新下
if [ ! -z "${NODE_SERVICES_START}" ]; then
    # 如果配置文件没新增或者改变，此步啥也不做
    /usr/bin/supervisorctl reread 2>&1 | tee -a "$(get_op_log)"
    # autostart=false的时候，更新完服务状态为STOPPED
    /usr/bin/supervisorctl update 2>&1 | tee -a "$(get_op_log)"
fi

# 顺序启动服务，服务之间间隔一定时间
supervisor_status=$(/usr/bin/supervisorctl status)
for node_service in ${NODE_SERVICES_START}
do
    # echo的信息加双引号，否则无法按行grep
    echo "${supervisor_status}" | grep -w ${node_service} | grep -E "RUNNING|STARTING"
    if [[ $? -ne 0 ]]; then
        /usr/bin/supervisorctl start ${node_service} 2>&1 | tee -a "$(get_op_log)"
    fi
    print "the node service [${node_service}] has been started"
    # 节点服务间启动间隔时间
    sleep ${NODE_SERVICES_START_INTERVAL}
done

# 休息2秒等服务启动
if [ ! -z "${NODE_SERVICES_START}" ]; then
    sleep 2
fi

# 检查节点服务启动结果
print "check the node service start result"

# 如果服务没有启动成功，直接失败退出
supervisor_status=$(/usr/bin/supervisorctl status)
for node_service in ${NODE_SERVICES_START}
do
    # echo的信息加双引号，否则无法按行grep
    echo "${supervisor_status}" | grep -w ${node_service} | grep RUNNING
    if [[ $? -ne 0 ]]; then
        print "the node service [${node_service}] start failed"
        exit 1
    fi
done
