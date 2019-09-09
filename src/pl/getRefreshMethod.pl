#--
#-- SUB: getRefreshMethod
#-- Returns the best refresh method supported by the SNAPSHOT refreshing process
#--
sub getRefreshMethod {
	#-- Function parameters
	my ($dbh, $snapshot, $masterschema, $mastername, $lastRefresh) = @_;

	#-- Local variables
	my $sql;
	my $sth;
	my $kind = $snapshot->{'kind'};
	my $row;

	if (($lastRefresh eq undef) || ($lastRefresh eq '1900-01-01 00:00:00')) { #-- It's the snapshot first refresh: always COMPLETE
		notice ('First Refresh detected.');
		$kind = 'C';
	} elsif (($kind eq 'R') or ($kind eq 'F')) { #-- The snapshot was created with REFRESH FORCE or REFRESH FAST
		#-- Test if LOG exists
		if (snapshotLogExists($dbh, $masterschema, $mastername)) {
			#-- count the rows at LOG
			my $logcount = countSnapshotLogModifiedRows($dbh, $masterschema, $mastername, $lastRefresh);
			#-- count the rows at MASTER
			if ("$snapshot->{'pbt_table'}" ne '') {
				$sql = <<SQL;
SELECT count(*) as total
FROM $masterschema.$snapshot->{'pbt_table'}
WHERE pbt\$ = $snapshot->{'snapid'}
SQL
			} else {
				$sql = <<SQL;
SELECT count(*) as total
FROM $masterschema.$mastername
SQL
			}
			my ($mastercount) = sqlLookup($dbh, $sql, ());
			notice ("Number of modified records: LOG=$logcount MASTER=$mastercount");
			#-- FAST only on fewer than 25% changes: if count(LOG) <= count(MASTER) / 4
			if (($kind eq 'F') || ($logcount le $mastercount / 4)) {
				$kind = 'F';
			} else {
				notice ("Huge number of modified records!");
				$kind = 'C';
			}
		} else {
			notice ('Snapshot Log does not exist.');
			$kind = 'C';
		}
		if (($snapshot->{'kind'} eq 'F') and ($kind ne 'F')) {
			#-- Can't do REFRESH FAST
			error ('Refresh FAST not supported. Did you set up a SNAPSHOT LOG correctly ?');
		}
	}
	return $kind;
}
