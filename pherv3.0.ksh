#!/bin/ksh

#
#  Patch Helper
#  Mason Hua @ IBM 16th Nov 2015
#

export OS=`uname -s | tr [a-z] [A-Z]`

# RPATH for report path
# WPATH for work path, where the $0 puts
RPATH="/tmp/upher`date "+%j"`"
if [ `echo "$0" | grep -c '^\./'` -eq 1 ]; then
  # use it by this way: ./istop.ksh
  WPATH=`pwd`
  PROGM=${0#./}
else
  # use it with full path
  WPATH=${0%/*}
  PROGM=${0##*/}
fi

# if run it with root, make all instances have access to this script
if [ `id -u` -eq 0 ]; then
  chmod 755 $WPATH >/dev/null 2>&1
  chmod 755 $WPATH/$PROGM >/dev/null 2>&1
  chmod 777 $RPATH >/dev/null 2>&1
fi

if [ ! -d $RPATH ]; then
  mkdir $RPATH
  chmod 777 $RPATH >/dev/null 2>&1
fi

Usage ( ) {
  echo " "
  echo "Run it as root "
  echo "Usage: $0 -i <instances, use comma(,) to separate each instance> 
                  -b <the code path you use to upgrade the instances> 
                  -l <preserve, for further use. license file>
                  -t START_INST | STOP_INST | BIND_DB | HC | CE | UPGRADE_DB
                      # TART_INST  start instances only
                      # STOP_INST  stop instances only
                      # BIND_DB    do rebind on databases only
                      # HC         run health check and fix violations automatically
                      # CE         collect evidences
                      # UPGRADE_DB run upgrade database on databases
                  -w <preserve, for further use. work directory, /tmp/pher$date as default>
        Mandatory parameters:
	          -i, -b
        Note: Make sure every instance have access to the work directory    
  "
  echo " "
  exit 1
}


#---------------------------------------------------------------------------
# Parse Parms passed into script
#---------------------------------------------------------------------------
#
#Check for the use of the following command line parms
# -? -HELP -N -DEBUG
#
parmlist="${*}"
for parm in ${parmlist};   do
  case ${parm} in 
      '-?') script_help='Y' ;;
      '-DEBUG') echo " debug is turned on "; set -x ;;
      '-HELP') script_help='Y' ;;
  esac
done

############################################################
# task functions
############################################################
#
# start instance
# run it with instance id
__start_instance() {
  if [ "$INST" == "" ]; then
    INST=$USER
  fi

  if [ `ps -ef | grep db2sys | grep -i -w $INST | grep -cv grep` -lt 1 ]; then
    echo "starting instance $INST"
    db2start
  else
    echo "Instance $INST is already up, not action required"
  fi

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
}

start_instance ( ) {

  if [ `id -u` -ne 0 ]; then
    echo "going to start current instance $USER"
    __start_instance
    exit 0
  elif [ "$INSTS" == "" ]; then
    echo "Pls specify the instance names when running by root"
    Usage
    exit 1
  fi

  echo "==========================================="
  echo "= start instances : $INSTS                 "
  echo "==========================================="
  count=2
  INSTS_TMP="${INSTS},"
  INST=`echo "$INSTS_TMP"|cut -d, -f 1`
  while [ "$INST" != "" ]
  do
    INST=`echo $INST | tr [A-Z] [a-z]`
    echo "++ start instance $INST"
    id $INST >/dev/null 2>&1
    if [ $? -ne 0 ]; then 
      echo "Instance $INST is not exists, please check it!!!"                       
    else
      echo ""
      su - $INST -c "$WPATH/$PROGM -t start_use_internal -i $INST"                                                                          
    fi
    echo ""
    echo ""

    INST=`echo "$INSTS_TMP"|cut -d, -f $count`
    (( count=$count + 1 ))
  done

  exit 0
}

# end of start instance

#
# stop_instance
# run it with instance id
__stop_instance ( ) {

  if [ "$INST" == "" ]; then
    INST=$USER
  fi

  if [ `ps -ef | grep db2sys | grep -i -w $INST | grep -cv grep` -ge 1 ]; then
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
}

