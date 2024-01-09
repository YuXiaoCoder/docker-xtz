#!/usr/bin/env bash

##
## supervisor的一些基础变量或者方法，指明supervisor服务之间的启动顺序等
##

# 指明supervisor节点服务的名字列表，空格分隔，如不指明则尽力自发现
NODE_SERVICES="xtz xtz_signer xtz_baker"
# 指明supervisor节点服务的启动顺序，空格分隔，如不指明则尽力自发现
NODE_SERVICES_START="xtz xtz_signer xtz_baker"
# 指明supervisor节点服务的停止顺序，空格分隔，如不指明则尽力自发现
NODE_SERVICES_STOP="xtz_baker xtz_signer xtz"
# 指明supervisor节点服务的启动间隔
NODE_SERVICES_START_INTERVAL=0
# 指明supervisor节点服务的停止间隔
NODE_SERVICES_STOP_INTERVAL=0
