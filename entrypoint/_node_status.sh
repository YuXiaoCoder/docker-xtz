#!/usr/bin/env bash

##
## 节点服务的查询脚本，在supervisord中查询服务状态
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

# 依据配置文件描述，逐个查看节点服务状态
print "status the node service on supervisord"

# 将supervisor配置加载进来并尽力更新下
if [ ! -z "${NODE_SERVICES}" ]; then
    # 如果配置文件没新增或者改变，此步啥也不做
    /usr/bin/supervisorctl reread 2>&1 | tee -a "$(get_op_log)"
    # autostart=false的时候，更新完服务状态为STOPPED
    /usr/bin/supervisorctl update 2>&1 | tee -a "$(get_op_log)"
fi

# 逐个检查节点服务的状态
supervisor_status=$(/usr/bin/supervisorctl status)
for node_service in ${NODE_SERVICES}
do
    # echo的信息加双引号，否则无法按行grep
    echo "${supervisor_status}" | grep -w ${node_service} 2>&1 | tee -a "$(get_op_log)"
done