stop_instance ( ) {

  if [ `id -u` -ne 0 ]; then
    echo "going to stop current instance $USER"
    __stop_instance
    exit 0
  elif [ "$INSTS" == "" ]; then
    echo "Pls specify the instance names when running by root"
    Usage
    exit 1
  fi

  echo "==========================================="
  echo "= stop instances : $INSTS                 "
  echo "==========================================="
  count=2
  INSTS_TMP="${INSTS},"
  INST=`echo "$INSTS_TMP"|cut -d, -f 1`
  while [ "$INST" != "" ]
  do
    INST=`echo $INST | tr [A-Z] [a-z]`
    echo "++ stop instance $INST"
    id $INST >/dev/null 2>&1
    if [ $? -ne 0 ]; then 
      echo "Instance $INST is not exists, please check it!!!"                       
    else
      echo ""
      su - $INST -c "$WPATH/$PROGM -t stop_use_internal -i $INST"                                                                          
    fi
    echo ""
    echo ""

    INST=`echo "$INSTS_TMP"|cut -d, -f $count`
    (( count=$count + 1 ))
  done

  exit 0
}
# end of stop instance

#
# function rebind_all
# run it with instance id
__rebind_all () {
  if [ "$INST" == "" ]; then
    INST=$USER
  fi

  if [ `ps -ef | grep db2sys | grep -i -w $INST | grep -cv grep` -lt 1 ]; then
    echo "Issuing: db2start"
    db2start
  fi

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

  echo "do rebind $INST"
  if [[ $OS == "AIX" ]]; then
    for db in `db2 list db directory | grep -p 'Indirect'  | grep 'Database alias' | awk -F'=' '{print $2}'`
    do
      cd $HOME/sqllib/bnd
      db2 connect to $db
      db2 bind  db2schema.bnd blocking all grant public SQLERROR continue 
      db2 bind  @db2ubind.lst BLOCKING ALL sqlerror continue grant public 
      db2 bind  @db2cli.lst blocking all grant public action add   

    # for capture and apply
      db2 bind @capture.lst isolation ur blocking all
      db2 bind @applycs.lst isolation cs blocking all grant public
      db2 bind @applyur.lst isolation ur blocking all grant public
    
    # for Qcapture and Qapply
      db2 bind @qcapture.lst isolation ur blocking all
      db2 bind @qapply.lst isolation ur blocking all grant public
      db2 terminate
    done
  else
    for db in `db2 list db directory | grep -B 5 'Indirect'  | grep 'Database alias' | awk -F'=' '{print $2}'`
    do
      cd $HOME/sqllib/bnd
      db2 connect to $db
      db2 bind  db2schema.bnd blocking all grant public SQLERROR continue 
      db2 bind  @db2ubind.lst BLOCKING ALL sqlerror continue grant public 
      db2 bind  @db2cli.lst blocking all grant public action add   

      # for capture and apply
      db2 bind @capture.lst isolation ur blocking all
      db2 bind @applycs.lst isolation cs blocking all grant public
      db2 bind @applyur.lst isolation ur blocking all grant public
    
      # for Qcapture and Qapply
      db2 bind @qcapture.lst isolation ur blocking all
      db2 bind @qapply.lst isolation ur blocking all grant public
      db2 terminate
    done
  fi

  exit 0
}

rebind_all ( ) {

  if [ `id -u` -ne 0 ]; then
    echo "going to rebind databases in current instance $USER"
    __rebind_all
    exit 0
  elif [ "$INSTS" == "" ]; then
    echo "Pls specify the instance names when running by root"
    Usage
    exit 1
  fi

  echo "==========================================="
  echo "= rebind databases in instances : $INSTS   "
  echo "==========================================="
  count=2
  INSTS_TMP="${INSTS},"
  INST=`echo "$INSTS_TMP"|cut -d, -f 1`
  while [ "$INST" != "" ]
  do
    INST=`echo $INST | tr [A-Z] [a-z]`
    echo "++ rebind databases in instance $INST"
    id $INST >/dev/null 2>&1
    if [ $? -ne 0 ]; then 
      echo "Instance $INST is not exists, please check it!!!"                       
    else
      echo ""
      su - $INST -c "$WPATH/$PROGM -t r_use_internal -i $INST"                                                                          
    fi
    echo ""
    echo ""

    INST=`echo "$INSTS_TMP"|cut -d, -f $count`
    (( count=$count + 1 ))
  done

  exit 0
}

# end of rebind_all

