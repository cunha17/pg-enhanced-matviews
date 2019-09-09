#--
#-- SUB: performFastRefresh
#-- Performs a FAST REFRESH on a snapshot
#--
sub performFastRefresh {
	#-- Function parameters
	my ($dbh_local, $dbh_remote, $snapshot, $masterschema, $mastername, $lastRefresh) = @_;

	#-- Local variables
	my $sth_local;
	my $sth_remote;
	my $masterKeys = getSnapshotLogColumns($dbh_remote, $masterschema, $mastername);
	my $qms;
	my $oldrecs;
	my $recs;
	my $errors;
	my $sql;
	my $where;
	my @types;
	my ($logKeys, $arrLogKeys) = getLogKeys ($masterKeys);
	my @keys = ($masterKeys, $logKeys, @$arrLogKeys);
	my $snapshotLogName = getSnapshotLogName($dbh_remote, $masterschema, $mastername);
	my $snapshotname;
	my $targetColumnList;
	my $cursor;
	my $chunkSize=1000;
	my $nof;

	#-- Remove old records from the snapshot
	my $deleted = deleteOldSnapshotRecords($dbh_local, $dbh_remote, $snapshot, $masterschema, $mastername, $lastRefresh, @keys);

	my @arrMasterKeys = getSourceKeysFromQuery($snapshot->{'query'}, split(',', $masterKeys));
	my $filter = '';
	for (my $i = 0; $i < @arrMasterKeys; ++$i) {
		$filter .= ' AND source.'.@arrMasterKeys[$i].'=keys.'.@$arrLogKeys[$i];
	}
	$filter = substr($filter, 5);
	my $logFilter = getInsertedUpdatedLogRecordsFilter($dbh_remote, $lastRefresh);
	my $source = $snapshot->{'query'};
	$sql = <<SQL;
SELECT source.*
FROM ($source) source,
	(SELECT $logKeys
	FROM $masterschema.$snapshotLogName
	WHERE $logFilter) keys
WHERE $filter
SQL
	notice ("Filter SQL is: $sql");
	notice ("LastRefresh is: $lastRefresh");
	$sth_remote = $dbh_remote->prepare("SELECT * FROM ($sql) source WHERE 1=0");
	$sth_remote->execute;

	$nof = $sth_remote->{NUM_OF_FIELDS};
	$qms = '?,' x $nof;
	chop($qms);

	if ($snapshot->{'pbt_table'} ne '') {
		$qms = "$snapshot->{'snapid'},$qms";
	}

	$snapshotname = ($snapshot->{'pbt_table'} eq '') ? $snapshot->{'snapshotname'} : $snapshot->{'pbt_table'};
	$targetColumnList = join(',', getColumnList($sth_remote));

	if ($snapshot->{'pbt_table'} ne '') {
		$targetColumnList = "pbt\$,$targetColumnList";
	}
	$sql = <<SQL;
INSERT INTO $snapshot->{'schemaname'}.$snapshotname($targetColumnList)
VALUES ($qms)
SQL
	$sth_local = $dbh_local->prepare($sql);
	if ($dbh_local->err) {
		error ("Could not add new records into snapshot: $sql [".$dbh_local->errstr."]");
	}

	@types = getSthColumnTypes($sth_remote);
	for (my $count=0; $count < $nof; $count++) {
		if (@types[$count] eq undef) {
			$sth_local->bind_param($count + 1, undef);
		} else {
			$sth_local->bind_param($count + 1, undef, @types[$count]);
		}
	}

	$sth_remote->finish;

	notice ('Fetching records.');

	$sql = <<SQL;
SELECT source.*
FROM ($source) source,
	(SELECT $logKeys
	FROM $masterschema.$snapshotLogName
	WHERE $logFilter) keys
WHERE $filter
SQL
	$cursor = openCursor($dbh_remote, $sql);
	if ($dbh_remote->err) {
		error ("Could not create remote cursor for query: $sql [".$dbh_remote->errstr."]");
	}

	$oldrecs = -1;
	$recs = $errors = 0;
	setTriggerStatus($dbh_local, $snapshot->{'schemaname'}, $snapshotname, "${snapshotname}_pbt\$_trg", FALSE);

	for (;$oldrecs ne $recs;) {
		$oldrecs = $recs;
	        $sth_remote = fetchCursor($dbh_remote, $cursor, $chunkSize);
        	if ($dbh_remote->err) {
                	error ("Could not fetch cursor '$cursor': [".$dbh->errstr."]");
	        }

		#-- Loop through all fetched records and insert them one at a time into the SNAPSHOT
		my $ok = (1 eq 1);
		while($ok) {
			my @row;
                        eval {
                                my $handler = $SIG{'__WARN__'};
                                $SIG{'__WARN__'} = sub { };
                                @row = $sth_remote->fetchrow_array;
                                $sth_remote->set_err (undef, undef);
                                $SIG{'__WARN__'} = $handler;
                        };
                        if ($@ or ! @row) {
                                $ok = (1 eq 0);
                        } else {
				$sth_local->execute(splice(@row, 0, $nof));
				if ($sth_local->err) {
					++$errors;
				}
				++$recs;
	                        if ($recs % $chunkSize eq 0) {
        	                        $dbh_local->commit;
                	                notice ("Commit. Record #$recs");
                        	}
			}

		}
		if ($sth_remote->err) {
			error ($sth_remote->errstr);
		}
	}
	$dbh_local->commit;
	$sth_local->finish;

	closeCursor($dbh_remote, $cursor);

	$recs = $recs - $errors;

	notice ("Inserted $recs modified records");
	if ($errors > 0) {
		error ("$errors errors on insertion process");
	}

	setTriggerStatus($dbh_local, $snapshot->{'schemaname'}, $snapshotname, "${snapshotname}_pbt\$_trg", TRUE);

	return $recs;
}

