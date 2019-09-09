#--
#-- SUB: getSnapshotLogName
#-- Returns the snapshot log's table name
#--
sub getSnapshotLogName {
	my ($dbh, $masterschema, $mastername) = @_;
	return call_driver_function($dbh, 'snapshotlog_name', undef, $masterschema, $mastername, undef);
}