#
# update/upgrade instance
# run it with root
# use $code_path/bin/db2greg -dump to get the current DB2 version, and the new version. 
# Then dicide to use db2iupdt or db2iupgrade
__update_instance () {

  if [ "$INST" == "" ]; then
    INST=$USER
  fi

  # check if run as root
  if [ `id -u` -ne 0 ]; then
    echo "You are run into the upgrade/update part, root access is required"
    Usage
    exit 1
  fi

  if [ "$INST" ==  "" ]; then
    echo "-i <instances> is mandatory when calling update instance"
    Usage
    exit 1
  fi

  if [ "$CPATH" ==  "" ]; then
    echo "-b <code path> is mandatory when calling update instance"
    Usage
    exit 1
  fi
  echo "update instance: $INST"

  if [[ -f $CPATH/instance/db2iupdt ]]; then
    echo "$CPATH/instance/db2iupdt -k $INST"
    $CPATH/instance/db2iupdt -k $INST
  else
    echo "db2iupdt is not exist on $CPATH/instance..."
    exit 1
  fi
  echo "end of upgrade instance: $INST"
}

update_instance () {
  if [ `id -u` -ne 0 ]; then
    echo "going to apply fixpack for current instance $USER"
    __update_instance
    exit 0
  elif [ "$INSTS" == "" ]; then
    echo "Pls specify the instance names when running by root"
    Usage
    exit 1
  fi

  echo "==========================================="
  echo "= apply fixpack for instances : $INSTS     "
  echo "==========================================="
  count=2
  INSTS_TMP="${INSTS},"
  INST=`echo "$INSTS_TMP"|cut -d, -f 1`
  while [ "$INST" != "" ]
  do
    INST=`echo $INST | tr [A-Z] [a-z]`
    echo "++ apply fixpack for instance $INST"
    id $INST >/dev/null 2>&1
    if [ $? -ne 0 ]; then 
      echo "Instance $INST is not exists, please check it!!!"                       
    else
      echo ""
      __update_instance
    fi
    echo ""
    echo ""

    INST=`echo "$INSTS_TMP"|cut -d, -f $count`
    (( count=$count + 1 ))
  done
}
# end of update_instance

# upgrade instance
__upgrade_instance () {

  if [ "$INST" == "" ]; then
    INST=$USER
  fi

  if [ `id -u` -ne 0 ]; then
    echo "You are run into the upgrade/update part, root access is required"
    Usage
    exit 1
  fi

  if [ "$INST" ==  "" ]; then
    echo "-i <instances> is mandatory when calling upgrade instance"
    Usage
  fi

  if [ "$CPATH" ==  "" ]; then
    echo "-b <code path> is mandatory when calling upgrade instance"
    Usage
  fi
  echo "upgrade instance: $INST"

  if [[ -f $CPATH/instance/db2iupdt ]]; then
    echo "$CPATH/instance/db2iupgrade -k $INST"
    $CPATH/instance/db2iupgrade -k $INST
  else
    echo "db2iupgrade is not exist on $CPATH/instance..."
    exit 1
  fi
  echo "end of upgrade instance: $INST"
  
}

upgrade_instance () {
  if [ `id -u` -ne 0 ]; then
    echo "going to upgrade current instance $USER"
    __upgrade_instance
    exit 0
  elif [ "$INSTS" == "" ]; then
    echo "Pls specify the instance names when running by root"
    Usage
    exit 1
  fi

  echo "==========================================="
  echo "= upgrade instances : $INSTS               "
  echo "==========================================="
  count=2
  INSTS_TMP="${INSTS},"
  INST=`echo "$INSTS_TMP"|cut -d, -f 1`
  while [ "$INST" != "" ]
  do
    INST=`echo $INST | tr [A-Z] [a-z]`
    echo "++ upgrade instance $INST"
    id $INST >/dev/null 2>&1
    if [ $? -ne 0 ]; then 
      echo "Instance $INST is not exists, please check it!!!"                       
    else
      echo ""
      __upgrade_instance
    fi
    echo ""
    echo ""

    INST=`echo "$INSTS_TMP"|cut -d, -f $count`
    (( count=$count + 1 ))
  done
}
# end of upgrade_instance

