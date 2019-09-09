#--
#-- SUB: getSnapshotLogColumns
#-- Returns the snapshot log's filter/pk/oid columns
#--
sub getSnapshotLogColumns {
	my ($dbh, $masterschema, $mastername) = @_;
	my $result = call_driver_function($dbh, 'snapshotlog_columns', undef, $masterschema, $mastername, undef);
	return $result;
}

