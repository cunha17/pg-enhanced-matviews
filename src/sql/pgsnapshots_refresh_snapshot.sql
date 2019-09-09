--
-- ATTENTION: This is a free software. 
--            View the LICENSE.txt file for license information
--

------------------------------------------------------------------------------
-- FUNCTION: %BASE_SCHEMA%.refresh_snapshot
--
-- Refreshes(Fills) a previously created SNAPSHOT
-- It can refresh using the FORCE, FAST or COMPLETE method
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION %BASE_SCHEMA%.refresh_snapshot(schemaname text, snapshotname text)
  RETURNS bool AS
$BODY$
use strict;
use DBI;
use constant TRUE => 1;
use constant FALSE => "";
#-- Function parameters
my ($schemaname, $snapshotname) = @_;
$schemaname = lc($schemaname);
$snapshotname = lc($snapshotname);
#-- Set this to 1 for debugging messages
$main::DEBUG=1;
#-- Localhost superuser connection
my $dbh_local = DBI->connect(getCurrentDatabaseConnectionString(), '%SUPERUSER%', undef, {AutoCommit => 0});
#-- Remote database connection
my $dbh;
#-- Start time of this function
my $start_time = time();
my $sql = '';
my $rs;
my $row;
#-- Number of records refreshed
my $recs;

if (! snapshotExists($dbh_local, $schemaname, $snapshotname)) {
	elog ERROR, "Snapshot '$schemaname.$snapshotname' does not exist";
}

my $snapshot = getSnapshot($dbh_local, $schemaname, $snapshotname);
my $snapname = ("$snapshot->{'pbt_table'}" eq '') ? $snapshotname : $snapshot->{'pbt_table'};

#-- Test for object's privileges
my ($hasInsert, $hasDelete) = testObjectPrivileges($schemaname,$snapname,('insert', 'delete'));
if (! $hasInsert) {
	elog ERROR, "You don't have INSERT privilege on '$schemaname.$snapshotname' SNAPSHOT";
}
if (! $hasDelete) {
	elog ERROR, "You don't have DELETE privilege on '$schemaname.$snapshotname' SNAPSHOT";
}

if ("$snapshot->{'dblinkid'}" eq '') {
	#-- refresh local
	$recs = refreshSnapshot($dbh_local, $snapshot, undef);
} else {
	#-- refresh remote
	$recs = refreshSnapshot($dbh_local, $snapshot, getDblinkById($dbh_local, $snapshot->{'dblinkid'}));
}

#-- Compute the elapsed time
my $stop_time = time();
my $secs = $stop_time - $start_time;
elog NOTICE, "Refreshed $recs records in $secs seconds.";
$sql = "UPDATE %BASE_SCHEMA%.pg_snapshots SET elapsedtime=? WHERE schemaname=? and snapshotname=?";
$rs=$dbh_local->prepare($sql);
$rs->execute(($secs, $schemaname, $snapshotname));
if ($rs->err) {
	elog NOTICE, "Could not update snapshot '$snapshot->{schemaname}.$snapshot->{snapshotname}' information. Error:" . $rs->errstr;
}
$dbh_local->commit;
$dbh_local->disconnect;

#-- Renew internal statistics about the refreshed object
$dbh_local = DBI->connect(getCurrentDatabaseConnectionString(), '%SUPERUSER%', undef, {AutoCommit => 1});

if (! vacuum($dbh_local, $snapshot->{schemaname}, $snapname)) {
	elog NOTICE, "Could not vacuum snapshot '$schemaname.$snapname':" . $dbh_local->errstr;
}

$dbh_local->disconnect;

#-- All done. Let's return TRUE
return TRUE;

INCLUDE 'message.pl'
INCLUDE 'sqlLookup.pl'
INCLUDE 'snapshotExists.pl'
INCLUDE 'testObjectPrivileges.pl'
INCLUDE 'getSnapshot.pl'
INCLUDE 'refreshSnapshot.pl'
INCLUDE 'getDblinkById.pl'
INCLUDE 'vacuum.pl'
INCLUDE 'getCurrentDatabaseConnectionString.pl'

#--Dependencies
INCLUDE 'dbiGetConnection.pl'
INCLUDE 'prepareForRefresh.pl'
INCLUDE 'performCompleteRefresh.pl'
INCLUDE 'performFastRefresh.pl'
INCLUDE 'finalizeRefresh.pl'
INCLUDE 'purgeSnapshotLog.pl'
INCLUDE 'spiGetCurrentDatabase.pl'

INCLUDE 'call_driver_function.pl'
INCLUDE 'setTriggerStatus.pl'
INCLUDE 'getColumnList.pl'
INCLUDE 'getSourceKeysFromQuery.pl'

INCLUDE 'retrieveMasterForSnapshot.pl'
INCLUDE 'snapshotLogExists.pl'
INCLUDE 'getLastSnapshotLogRefresh.pl'
INCLUDE 'getRefreshMethod.pl'
INCLUDE 'updateLastSnapshotLogRefresh.pl'
INCLUDE 'updateNullSnaptimeRows.pl'
INCLUDE 'getInsertedUpdatedLogRecordsFilter.pl'

INCLUDE 'countSnapshotLogModifiedRows.pl'
INCLUDE 'getSthColumnTypes.pl'
INCLUDE 'map2PgType.pl'

INCLUDE 'getSnapshotLogColumns.pl'
INCLUDE 'getLogKeys.pl'
INCLUDE 'getSnapshotLogName.pl'
INCLUDE 'deleteOldSnapshotRecords.pl'
INCLUDE 'getSnapshotLogName.pl'
INCLUDE 'getUnifiedSqlType.pl'

INCLUDE 'getUpdatedDeletedLogRecordsFilter.pl'

INCLUDE 'db/cursor.pl'
INCLUDE 'db/oracle/cursor.pl'
INCLUDE 'db/pg/cursor.pl'
INCLUDE 'db/sybase/cursor.pl'
INCLUDE 'db/odbc/cursor.pl'
INCLUDE 'db/freetds/cursor.pl'
INCLUDE 'db/mysql/cursor.pl'
$BODY$
  LANGUAGE 'plperlu' VOLATILE;
ALTER FUNCTION %BASE_SCHEMA%.refresh_snapshot(schemaname text, snapshotname text) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION %BASE_SCHEMA%.refresh_snapshot(text, text) TO "snapshot.users";
COMMENT ON FUNCTION %BASE_SCHEMA%.refresh_snapshot(schemaname text, snapshotname text) IS $$
This function is part of PostgreSQL::Snapshots project.
This is the function that refreshes the snapshot. The refreshing process may take a long time depending on the size of the result, the connection speed, etc. This is not a memory consuming process once all the process is divided in transaction chunks of 1000 records. It uses more CPU (because of Perl) and network (because of the resultset size) than memory.
$$;
