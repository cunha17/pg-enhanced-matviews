#--
#-- SUB: finalizeRefresh
#-- Finalize the refresh process updating control fields.
#--
sub finalizeRefresh {
	#-- Function parameters
	my ($dbh, $masterschema, $mastername, $snapid, $refreshTime) = @_;

	#-- Local variables
	if ($masterschema ne undef) {
		if (snapshotLogExists($dbh, $masterschema, $mastername)) { #-- has snapshot log
			notice ("Setting refresh time to $refreshTime");
			updateLastSnapshotLogRefresh($dbh, $masterschema, $mastername, $refreshTime, $snapid);
			updateNullSnaptimeRows($dbh, $masterschema, $mastername, $refreshTime);
		}
	}
}

