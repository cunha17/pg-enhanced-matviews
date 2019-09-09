#--
#-- SUB: getUpdatedDeletedLogRecordsFilter
#-- Returns the filter for retrieving snapshot log's updated or deleted records
#--
sub getUpdatedDeletedLogRecordsFilter {
	my ($dbh, $lastRefresh) = @_;
	return call_driver_function($dbh, 'snapshotlog_ud_filter', undef, undef, undef, $lastRefresh);
}
