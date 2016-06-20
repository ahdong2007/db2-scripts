#!/usr/bin/ksh
# shell script name is getlongsql.sh

#
# 快照监视器监控的是数据库的实时数据，Event Monitor记录某事件或转变出现时某段时间内数据库的活动情况。
#
#
#
if [ $# -eq 0 ] ; then
 echo "Usage:getlongsql.sh <database1> <interval>"
 exit
fi
DB=$1
INTERVAL=$2
FILENAME=sql.txt

connectdb() {
  db2 GET CONNECTION STATE|grep 'Connected'>/dev/null
  res2=$?
  if [[ $res2 -eq 0 ]]
  then
    echo "The DB $DB has been connected!"
  else
    db2 connect to $DB
    res=$?
    i=0
    while [ $i -lt 3 ]
    do
           i='expr $i + 1'
                  if [[ $res -eq 0 ]]
                  then
                    echo "The DB $DB has been connected!"
                    break
                  else
                    sleep 3
                    db2 connect to $DB
                    res=$?
                  fi
    done
  fi
}

openEventMonitor() {
  db2 "drop table STMT_SQLMON";
  db2 "drop table CONTROL_SQLMON";
  db2 "drop table CONNHEADER_SQLMON";
  db2 "drop event monitor SQLMON";
  db2 "create event monitor SQLMON for statements write to table";
  db2 "set event monitor SQLMON state 1"
  sleep $INTERVAL
  db2 "set event monitor SQLMON state 0"
  db2 "select START_TIME, STOP_TIME, (STOP_TIME-START_TIME) as dur,ROWS_READ,FETCH_COUNT,substr(stmt_text,1,400) as stmt from STMT_SQLMON order by dur desc" > $FILENAME
  more $FILENAME
}
connectdb
openEventMonitor
