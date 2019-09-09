--
-- ATTENTION: This is a free software. 
--            View the LICENSE.txt file for license information
--

------------------------------------------------------------------------------
-- FUNCTION: %BASE_SCHEMA%.create_snapshot_log
--
-- Creates a SNAPSHOT LOG on a TABLE to be used on FAST refreshes
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION %BASE_SCHEMA%.create_snapshot_log(schemaname text, mastername text, withwhat text)
  RETURNS bool AS
$BODY$
use strict;
use DBI;
use constant TRUE => 1;
use constant FALSE => "";
#-- Function parameters
my ($schemaname, $mastername, $withwhat) = @_;
#-- Set this to 1 for debugging messages
$main::DEBUG=0;
#-- Localhost superuser connection
my $dbh_local = DBI->connect(getCurrentDatabaseConnectionString(), '%SUPERUSER%', undef, {AutoCommit => 0});
#-- variables
my $sql;
my $rs;
my $row;
my $sth;
my $masterKeyColumns;
my $logKeyColumns;
my $masterPkColumns;
my $masterFilterColumns;
my $flag;
my $log;

#-- Test if the SNAPSHOT LOG already exists
if (snapshotLogExists($dbh_local, $schemaname, $mastername)) {
	elog ERROR, "Snapshot log on '$schemaname.$mastername' already exists! SQL=$sql";
}

if (! objectExists($dbh_local, $schemaname, $mastername)) {
	elog ERROR, "Master '$schemaname.$mastername' does not exist! SQL=$sql";
}

($flag, $masterKeyColumns, $logKeyColumns, $masterPkColumns, $masterFilterColumns) = getKeyColumns($dbh_local, $schemaname, $mastername, $withwhat);
elog NOTICE, 'KEY='.join(',', keys %$logKeyColumns) . ' TYPES='.join(',', values %$logKeyColumns) . ' FLAG='.$flag if $main::DEBUG == 1;

#-- Create the Snapshot's Log Table
$log = createSnapshotLogTable($schemaname, $mastername, $logKeyColumns);
createSnapshotLogTableIndexes($schemaname, $mastername, $log, $logKeyColumns);
createSnapshotLogTrigger($dbh_local, $schemaname, $mastername, $log, $masterKeyColumns, $logKeyColumns);

createSnapshotLogEntry($dbh_local, $schemaname, $mastername, $flag, $log, $masterPkColumns, $masterFilterColumns);

#--call_driver_function($dbh_local, 'snapshot_do', 'REGISTER', $schemaname, $mastername, $snapid);

$dbh_local->commit;
$dbh_local->disconnect;
#-- All done. Let's return TRUE
return TRUE;

INCLUDE 'sqlLookup.pl'
INCLUDE 'snapshotLogExists.pl'
INCLUDE 'objectExists.pl'
INCLUDE 'getPgTypeName.pl'
INCLUDE 'getUnifiedSqlType.pl'
INCLUDE 'map2PgType.pl'
INCLUDE 'getKeyColumns.pl'
INCLUDE 'createSnapshotLogTable.pl'
INCLUDE 'createSnapshotLogTableIndexes.pl'
INCLUDE 'createSnapshotLogTrigger.pl'
INCLUDE 'createSnapshotLogEntry.pl'
INCLUDE 'call_driver_function.pl'
INCLUDE 'getCurrentDatabaseConnectionString.pl'

#-- Dependencies

INCLUDE 'getObjectMeta.pl'
INCLUDE 'createSnapshotLogEntryColumns.pl'
INCLUDE 'spiGetCurrentDatabase.pl'

$BODY$
  LANGUAGE 'plperlu' VOLATILE;
ALTER FUNCTION %BASE_SCHEMA%.create_snapshot_log(schemaname text, mastername text, withwhat text) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION %BASE_SCHEMA%.create_snapshot_log(text, text, text) TO "snapshot.users";
COMMENT ON FUNCTION %BASE_SCHEMA%.create_snapshot_log(schemaname text, mastername text, withwhat text) IS $$
This function is part of PostgreSQL::Snapshots project.
This is the function that creates a snapshot log.
$$;

