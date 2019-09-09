#--
#-- SUB: updateLastSnapshotLogRefresh
#-- Updates the SNAPSHOT LOG catalog with the SNAPSHOT last refresh
#--
sub updateLastSnapshotLogRefresh {
	#-- Function parameters
	my ($dbh, $masterschema, $mastername, $refreshTime, $snapid) = @_;
	
	call_driver_function($dbh, 'snapshot_do', 'REFRESHED', $masterschema, $mastername, $refreshTime.'|'.$snapid);
}
