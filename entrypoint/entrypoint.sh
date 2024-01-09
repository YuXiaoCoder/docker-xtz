#!/usr/bin/env bash

# docker容器的入口命令，前台执行，除非发生错误，否则不自动退出
# 一般情况下，无需对此脚本进行修改，也不建议日常运维时执行此脚本

# 引入基础依赖
ENTRYPOINT_PATH=$(dirname $(readlink -f "$0"))
source ${ENTRYPOINT_PATH}/entrypoint_base.sh

# 尽力清理entrypoint脚本日志
clean_entrypoint_log

# 主进程收到退出信号，优雅停止应用所有服务
# 默认情况下，Kubernetes 将发送 SIGTERM 信号并等待 30 秒，然后强制终止该进程。
function node_exit() {
    ${ENTRYPOINT_PATH}/node_stop.sh
    stop_supervisord
}

# 一种信号在一个脚本里只能被trap一次，trap多次只有最后一次生效
# TERM相当于kill -15信号，INT相当于Control-C信号，kill -9信号无法捕获
# trap里的函数执行不结束，整个进程退出卡住，函数执行完成后，主进程才会自动退出
trap node_exit TERM INT

# 停止现有的supervisord服务，人工在机器上反复测试此脚本时候有意义
stop_supervisord

# 后台启动supervisord服务，开启整机核心进程守护
start_supervisord

# 准备应用服务，将应用进程运行所需的数据目录、配置文件准备好
${ENTRYPOINT_PATH}/node_prepare.sh

# 启动应用服务，如果应用进程启动失败，则只启动系统默认的进程，如sshd等
${ENTRYPOINT_PATH}/node_start.sh

# 守护supervisord进程，如果发生了重启或退出，则主进程退出
node_main_stime=$(date +%s)
while true
do
    # 无pid描述文件，直接设定进程启动时间为现在，主进程直接走向死亡
    if [ -f /var/run/supervisord.pid ]; then
        supervisord_stime=$(stat -c %Y /var/run/supervisord.pid)
    else
        supervisord_stime=$(date +%s)
    fi
    # 单位为秒，均为unix timestamp格式
    delta_time=$((${node_main_stime} - ${supervisord_stime}))
    if [[ ${delta_time} -lt 0 ]]; then
        print "detect supervisord exit or reboot"
        exit 1
    fi
    # supervisord进程一切正常，打印当前各服务状态
    print "supervisorctl status:"
    /usr/bin/supervisorctl status 2>&1 | tee -a "$(get_entrypoint_log)"
    # 尽力清理entrypoint脚本日志
    clean_entrypoint_log
    sleep 30
done