------------------------------------------------------------------------------
-- FUNCTION: %BASE_SCHEMA%.drop_snapshot_log
--
-- Removes a previously created SNAPSHOT LOG
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION %BASE_SCHEMA%.drop_snapshot_log(schemaname text, mastername text)
  RETURNS bool AS
$BODY$
use strict;
use DBI;
use constant TRUE => 1;
use constant FALSE => "";
#-- Function parameters
my ($schemaname, $mastername) = @_;
#-- Set this to 1 for debugging messages
$main::DEBUG=0;
#-- Localhost superuser connection
my $dbh_local = DBI->connect(getCurrentDatabaseConnectionString(), '%SUPERUSER%', undef, {AutoCommit => 0});
my $sql;
my $rs;
my $row;
my $log;

if (! snapshotLogExists($dbh_local, $schemaname, $mastername)) {
	elog ERROR, "Snapshot log on '$schemaname.$mastername' does not exist!";
}
elog NOTICE, "Snapshot log on '$schemaname.$mastername' exists..." if $main::DEBUG==1;

$log = getSnapshotLogName($dbh_local, $schemaname, $mastername);

elog NOTICE, "Snapshot log on '$schemaname.$mastername' is $log" if $main::DEBUG==1;

$dbh_local->commit;

#-- Drop the Snapshot's Log Table
$sql = <<SQL;
DROP TABLE $schemaname.$log
SQL

$rs = spi_exec_query($sql);
if ($rs->{status} ne 'SPI_OK_UTILITY') {
	elog ERROR, "Could not drop Snapshot log '$schemaname.$log'. STATUS='".$rs->status."' SQL='$sql'";
}

elog NOTICE, "Snapshot log '$log' dropped." if $main::DEBUG==1;

#-- Delete the Snapshot Log entry
$sql = <<SQL;
DELETE FROM %BASE_SCHEMA%.pg_mlogs 
WHERE masterschema=? 
	AND mastername=?
SQL

$rs = $dbh_local->prepare($sql);
$rs->execute($schemaname, $mastername);
if ($rs->err) {
	elog ERROR, "Could not delete snapshot log entry on system table '%BASE_SCHEMA%.pg_mlogs'. ERR='".$rs->errstr."' SQL='$sql'";
}

elog NOTICE, "Snapshot log entry removed." if $main::DEBUG==1;

#-- Drop triggers on master table
$sql = <<SQL;
DROP TRIGGER ${log}_trg ON $schemaname.${mastername}
SQL

$dbh_local->do($sql);
if ($dbh_local->err) {
	elog ERROR, "Could not drop the snapshot log trigger on table '$schemaname.$mastername'. ERR='".$dbh_local->errstr."' SQL='$sql'";
}

elog NOTICE, "Snapshot log table trigger dropped." if $main::DEBUG==1;

#-- Drop trigger's function
$sql = <<SQL;
DROP FUNCTION $schemaname.${log}_trgfn();
SQL

$dbh_local->do($sql);
if ($dbh_local->err) {
	elog ERROR, "Could not drop the snapshot log trigger function '$schemaname.mlog\$_${mastername}_trgfn()'. ERR='".$dbh_local->errstr."' SQL='$sql'";
}

elog NOTICE, "Snapshot log trigger function dropped." if $main::DEBUG==1;

$dbh_local->commit;
$dbh_local->disconnect;
#-- All done. Let's return TRUE
return TRUE;

INCLUDE 'message.pl'
INCLUDE 'sqlLookup.pl'
INCLUDE 'snapshotLogExists.pl'
INCLUDE 'getSnapshotLogName.pl'
INCLUDE 'getCurrentDatabaseConnectionString.pl'

#-- Dependencies

INCLUDE 'call_driver_function.pl'
INCLUDE 'spiGetCurrentDatabase.pl'

$BODY$
  LANGUAGE 'plperlu' VOLATILE;
ALTER FUNCTION %BASE_SCHEMA%.drop_snapshot_log(schemaname text, mastername text) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION %BASE_SCHEMA%.drop_snapshot_log(text, text) TO "snapshot.users";
COMMENT ON FUNCTION %BASE_SCHEMA%.drop_snapshot_log(schemaname text, mastername text) IS $$
This function is part of PostgreSQL::Snapshots project.
This is the function that drops a snapshot log.
$$;
