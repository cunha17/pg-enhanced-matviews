--
-- ATTENTION: This is a free software. 
--            View the LICENSE.txt file for license information
--

------------------------------------------------------------------------------
-- FUNCTION: %BASE_SCHEMA%.drop_snapshot
--
-- Removes a SNAPSHOT previously created with create_snapshot
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION %BASE_SCHEMA%.drop_snapshot(schemaname text, snapshotname text)
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
$main::DEBUG=0;
#-- Localhost superuser connection
my $dbh_local = DBI->connect(getCurrentDatabaseConnectionString(), '%SUPERUSER%', undef, {AutoCommit => 0});
my $dbh_remote;
my $sql;
my $sth;
my $row;
my $masterschema;
my $mastername;
my $snapshot;
my $dblink;
my $attr_href;
my $affected;
my $total;

if (! snapshotExists($dbh_local, $schemaname, $snapshotname)) {
	elog ERROR, "Snapshot '$schemaname.$snapshotname' does not exist";
}

my $snapshot = getSnapshot($dbh_local, $schemaname, $snapshotname);
if ("$snapshot->{'dblinkid'}" eq '') {
	#-- refresh local
	$dbh_remote = $dbh_local;
} else {
	$dblink = getDblinkById($dbh_local, $snapshot->{'dblinkid'});
	if ($dblink) {
		#--create the remote database connection
		$attr_href = eval($dblink->{'attributes'});
		$dbh_remote = dbiGetConnection(
			$dblink->{'datasource'}
			, $dblink->{'username'}
			, $dblink->{'password'}
			, $attr_href
			);
	} else {
		$dbh_remote = $dbh_local;
	}
}

($masterschema, $mastername) = retrieveMasterForSnapshot($dbh_remote, $snapshot);
if (snapshotLogExists($dbh_remote, $masterschema, $mastername)) {
	call_driver_function($dbh_remote, 'snapshot_do', 'UNREGISTER', $masterschema, $mastername, $snapshot->{'snapid'});
}
if ("$snapshot->{'dblinkid'}" ne '') {
	$dbh_remote->commit;
	$dbh_remote->disconnect;
}
#-- Then delete the SNAPSHOT entry in %BASE_SCHEMA%.pg_snapshots
$sql = <<SQL;
DELETE FROM %BASE_SCHEMA%.pg_snapshots 
WHERE schemaname=?
	AND snapshotname=?
SQL
$sth = $dbh_local->prepare($sql);
$sth->execute(($schemaname, $snapshotname));
if (! $sth->err) {
	elog NOTICE, "Snapshot entry removed" if $main::DEBUG==1;
} else {
	elog ERROR, "Could not remove Snapshot entry '$schemaname.$snapshotname'. $sth->{errstr}";
}

