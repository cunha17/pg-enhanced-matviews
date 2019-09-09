#--
#-- SUB: countSnapshotLogModifiedRows
#-- Returns the number of modified rows on the snapshot log
#--
sub countSnapshotLogModifiedRows {
	#-- Function parameters
	my ($dbh, $masterschema, $mastername, $lastRefresh) = @_;
	return call_driver_function($dbh, 'count_log_modified_rows', undef, $masterschema, $mastername, $lastRefresh);
}
