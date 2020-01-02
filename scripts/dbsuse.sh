#!/bin/sh
# ----------------------------------------------------------------------
# File Name     : dbsuse.sh
# Author        : Ihor Zaiets
# Description   : Display informix dbspace usage spaces
# Last Modified : 2006-06-05
# ----------------------------------------------------------------------
# Set IDS environmets

INFENV=/etc/informix/server
if [ -r $INFENV ]
 then
  . $INFENV
fi

unset INFENV

# set path to AWK
AWKSERV_OS=`uname`
if [ "$AWKSERV_OS" = "SunOS" ]
  then
    NAWK=/bin/nawk
  else
    NAWK=/bin/awk
fi
# ----------------------------------------------------------------------
IDSVERSION=`echo "select dbinfo('version','major') version from systables where tabid = 1" | \
dbaccess sysmaster 2>/dev/null | $NAWK  '$1=="version"{getline;getline;print}'`


printhelp() {
printf "Script for prognose dbspace usage\n"
printf "USAGE:$0 [-h]\n"
printf "output:\n"
printf "|--------------------------------------------------------------------------------------------|\n"
printf "|    dbspace               size_p     free_p     next     maxnext   free  used   max_e_size  |\n"
printf "|--------------------------------------------------------------------------------------------|\n"
printf "\t dbspace    - name of the dbspace\n"
printf "\t size_p     - size allocated for dbspace in pages\n"
printf "\t free_p     - number of the free pages in dbspace\n"
printf "\t next       - number of the all next pages at sum(next size) for all tables\n"
printf "\t maxnext    - maximum extent size for tables in pages\n"
printf "\t free       - percent free pages\n"
printf "\t used       - percent used pages\n"
printf "\t max_e_size - max. allowable extent size in pages\n"
printf "Monitoring:\n"
printf " 1. If next > free_p - add chunk\n"
printf " 2. If free_p is large and max_e_size is small - necessary defragmentation for tables\n"
printf "\n"
printf "\n"
printf "\n"
printf "\n"

}

while getopts h i; do
  case $i in
    h) printhelp $0 ; exit 0;;
  esac
done


# ----------------------------------------------------------------------
OUTPUT1=/tmp/dbsuse1.$$.out
OUTPUT2=/tmp/dbsuse2.$$.out

IDSVERSION=`echo "select dbinfo('version','major') version from systables where tabid = 1" | \
dbaccess sysmaster 2>/dev/null |  $NAWK '$1=="version"{getline;getline;print}'`

# Get dbspace and pagesize
if [ $IDSVERSION -lt 10 ]
  then
   PSIZE=`onstat -b | grep "buffer size" | nawk '{print $(NF-2)}'`
   echo "set isolation to dirty read ;unload to $OUTPUT2 select dbsnum,$PSIZE from sysdbspaces" |\
    dbaccess -e sysmaster >/dev/null 2>&1
   unset PSIZE
  else
   #echo "set isolation to dirty read ;unload to $OUTPUT2 select dbsnum,pagesize from sysdbspaces" | \
   # dbaccess -e sysmaster >/dev/null 2>&1
   PSIZE=`onstat -b | grep "buffer size" | nawk '{print $(NF-2)}'|head -1`
   echo "set isolation to dirty read ;unload to $OUTPUT2 select dbsnum,$PSIZE from sysdbspaces" |\
    dbaccess -e sysmaster >/dev/null 2>&1
fi

dbaccess  sysmaster >/dev/null 2>&1 <<!!
set isolation to dirty read;

-- drop table tmp_dfe;
-- drop table tmp_p;

create temp table tmp_dbs_pagesize (
 dbsnum  integer,
 pagesize integer) with no log ;
load from $OUTPUT2 insert into tmp_dbs_pagesize ;


select
 c.dbsnum,
 max(f.leng) leng
from
  sysmaster:syschfree f
  ,sysmaster:syschunks c
where
  f.chknum = c.chknum
 group by 1
into temp tmp_dfe with no log;

select
dbinfo('dbspace',p.partnum) name
,sum(p.nextsiz)::integer next
,max(p.nextsiz)::integer maxnext
from
 sysmaster:sysptnhdr p
where
 (((p.nptotal - p.npused )*100)/p.nextsiz) > 10
group by 1
into temp tmp_p with no log;

unload to $OUTPUT1
select unique
  d.dbsnum
  ,d.name
  ,sum(c.chksize)::integer  dbsize
  ,sum(c.nfree)::integer    dbfree
  ,p.next          next
  ,p.maxnext       maxnext
  ,((sum(c.nfree)*100)/sum(c.chksize))::integer            pct_free
  ,(100 - (sum(c.nfree)*100)/sum(c.chksize))::integer      pct_used
  ,dfe.leng                                                mx_chunk_l
  , ds.pagesize/1024::integer
from
  sysmaster:syschunks c
  ,sysmaster:sysdbspaces d
  , tmp_dbs_pagesize ds
  , outer tmp_p p
  ,outer tmp_dfe dfe
where
  d.dbsnum = c.dbsnum
  and d.name = p.name
  and ds.dbsnum = d.dbsnum
  and dfe.dbsnum = d.dbsnum
group by 1,2,5,6,9,10
order by 1,2;
!!

if [ -n $OUTPUT1 ]
 then
  LC_ALL=C
  printf "Date: `date '+%Y-%m-%d %H:%M'`\n"
  $NAWK -F"|" '
  BEGIN{
     printf("|--------------------------------------------------------------------------------------------------|\n")
     printf("|    dbspace             size        free      next     maxnext   free   used max_e_size | Message |\n")
     printf("|--------------------------------------------------------------------------------------------------|\n")
       }
  {
   if ( $5 >= $4*$10 ) { dbs_msg = "Warning" } else { dbs_msg = "Normal" }
   printf("  %-16s  %12s  %9d  %7s  %9s  %5s  %5s %12s %-8s\n",$2,$3*$10,$4*$10,$5,$6,$7,$8,$9,dbs_msg)

  }

' $OUTPUT1

fi

rm -f $OUTPUT1 $OUTPUT2
