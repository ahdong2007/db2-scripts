
#!/bin/ksh

export OS=`uname -s | tr [a-z] [A-Z]`


if [[ $OS == "AIX" ]]; then
  for db in `db2 list db directory | grep -p 'Indirect' | grep 'Database name' | sort -u | awk -F'=' '{print $2}'`
  do
    db2 activate db $db
  done
else
  for db in `db2 list db directory | grep -B 5 'Indirect' | grep 'Database name' | sort -u | awk -F'=' '{print $2}'`
  do
    db2 activate db $db
  done
fi

exit 0