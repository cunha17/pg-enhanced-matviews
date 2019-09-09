#--
#-- SUB: getLastSnapshotLogRefresh
#-- Returns the date/time of the snapshot's last refresh
#--
sub getLastSnapshotLogRefresh {
	#-- Function arguments
	my ($dbh, $masterschema, $mastername, $snapid) = @_;

	return 	call_driver_function($dbh, 'last_log_refresh', undef, $masterschema, $mastername, $snapid);
}
