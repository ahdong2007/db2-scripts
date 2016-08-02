

-- create table tmp2
db2 drop table tmp2
db2 "create table tmp2(empno int, sal int, ename varchar(10))"

-- keep insert data
[db2inst1@huayd ~]$ cat insert.sh 

db2 connect to sample

while [ 1 ]
do
	date
	db2 "insert into tmp2(empno, sal, ename) values (8888, 99999,'huayd')"
	db2 "delete from tmp2"
	db2 commit
done


--
-- change empno int  --> varchar
-- add deptno in 3rd place
-- change ename varchar(10) --> varchar(20)      
-- 事务（dml）可以正常直行，但是貌似会有不明显的停顿
[db2inst1@huayd ~]$ cat move2.sql 

connect to sample;
call sysproc.admin_move_table (
'DB2INST1',
'TMP2',
'',
'',
'',
'',
'',
'',
'empno varchar(20), sal int, deptno int, ename varchar(20)',
'',
'move');


-- tableid changed
db2 "select tableid from syscat.tables where tabname='TMP2'"