if ("$snapshot->{'pbt_table'}" ne '') {
	my $pbt_table = $snapshot->{'pbt_table'};
	my $row;
	my $sth;

	setTriggerStatus($dbh_local, $snapshot->{'schemaname'}, $snapshot->{'pbt_table'}, "$snapshot->{'pbt_table'}_pbt\$_trg", FALSE);

	#-- Remove all rows based on this snapshot
	$sql = <<SQL;
DELETE FROM $schemaname.${pbt_table}
WHERE pbt\$ = ?
SQL
	$sth = $dbh_local->prepare($sql);
	$affected = $sth->execute(($snapshot->{'snapid'}));
	if ($sth->err) {
		elog ERROR, "Could not delete snapshot based rows from prebuilt table. SQL=$sql.".$sth->errstr;
	}
	$dbh_local->commit;
        elog NOTICE, "Prebuilt table snapshot rows deleted: $affected" if $main::DEBUG==1;
	
	#-- Find out whether we are the last snapshot using this prebuilt table
	$sql = <<SQL;
SELECT count(*) as total
FROM %BASE_SCHEMA%.pg_snapshots
WHERE schemaname=?
	AND pbt_table=?
SQL
	my ($total) = sqlLookup($dbh_local, $sql, ($schemaname, $pbt_table));
	if ($total eq 0) {
	        elog NOTICE, "We are the last snapshot on this prebuilt table!" if $main::DEBUG==1;
		#-- Drop pbt$ column index
		$sql = <<SQL;
DROP INDEX ${pbt_table}_pbt\$_ix
SQL
		$dbh_local->do($sql);
		if ($dbh_local->err) {
			elog WARNING, "Could not drop the prebuilt table pbt\$ column index on table '$schemaname.$pbt_table'. ERR='".$dbh_local->errstr."' SQL='$sql'";
		}
	
		elog NOTICE, "Prebuilt table pbt\$ column index dropped." if $main::DEBUG==1;

		#-- Drop pbt$ column on Prebuilt table
		$sql = <<SQL;
ALTER TABLE $schemaname.${pbt_table}
DROP COLUMN pbt\$
SQL
		$dbh_local->do($sql);
		if ($dbh_local->err) {
			elog ERROR, "Could not drop the prebuilt table pbt\$ column on table '$schemaname.$pbt_table'. ERR='".$dbh_local->errstr."' SQL='$sql'";
		}
	
		elog NOTICE, "Prebuilt table pbt\$ column dropped." if $main::DEBUG==1;

		#-- Drop triggers on Prebuilt table
		$sql = <<SQL;
DROP TRIGGER ${pbt_table}_pbt\$_trg ON $schemaname.${pbt_table}
SQL
		$dbh_local->do($sql);
		if ($dbh_local->err) {
			elog ERROR, "Could not drop the prebuilt table trigger on table '$schemaname.$pbt_table'. ERR='".$dbh_local->errstr."' SQL='$sql'";
		}
	
		elog NOTICE, "Prebuilt table trigger dropped." if $main::DEBUG==1;
	
		#-- Drop trigger's function
		$sql = <<SQL;
DROP FUNCTION $schemaname.${pbt_table}_pbt\$_trgfn();
SQL
		$dbh_local->do($sql);
		if ($dbh_local->err) {
			elog ERROR, "Could not drop the prebuilt table trigger function '$schemaname.${pbt_table}_trgfn()'. ERR='".$dbh_local->errstr."' SQL='$sql'";
		}
	
		elog NOTICE, "Prebuilt table trigger function dropped." if $main::DEBUG==1;
	} else {
		setTriggerStatus($dbh_local, $snapshot->{'schemaname'}, $snapshot->{'pbt_table'}, "$snapshot->{'pbt_table'}_pbt\$_trg", TRUE);
	}
} else {
	#-- Actually drop the SNAPSHOT placeholder
	$sql = <<SQL;
DROP TABLE $schemaname.$snapshotname
SQL
	$sth = spi_exec_query($sql);
	if ($sth->{status} eq 'SPI_OK_UTILITY') {
		elog NOTICE, "Snapshot dropped" if $main::DEBUG==1;
	} else {
		elog ERROR, "Could not drop Snapshot '$schemaname.$snapshotname'. $sth->{status}";
	}
}

$dbh_local->commit;
$dbh_local->disconnect;
#-- All done. Let's return TRUE
return TRUE;

INCLUDE 'message.pl'
INCLUDE 'sqlLookup.pl'
INCLUDE 'snapshotExists.pl'
INCLUDE 'getSnapshot.pl'
INCLUDE 'getDblinkById.pl'
INCLUDE 'dbiGetConnection.pl'
INCLUDE 'retrieveMasterForSnapshot.pl'
INCLUDE 'snapshotLogExists.pl'
INCLUDE 'call_driver_function.pl'
INCLUDE 'setTriggerStatus.pl'
INCLUDE 'getCurrentDatabaseConnectionString.pl'

INCLUDE 'spiGetCurrentDatabase.pl'
$BODY$
  LANGUAGE 'plperlu' VOLATILE;
ALTER FUNCTION %BASE_SCHEMA%.drop_snapshot(schemaname text, snapshotname text) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION %BASE_SCHEMA%.drop_snapshot(text, text) TO "snapshot.users";
COMMENT ON FUNCTION %BASE_SCHEMA%.drop_snapshot(schemaname text, snapshotname text) IS $$
This function is part of PostgreSQL::Snapshots project.
This is the function that removes a snapshot.
$$;
