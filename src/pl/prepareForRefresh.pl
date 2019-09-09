#--
#-- SUB: prepareForRefresh
#-- Prepares the local SNAPSHOT for the refresh process, removing old rows, old logs, etc.
#--
sub prepareForRefresh {
	#-- Function parameters
	my ($dbh, $snapshot) = @_;

	#-- Local variables
	my $kind = 'C';
	my $lastRefresh = undef;
	my $snapid = $snapshot->{'snapid'};
	my ($masterschema, $mastername) = retrieveMasterForSnapshot($dbh, $snapshot);
	if ($masterschema ne undef) {
		if (snapshotLogExists($dbh, $masterschema, $mastername)) { #-- has snapshot log
			$lastRefresh = getLastSnapshotLogRefresh($dbh, $masterschema, $mastername, $snapid);
			notice ("Last refresh on $lastRefresh");
			$kind = getRefreshMethod($dbh, $snapshot, $masterschema, $mastername, $lastRefresh);
		}
	}
	notice ("Refresh method=$kind");
	return ($masterschema, $mastername, $kind, $lastRefresh);
}

