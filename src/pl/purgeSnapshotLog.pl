#--
#-- SUB: purgeSnapshotLog
#-- Removes old SNAPSHOT LOG entries
#--
sub purgeSnapshotLog {
	#-- Function parameters
	my ($dbh, $masterschema, $mastername) = @_;

	call_driver_function($dbh, 'snapshot_do', 'PURGELOG', $masterschema, $mastername, undef);
}
