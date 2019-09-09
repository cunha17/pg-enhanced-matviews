#--
#-- SUB: performCompleteRefresh
#-- Performs a COMPLETE REFRESH on a snapshot
#--
sub performCompleteRefresh {
	#-- Function parameters
	my ($dbh_local, $dbh_remote, $snapshot) = @_;

	#-- Local variables
	my $sql;
	my $sth_remote;
	my $sth_local;
	my $oldrecs;
	my $recs;
	my $errors;
	my $snapshotname;
	my $targetColumnList;
 	my $cursor;
	my $chunkSize = 1000;
	my $nof;

	#--Fetches the remote database query
	$sql = $snapshot->{'query'};
	notice ("sql is \n$sql");

	$sth_remote = $dbh_remote->prepare("SELECT * FROM ($sql) source WHERE 1=0");
	$sth_remote->execute;

	#-- Parameterized query placeholders (question marks)
	$nof = $sth_remote->{NUM_OF_FIELDS};
	my $qms = '?,' x $nof; 
	chop($qms);

	$snapshotname = ($snapshot->{'pbt_table'} eq '') ? $snapshot->{'snapshotname'} : $snapshot->{'pbt_table'};
	$targetColumnList = join(',', getColumnList($sth_remote));
	if ($snapshot->{'pbt_table'} eq '') {
		#--Truncates (empty) the local SNAPSHOT
		$sql = <<SQL;
TRUNCATE $snapshot->{'schemaname'}.$snapshotname
SQL
		$dbh_local->do($sql);
		if (! $dbh_local->err) {
			notice ("Snapshot truncated");
		} else {
			error ("Could not truncate snapshot: $sql [".$dbh_local->errstr."]");
		}
	} else {
		setTriggerStatus($dbh_local, $snapshot->{'schemaname'}, $snapshotname, "${snapshotname}_pbt\$_trg", FALSE);
		$targetColumnList = "pbt\$,$targetColumnList";
		$qms = "$snapshot->{'snapid'},$qms";
		#-- Deletes all rows where pbt$ eq $snapid
		$sql = <<SQL;
DELETE FROM $snapshot->{'schemaname'}.$snapshotname
WHERE pbt\$ = ?
SQL
		my $sth_aux = $dbh_local->prepare($sql);
		$sth_aux->execute(($snapshot->{'snapid'}));
		if (! $sth_aux->err) {
			notice ("Snapshot cleaned.");
		} else {
			error ("Could not clean snapshot: $sql [".$sth_aux->errstr."]");
		}
	}
	$dbh_local->commit;

	#-- Fill the SNAPSHOT with the remote database query results
	
		#-- Prepare the INSERT query that will be executed for each returned query
		$sql = <<SQL;
INSERT INTO $snapshot->{'schemaname'}.$snapshotname($targetColumnList)
VALUES ($qms)
SQL
		notice ($sql);
		$sth_local = $dbh_local->prepare($sql);

		#-- Set the type of target row parameters to the same type of source row columns
		my @types = getSthColumnTypes($sth_remote);
		for (my $count=0; $count < $nof; $count++) {
			if (@types[$count] eq undef) {
				$sth_local->bind_param($count + 1, undef);
			} else {
				$sth_local->bind_param($count + 1, undef, @types[$count]);
			}
		}

		$sth_remote->finish;

		$sql = $snapshot->{'query'};
	        $cursor = openCursor($dbh_remote, $sql);
        	if ($dbh_remote->err) {
                	error ("Could not create remote cursor for query: $sql [".$dbh_remote->errstr."]");
	        }

		$oldrecs = -1;
		$recs = $errors = 0;
		for (;$oldrecs ne $recs;) {
			$oldrecs = $recs;
			$sth_remote = fetchCursor($dbh_remote, $cursor, $chunkSize);
			if ($dbh_remote->err) {
                        	error ("Could not fetch cursor '$cursor': [".$dbh_remote->errstr."]");
			}

			#-- Loop through all fetched records and insert them one at a time into the SNAPSHOT
			my $ok = (1 eq 1);
			while ($ok) {
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
						if ($errors eq 0) {
							error ($sth_local->errstr);
						}
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

		notice ("All $recs records processed. $errors errors.");
	if ($snapshot->{'pbt_table'} ne '') {
		setTriggerStatus($dbh_local, $snapshot->{'schemaname'}, $snapshotname, "${snapshotname}_pbt\$_trg", TRUE);
	}
	#-- Returns the number of records inserted
	return $recs-$errors;
}
