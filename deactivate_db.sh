#!/bin/ksh

export OS=`uname -s | tr [a-z] [A-Z]`

if [ `ps -ef | grep db2sys | grep -i -w $USER | grep -cv grep` -ge 1 ]; then
  echo "stopping Instances $INST"
  if [[ $OS == "AIX" ]]; then
    db2 force application all
    db2 force application all
    for db in `db2 list db directory | grep -p 'Indirect'  | grep 'Database alias' | awk -F'=' '{print $2}'`
    do
      db2 deactivate db $db
    done
    db2stop force && ipclean 
  else
    db2 force application all
    db2 force application all
    for db in `db2 list db directory | grep -B 5 'Indirect'  | grep 'Database alias' | awk -F'=' '{print $2}'`
    do
      db2 deactivate db $db
    done
    db2stop force && ipclean 
  fi
else
  echo "Instance $INST is already stopped, no action required"
fi

exit 0