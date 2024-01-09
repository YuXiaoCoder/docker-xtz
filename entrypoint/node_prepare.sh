#!/usr/bin/env bash

##
## 节点服务准备脚本，初始化节点服务使用
##

# 引入基础依赖
ENTRYPOINT_PATH=$(dirname $(readlink -f "$0"))
source ${ENTRYPOINT_PATH}/entrypoint_base.sh

print "prepare the node service"
safe_run ${ENTRYPOINT_PATH}/_node_prepare.sh
