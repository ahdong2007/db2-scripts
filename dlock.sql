
db2 get monitor switches
db2 update monitor switches using lock on statement on sort on bufferpool on uow on table on

db2 connect to sample
# mkdir /home/db2inst1/dlock
db2 "create event monitor dlock for deadlocks with details history write to file '/home/db2inst1/dlock'"
db2 "set event monitor dlock state 1"

db2evmon -path '/home/db2inst1/dlock' > /home/db2inst1/dlock.txt
db2 "set event monitor dlock state 0"