# upgrade database
__upgrade_database () {
  if [ "$INST" == "" ]; then
    INST=$USER
  fi

  echo "upgrade databases in instance $INST"

  if [[ $OS == "AIX" ]]; then
    if [ `db2 list db directory | grep -p 'Indirect' | grep -c 'Database name'` -eq 0 ]; then
      echo "No database cataloged this instance $USER"
      echo "No upgrade database is needed"
      exit 0
    fi
  else
    if [ `db2 list db directory | grep -B 5 'Indirect' | grep -c 'Database name'` -eq 0 ]; then
      echo "No database cataloged this instance $USER"
      echo "No upgrade database is needed"
      exit 0
    fi
  fi

  if [[ $OS == "AIX" ]]; then
    for db in `db2 list db directory | grep -p 'Indirect' | grep 'Database name' | sort -u | awk -F'=' '{print $2}'`
    do
      echo "db2 upgrade db $db"
      db2 upgrade db $db
    done
  else
    for db in `db2 list db directory | grep -B 5 'Indirect' | grep 'Database name' | sort -u | awk -F'=' '{print $2}'`
    do
      echo "db2 upgrade db $db"
      db2 upgrade db $db
    done
  fi

  exit 0
}

upgrade_database ( ) {

  if [ `id -u` -ne 0 ]; then
    echo "going to upgrade databass in instance $USER"
    __upgrade_database
    exit 0
  elif [ "$INSTS" == "" ]; then
    echo "Pls specify the instance names when running by root"
    Usage
    exit 1
  fi

  echo "==========================================="
  echo "= upgrade databases in instances : $INSTS  "
  echo "==========================================="
  count=2
  INSTS_TMP="${INSTS},"
  INST=`echo "$INSTS_TMP"|cut -d, -f 1`
  while [ "$INST" != "" ]
  do
    INST=`echo $INST | tr [A-Z] [a-z]`
    echo "++ upgrade databases in instance $INST"
    id $INST >/dev/null 2>&1
    if [ $? -ne 0 ]; then 
      echo "Instance $INST is not exists, please check it!!!"                       
    else
      echo ""
      # start the instance first before upgrade the DB
      su - $INST -c "$WPATH/$PROGM -t START_INST -i $INST"
      su - $INST -c "$WPATH/$PROGM -t UPGRADE_DB -i $INST"                                                                          
    fi
    echo ""
    echo ""

    INST=`echo "$INSTS_TMP"|cut -d, -f $count`
    (( count=$count + 1 ))
  done

  exit 0
}
# end of upgrade database

# apply license
apply_license () {
  if [ -f "$LFILE" ]; then
    echo "apply license"
    echo "$CPATH/adm/db2licm -a $LFILE"
    $CPATH/adm/db2licm -a $LFILE
  fi
}
# end of apply_license

#
# Healthcheck functions
#
Fix_A020 ( ) {

  # cat *.info | grep -w 'VIOLATION' | grep A020
  # A020  |DBAUTH              |PUBLIC   |IMPLSCHEMA  |VIOLATION
  # A020  |DBAUTH              |PUBLIC  |CONNECT     |VIOLATION

  priv=`echo $1 | awk -F'|' '{print $4}' | awk 'gsub(" ","",$0)'`

  if [ "$priv" == "CONNECT" ]; then
    cmd="db2 revoke CONNECT on database from PUBLIC"
  fi

  if [ "$priv" == "IMPLSCHEMA" ]; then
    cmd="db2 revoke IMPLICIT_SCHEMA on database from PUBLIC"
  fi

  db2 connect to $db_name
  echo ${cmd}
  ${cmd}
  db2 terminate

} # end of Fix_A020

Fix_A021 ( ) {

  # cat *.info | grep -w 'VIOLATION' | grep A021
  # A021  |Schema-JEBRUNSG                            |PUBLIC           |CREATEIN           |VIOLATION
  # A021  |Schema-JOUHAUD                             |PUBLIC           |CREATEIN           |VIOLATION
  # A021  |Schema-SBROMANO                            |PUBLIC           |CREATEIN           |VIOLATION
  # A021  |Schema-SYSPUBLIC                           |PUBLIC           |CREATEIN           |VIOLATION
  # A021  |Schema-A3INSTMT     |PUBLIC  |CREATEIN    |VIOLATION
  # A021  |Schema-DB2EXT       |PUBLIC  |CREATEIN    |VIOLATION

  #cmd=`echo $1 | awk '{print $2 " " $3}' | sed 's/[\|]/ /g' | cut -d "-" -f2 | awk '{print "db2 revoke " $2 " on schema " $1 " from public" '}`
  cmd=`echo $1 | awk '{print $2 " " $3}' | sed 's/[\|]/ /g' | cut -d "-" -f2 | awk '{print "db2 revoke CREATEIN on schema " $1 " from public" '}`

  db2 connect to $db_name
  echo ${cmd} | tee -a $vscript
  ${cmd}
  db2 terminate

} # end of Fix_A021

