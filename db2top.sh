
# 运行480分钟，每个15秒收集一次快照
db2top -d sample -f collect.file -C -m 480 -i 15 

# 重新播放所收集的数据（－b 1 -A 非必需）
db2top -d sample -f collect.file -b 1 -A

# 重放时直接跳到指定时间戳
db2top -d sample -f collect.file /02:00:00