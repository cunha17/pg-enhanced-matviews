#!/bin/sh

# You may change the following variables to best suit your needs

##
# KEY is the communication key between any two servers 
# or between a DBA workstation and a server
##
KEY=123456

##
# BASE_SCHEMA is the schema where all base(internal) tables of Pg::Snapshot will be placed
##
BASE_SCHEMA=public

##
# LOCAL postgresql server superuser
##
SUPERUSER=postgres

# You may not need to change anything beyond this line
if [ "$1" == "clean" ]; then
	echo "Removing pgsnapshots.sql..."
        rm -f pgsnapshots.sql
	echo "Removing previously generated SQL drivers..."
        find drivers -name snapshot.sql | xargs rm -f
        echo "Cleaned."
        exit 0
fi

function apply {
	cat $1 | awk '/^INCLUDE .*$/ { system("cat src/pl/"$2"")} !/^INCLUDE .*$/ {print}' | sed "s/%BASE_SCHEMA%/$BASE_SCHEMA/g" | sed "s/%COMMUNICATION_KEY%/$KEY/g" | sed "s/%SUPERUSER%/$SUPERUSER/g"
}

IFS=' '
SQLS='pgsnapshots_tables.sql pgsnapshots_dblink.sql pgsnapshots_create_snapshot.sql pgsnapshots_drop_snapshot.sql pgsnapshots_refresh_snapshot.sql pgsnapshots_snapshotlog.sql'

rm -f pgsnapshots.sql
for F in $SQLS; do
	#echo $F
	apply src/sql/$F >> pgsnapshots.sql
done
IFS=$'\n\t '
for F in `find drivers -name snapshot.template.sql`; do
	OUTFILE=`echo "$F" | sed "s/\.template\.sql/.sql/"`
	cat $F | sed "s/%BASE_SCHEMA%/$BASE_SCHEMA/g" | sed "s/%COMMUNICATION_KEY%/$KEY/g" > $OUTFILE
done
echo "Done."