Fix_A026 ( ) {

  # cat *.info | grep -w 'VIOLATION' | grep A026
  # A026  |SYSIBM.SYSSECURITYLABELCOMPONENTELEMENTS  |PUBLIC           |SELECT             |VIOLATION
  # A026  |SYSIBM.SYSSECURITYLABELCOMPONENTS         |PUBLIC           |SELECT             |VIOLATION
  # A026  |SYSIBM.SYSSECURITYLABELS                  |PUBLIC           |SELECT             |VIOLATION
  # A026  |SYSIBM.SYSSECURITYPOLICIES                |PUBLIC           |SELECT             |VIOLATION
  # A026  |SYSIBM.SYSSECURITYPOLICYCOMPONENTRULES    |PUBLIC           |SELECT             |VIOLATION

  cmd=`echo $1 | awk '{print $2 " " $3}' | sed 's/[\|]/ /g' | cut -d "-" -f2 | awk '{print "db2 revoke select on table " $1 " from public" '}`

  db2 connect to $db_name
  echo ${cmd} | tee -a $vscript
  ${cmd}
  db2 terminate

} # end of Fix_A026


# A045|A050|A055|A058|A060|A062|A065|A066|A070
# For A070, need root access
Fix_A065 ( ) {

  # A065  |775                 |F:775  |db2c955  |staff   |/home/db2c955/javacore.20130709.222833.6684922.txt                  |VIOLATION-Grp
  # A065  |775                 |F:775  |db2c955  |staff   |/home/db2c955/javacore.20130818.051948.2293832.txt                  |VIOLATION-Grp
  # A065  |775  |F:775  |instptx1  |staff    |/home/instptx1/.profile                                                      |VIOLATION-Grp
  # A065  |775  |F:666  |instptx1  |dbadmin  |/home/instptx1/core.20150412.075515.22741002.dmp                             |VIOLATION

  echo "Fix_A065: 1: $1"
  cmd=`echo $1 | grep -w 'VIOLATION' | egrep 'A045|A050|A055|A058|A060|A062|A065|A066|A070' | awk -F'|' '{print "chmod " $2 $6}'`

  echo ${cmd}
  ${cmd}

  # for VIOLATION-Grp
  cmd=`echo $1 | grep -w 'VIOLATION-Grp' | egrep 'A045|A050|A055|A058|A060|A062|A065|A066|A070' | awk -F'|' '{gsub(" ","",$4);print "chown "$4":"$5 $6}'`

  echo ${cmd}
  ${cmd}
}

