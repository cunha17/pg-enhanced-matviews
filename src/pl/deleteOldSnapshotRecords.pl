#--
#-- SUB: deleteOldSnapshotRecords
#-- Removes old records from the local snapshot based on the snapshot log
#--
sub deleteOldSnapshotRecords {
	#-- Function parameters
	my ($dbh_local, $dbh_remote, $snapshot, $masterschema, $mastername, $lastRefresh, @keys) = @_;	

	#-- Local variables
	my $sql;
	my $filter;
	my $sth_local;
	my $sth_remote;
	my $qms;
	my $recs;
	my $sqlRow;
	my ($masterKeys, $logKeys, @arrLogKeys) = @keys;
	my $snapshotLogName = getSnapshotLogName($dbh_remote, $masterschema, $mastername);
	my $snapshotname;

	#-- Delete modified/removed records from SNAPSHOT
	$filter = getUpdatedDeletedLogRecordsFilter($dbh_remote, $lastRefresh);
	$sql = <<SQL;
SELECT $logKeys
FROM $masterschema.$snapshotLogName
WHERE $filter
SQL
	$sth_remote = $dbh_remote->prepare($sql);
	if ($dbh_remote->err) {
		error ("Could not retrieve records to delete: $sql [".$dbh_remote->errstr."]");
	}
	$sth_remote->execute();
	if ($sth_remote->err) {
		error ("Could not retrieve records to delete: $sql [".$sth_remote->errstr."]");
	}
	
	my @master = getSourceKeysFromQuery($snapshot->{'query'}, split(',', $masterKeys));
	$sqlRow = '';
	
	for (my $i=0; $i < @master; ++$i) {
		$sqlRow .= " AND " . @master[$i] . '=?';
	}
	$sqlRow = substr($sqlRow, 5);

	$snapshotname = ($snapshot->{'pbt_table'} eq '') ? $snapshot->{'snapshotname'} : $snapshot->{'pbt_table'};
	$sql = <<SQL;
DELETE FROM $snapshot->{'schemaname'}.$snapshotname 
WHERE $sqlRow
SQL
	if ($snapshot->{'pbt_table'} ne '') {
		$sql .= " AND pbt\$ = $snapshot->{'snapid'}";
	}
	$sth_local = $dbh_local->prepare($sql);
	if ($dbh_local->err) {
		error ("Could not erase old records from snapshot: $sql [".$dbh_local->errstr."]");
	}
	
	$recs = 0;
	setTriggerStatus($dbh_local, $snapshot->{'schemaname'}, $snapshotname, "${snapshotname}_pbt\$_trg", FALSE);
	while(my @row = $sth_remote->fetchrow_array) {
		$sth_local->execute(@row);
		if ($sth_local->err) {
			error ($sth_local->errstr);
		}
		++$recs;
		if (($recs % 1000) == 0) {
			$dbh_local->commit;
			notice ("Deleted. Record #$recs");
		}
	}
        setTriggerStatus($dbh_local, $snapshot->{'schemaname'}, $snapshotname, "${snapshotname}_pbt\$_trg", TRUE);

	if (! $sth_remote->err) {
		notice ("Deleted $recs modified records");
	} else {
		error ("Could delete modified snapshot records: $sql [".$sth_remote->errstr."]");
	}

	$dbh_local->commit;
	$sth_local->finish;

	return $recs;
}

