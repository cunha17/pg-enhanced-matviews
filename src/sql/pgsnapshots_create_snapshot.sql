--
-- ATTENTION: This is a free software. 
--            View the LICENSE.txt file for license information
--

------------------------------------------------------------------------------
-- FUNCTION: %BASE_SCHEMA%.create_snapshot
--
-- Creates a SNAPSHOT based on a LOCAL query or on a DBLINK query
-- TODO: ON PREBUILT TABLE -> may be child OO table ?
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION %BASE_SCHEMA%.create_snapshot(schemaname text, snapshotname text, query text, dblink text, kind text, pbt_table text)
  RETURNS bool AS
$BODY$
use strict;
use DBI;
use constant TRUE => 1;
use constant FALSE => "";
#-- Function parameters
my ($schemaname, $snapshotname, $query, $dblinkname, $kindname, $pbt_table) = @_;
$schemaname = lc($schemaname);
$snapshotname = lc($snapshotname);
$dblinkname = lc($dblinkname);
$kindname = lc($kindname);
$pbt_table = lc($pbt_table);
#-- Set this to 1 for debugging messages
$main::DEBUG=1;
#-- Remote database connection
my $dbh;
#-- Localhost superuser connection
my $dbh_local = DBI->connect(getCurrentDatabaseConnectionString(), '%SUPERUSER%', undef, {AutoCommit => 0});
my $sql = '';
my $sth;
my $row;
my $kind;
my $pbt;

if ($kindname eq 'fast') {
	$kind = 'F';
} elsif ($kindname eq 'complete') {
	$kind = 'C';
} elsif ($kindname eq 'force') {
	$kind = 'R';
} else {
	elog ERROR, "KIND of refresh should be 'FAST', 'COMPLETE' or 'FORCE' !";
}

if ("$pbt_table" eq '') {
	$pbt = '';
} else {
	$pbt = $pbt_table;
}

#-- Test if the SNAPSHOT entry already exists
if (snapshotExists($dbh_local, $schemaname, $snapshotname)) {
	elog ERROR, "Snapshot '$snapshotname' already created";
}

if ($pbt eq '') {
	#-- Test if another OBJECT exists on the same place
	if (objectExists($dbh_local, $schemaname, $snapshotname)) {
		elog ERROR, "An object at '$schemaname.$snapshotname' already exists";
	}
} else {
	#-- Test if the PREBUILT TABLE exists
	if (! objectExists($dbh_local, $schemaname, $pbt_table)) {
		elog ERROR, "Prebuilt table '$schemaname.$pbt_table' does not exist!";
	}
}

if ("$dblinkname" eq '') {
	#-- create local
	elog NOTICE, 'Creating LOCAL snapshot' if $main::DEBUG==1;
	createLocalSnapshot($dbh_local, $schemaname, $snapshotname, $query, $pbt);
} else {
	#-- create remote
	elog NOTICE, 'Creating REMOTE(DBLINK) snapshot' if $main::DEBUG==1;
	createRemoteSnapshot($dbh_local, $schemaname, $snapshotname, $query, $dblinkname, $pbt);
}

#-- get the DBLINK id
my $dblinkid = getDblinkId($dbh_local, $dblinkname);

#-- insert the snapshot into the catalog
$sql = <<SQL;
INSERT INTO %BASE_SCHEMA%.pg_snapshots(schemaname, snapshotname, query, dblinkid, kind, pbt_table)
VALUES (?, ?, ?, ?, ?, ?)
SQL
$sth = $dbh_local->prepare($sql);
$sth->execute(($schemaname, $snapshotname, $query, $dblinkid, $kind, $pbt));
if (! $sth->err) {
	elog NOTICE, "Snapshot entry created" if $main::DEBUG==1;
} else {
	elog ERROR, "Could not create snapshot entry. SQL=$sql ERROR=".$sth->errstr;
}
if ("$dblinkname" ne '') {
	registerRemoteSnapshot($dbh_local, $schemaname, $snapshotname, $dblinkname);
}
$dbh_local->commit;
$dbh_local->disconnect;
#-- All done. Let's return TRUE
return TRUE;

INCLUDE 'message.pl'
INCLUDE 'sqlLookup.pl'
INCLUDE 'snapshotExists.pl'
INCLUDE 'objectExists.pl'
INCLUDE 'getDblinkId.pl'
INCLUDE 'createLocalSnapshot.pl'
INCLUDE 'createRemoteSnapshot.pl'
INCLUDE 'getCurrentDatabaseConnectionString.pl'
INCLUDE 'registerRemoteSnapshot.pl'

#-- Dependencies
INCLUDE 'dbiGetConnection.pl'
INCLUDE 'getQueryWithNoRecords.pl'
INCLUDE 'getUnifiedSqlType.pl'
INCLUDE 'validateModifyPrebuiltTable.pl'
INCLUDE 'spiGetCurrentDatabase.pl'
INCLUDE 'getSnapshot.pl'
INCLUDE 'getDblinkById.pl'
INCLUDE 'retrieveMasterForSnapshot.pl'
INCLUDE 'call_driver_function.pl'

$BODY$
  LANGUAGE 'plperlu' VOLATILE;
ALTER FUNCTION %BASE_SCHEMA%.create_snapshot(schemaname text, snapshotname text, query text, dblink text, kind text, pbt_table text) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION %BASE_SCHEMA%.create_snapshot(text, text, text, text, text, text) TO "snapshot.users";
COMMENT ON FUNCTION %BASE_SCHEMA%.create_snapshot(schemaname text, snapshotname text, query text, dblink text, kind text, pbt_table text) IS $$
This function is part of PostgreSQL::Snapshots project.
This is the function that creates a snapshot. It only creates the snapshot placeholder with the same structure as the query result. The snapshot needs to be refresh to become filled.
$$;