# fix violations
__fix_vio () {

  if [ ! -f $HOME/Security/db2shc ]; then
    echo "db2shc is not exists in instance $USER"
    exit 1
  fi

  SHOME="$HOME/Security/"
  vtmp="$SHOME/.vtmp.out"

  if [ "$INST" == "" ]; then
    INST=$USER
  fi
  
  cd $SHOME

  echo "Going to run db2shc -nm, it may take minutes, please be patient!"
  $SHOME/db2shc -nm >/dev/null 2>&1
  hcfiles=$(ls $SHOME/*$hostname-$USER*.out)

  for hcfile in $hcfiles
  do
    viols=$(awk -F\| '/TOTAL VIOLATIONS/ { print $5 }' $hcfile)
    db_name=$(ls -l $hcfile | awk -F':' '{print $2}' | awk -F'-' '{print $5}')
    echo $db_name : $viols

    if [[ $viols -gt 0 ]]
    then
      echo "Violations before we run this script $db_name: totally $viols" 
      cat $SHOME/*$hostname-$USER-$db_name*.info | grep -w 'VIOLATION' | head -10 
      echo "......" 
      echo ""       
      echo "going to fix those violations for $db_name"
      cat $SHOME/*$hostname-$USER-$db_name*.info | grep -w 'VIOLATION' | tee $vtmp
      while read line
      do
        echo "line: $line"
        vtype=`echo $line | awk -F'|' '{gsub(" ","",$1);print $1}'`
        echo "VIOLATION TYPE: $vtype"
        case $vtype in
          "A020") Fix_A020 "$line" ;;
          "A021") Fix_A021 "$line" ;;
          "A026") Fix_A026 "$line" ;;
          "A045"|"A050"|"A055"|"A058"|"A060"|"A062"|"A065"|"A066")  Fix_A065 "$line" ;;
          #"A070")  Fix_A070 "$line" ;;
        esac
      done < $vtmp
    else
      echo "No violations found for $db_name" 
    fi
  done

  # run it again
  echo "Going to run db2shc -nm again, it may take minutes, please be patient!"
  $SHOME/db2shc -nm >/dev/null 2>&1
  hcfiles=$(ls $SHOME/*$hostname-$USER*.out)

  for hcfile in $hcfiles
  do
    viols=$(awk -F\| '/TOTAL VIOLATIONS/ { print $5 }' $hcfile)
    db_name=$(ls -l $hcfile | awk -F':' '{print $2}' | awk -F'-' '{print $5}')
    echo $db_name : $viols

    if [[ $viols -gt 0 ]]
    then
      echo "Violations after we run this script $db_name: totally $viols" 
      cat $SHOME/*$hostname-$USER-$db_name*.info | grep -w 'VIOLATION' | head -10 
      echo "......" 
      echo ""       
    else
      echo "Violations after we run this script for $db_name: totally $viols" 
      echo "ALL violations fixed!!" 

      echo "cat $hcfile | grep -w 'TOTAL VIOLATIONS"
      cat $hcfile | grep -w 'TOTAL VIOLATIONS'
    fi
  done

  \rm $vtmp  2>/dev/null

  exit 0
}

# end of fix violations

health_check( ) {

  if [ `id -u` -ne 0 ]; then
    echo "going to fix violations for current instance $USER"
    __fix_vio
    exit 0
  elif [ "$INSTS" == "" ]; then
    echo "Pls specify the instance names when running by root"
    Usage
    exit 1
  fi

  echo "==========================================="
  echo "= run health check for instances : $INSTS  "
  echo "==========================================="
  count=2
  INSTS_TMP="${INSTS},"
  INST=`echo "$INSTS_TMP"|cut -d, -f 1`
  while [ "$INST" != "" ]
  do
    INST=`echo $INST | tr [A-Z] [a-z]`
    echo "++ do health check for instance $INST"
    id $INST
    if [ $? -ne 0 ]; then 
      echo "Instance $INST is not exists, please check it!!!"                       
    else
      echo ""
      su - $INST -c "$WPATH/$PROGM -t h_use_internal -i $INST"                                                                          
    fi
    echo ""
    echo ""

    INST=`echo "$INSTS_TMP"|cut -d, -f $count`
    (( count=$count + 1 ))
  done

  exit 0
}
# end of health check

# collect_evidence
__collect_evidence ( ) {
  if [ ! -f $HOME/Security/db2shc ]; then
    echo "db2shc is not exists..."
  else
    $HOME/Security/db2shc -nm  > /dev/null 2>&1
    cat $HOME/Security/*.out | grep -i 'TOTAL VIOLATIONS'
  fi
  echo "db2level"
  db2level
  echo "db2licm -l"
  db2licm -l
  echo "db2ilist:"
  db2ilist

  exit 0
}

collect_evidence () {

  if [ `id -u` -ne 0 ]; then
    echo "going to collect evidence for instance $USER"
    __collect_evidence
    exit 0
  elif [ "$INSTS" == "" ]; then
    echo "Pls specify the instance names when running by root"
    Usage
    exit 1
  fi

  echo "==========================================="
  echo "= collect evidence for instances : $INSTS  "
  echo "==========================================="

  count=2
  INSTS_TMP="${INSTS},"
  INST=`echo "$INSTS_TMP"|cut -d, -f 1`
  while [ "$INST" != "" ]
  do
    INST=`echo $INST | tr [A-Z] [a-z]`
    echo "++ collect evidence for instance $INST"
    id $INST
    if [ $? -ne 0 ]; then 
      echo "Instance $INST is not exists, please check it!!!"                       
    else
      echo ""
      su - $INST -c "$WPATH/$PROGM -t e_use_internal -i $INST"                                                                          
    fi
    echo ""
    echo ""

    INST=`echo "$INSTS_TMP"|cut -d, -f $count`
    (( count=$count + 1 ))
  done

  exit 0
}
# end of add_evidence

# task

OPTIND=1
while getopts ":t:b:i:" opt
do
  case ${opt} in
    t )  op=${OPTARG} ;;
    b )  CPATH=${OPTARG} ;;
    i )  INSTS=${OPTARG} ;;
  esac
done

case $op in
  u_use_internal )
    upgrade_instance ;;
  r_use_internal )
    __rebind_all ;;
  h_use_internal )
    __fix_vio ;;
  e_use_internal )
    __collect_evidence ;;
  stop_use_internal )
    __stop_instance ;;
  start_use_internal )
    __start_instance ;;
  START_INST )
    start_instance ;;
  STOP_INST )
    stop_instance ;;
  BIND_DB )
    rebind_all ;;
  HC )
    health_check ;;
  CE )
    collect_evidence ;;
  UPGRADE_DB )
    upgrade_database ;;
  esac
# end of task

############################################################
# end of task functions
############################################################

# You are run into the upgrade/update part, root access is needed
if [ `id -u` -ne 0 ]; then
  echo "You are run into the upgrade/update part, root access is required"
  Usage
  exit 1
fi
#
#Check script specific parms
#
OPTIND=1
while getopts ":i:b:w:" opt
do
  case ${opt} in
    i )  INSTS=${OPTARG} ;;
    b )  CPATH=${OPTARG} ;;
    w )  WPATH=${OPTARG} ;;
  esac
done

if [[ "$INSTS" == "" ]]; then
  echo "Instances name must be specific when upgrade/update instances"
  Usage
  exit 1
fi

if [[ "$CPATH" == "" ]]; then
  echo "DB2 code path must be specific when upgrade/update instances"
  Usage
  exit 1
fi

if [[ ! -f $CPATH/instance/db2iupdt ]]; then
  echo "db2iupdt is not exist on $CPATH/instance..."
  echo "Pls specify the right DB2 code path"
  Usage
  exit 1
fi

INSTS_TMP=`echo $INSTS | sed -e 's/,/./g'`
RFILE="$RPATH/${INSTS_TMP}.`date "+%H%M%S"`.log"

# erase the / in the code path if any, in case, with / , we can't match the code path
CPATH=$(echo $CPATH | sed -e 's/\/$//')

echo "@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&"
echo "@ Instances going to upgrade/update: $INSTS                       "
echo "@ Using code: $CPATH                                              "
echo "@ Working directory: $WPATH                                       "
echo "@ Output directory:  $RPATH                                       "
echo "@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&@&"

# check it's upgrade or update
INSTS_TMP="${INSTS},"
INST=`echo "$INSTS_TMP"|cut -d, -f 1`
current_version=$($CPATH/bin/db2greg -dump | grep ^I | grep -w $INST |\
   grep -v 'DB2INSTDEF' | awk -F',' '{print $3}' | cut -d'.' -f 1 | tail -1)
new_version=$($CPATH/bin/db2greg -dump | grep ^S | grep -w "$CPATH" |\
   awk -F',' '{print $3}' | cut -d'.' -f 1 | tail -1 )

task_step=1
# main function
echo "task #${task_step}: stop instances"                                           | tee $RFILE
$WPATH/$PROGM -t STOP_INST -i $INSTS                                                | tee -a $RFILE

((task_step=task_step+1))
if [[ "$current_version" == "$new_version" ]]; then
  echo "task #${task_step}: apply fixpack for instances"                            | tee -a $RFILE
  update_instance                                                                   | tee -a $RFILE
else
  echo "task #${task_step}: upgrade instances"                                      | tee -a $RFILE
  upgrade_instance                                                                  | tee -a $RFILE

  ((task_step=task_step+1))                                        
  echo "task #${task_step} upgrade databases"                                       | tee -a $RFILE
  $WPATH/$PROGM -t UPGRADE_DB -i $INSTS                                             | tee -a $RFILE
fi

((task_step=task_step+1))
echo "task #${task_step}: rebind databases"                                         | tee -a $RFILE
$WPATH/$PROGM -t BIND_DB -i $INSTS                                                | tee -a $RFILE

((task_step=task_step+1))
echo "task #${task_step}: health check on instances"                                | tee -a $RFILE
$WPATH/$PROGM -t HC -i $INSTS                                                       | tee -a $RFILE

((task_step=task_step+1))
echo "task #${task_step}: collect evidence for instances"                           | tee -a $RFILE
$WPATH/$PROGM -t CE -i $INSTS                                                       | tee -a $RFILE
# end of main function


# end of script