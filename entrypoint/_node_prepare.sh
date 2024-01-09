#!/usr/bin/env bash

##
## 节点服务的准备脚本，为supervisord启动节点做好准备工作
##

# 引入基础依赖
ENTRYPOINT_PATH=$(dirname $(readlink -f "$0"))
source ${ENTRYPOINT_PATH}/entrypoint_base.sh

# 判断节点服务是否需要进行准备
if [[ x"${NODE_ENABLE}" == x"0" ]]; then
    print "the node service is disabled by NODE_ENABLE=0 flag"
    exit 0
fi

# 在挂载的磁盘上建立数据目录，此刻磁盘早已挂载好
print "create the node data path on persistent disk"

# 本应在各自的supervisor_prepare脚本里创建，这里主要是兜底
mkdir -p ${NODE_DATA_PATH}/node
mkdir -p ${NODE_DATA_PATH}/conf
mkdir -p ${NODE_DATA_PATH}/log
mkdir -p ${NODE_DATA_PATH}/snapshot

# 准备节点配置文件，执行节点准备脚本
print "prepare the node service for supervisord"

# 拷贝节点的supervisor配置文件
if [[ -f /etc/supervisor/conf.d/program_node.conf ]]; then
    sed -i "s/{{NODE_NAME}}/${NODE_NAME}/g" /etc/supervisor/conf.d/program_node.conf
fi

# 尽力替换supervisor公共变量的占位符
if [[ -f /etc/supervisor/conf.d/supervisor_service.sh ]]; then
    sed -i "s/{{NODE_NAME}}/${NODE_NAME}/g" /etc/supervisor/conf.d/supervisor_service.sh
fi

# 执行用户自定义的节点服务准备脚本
if [[ -f /etc/supervisor/conf.d/supervisor_prepare.sh ]]; then
    /etc/supervisor/conf.d/supervisor_prepare.sh 2>&1 | tee -a "$(get_entrypoint_log)"
fi
