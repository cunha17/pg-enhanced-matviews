This is a COOK BOOK on how to setup a database with Pg::Snapshots support on FEDORA.

** IMPORTANT: It assumes that the server does not have postgresql installed **

The commands bellow are issued by the user "root" and should be followed from top to bottom with this sequence:

yum install perl-DBD-Pg
yum install postgresql-server postgresql-plperl
service postgresql initdb
service postgresql start
su - postgres
createlang -d template1 plperl
createlang -d template1 plperlu
createlang -d template1 plpgsql
cd /tmp
wget http://pgfoundry.org/frs/download.php/1520/pgsnapshot-0.3.1.tgz
tar -xvzf pgsnapshot-0.3.1.tgz
cd pgsnapshot-0.3.1
./Makefile.sh
psql -d template1 -c "create database snaptest;"
psql -d snaptest -f drivers/pg/snapshot.sql
psql -d snaptest -f pgsnapshots.sql

