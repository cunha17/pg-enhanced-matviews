#--
#-- SUB: updateNullSnaptimeRows
#-- Updates the SNAPSHOT LOG rows that were not viewed by anyone (snaptime column is NULL)
#--
sub updateNullSnaptimeRows {
	#-- Function parameters
	my ($dbh, $masterschema, $mastername, $refreshTime) = @_;

	call_driver_function($dbh, 'snapshot_do', 'UPDATE_NULL', $masterschema, $mastername, $refreshTime);
}
