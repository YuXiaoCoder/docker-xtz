#!/usr/bin/env bash

##
## 节点服务停止脚本，日常运维使用
##

# 引入基础依赖
ENTRYPOINT_PATH=$(dirname $(readlink -f "$0"))
source ${ENTRYPOINT_PATH}/entrypoint_base.sh

print "stop the node service"
safe_run ${ENTRYPOINT_PATH}/_node_stop.sh
