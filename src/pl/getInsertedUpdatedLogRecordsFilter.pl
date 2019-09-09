#--
#-- SUB: getInsertedUpdatedLogRecordsFilter
#-- Returns the filter for retrieving snapshot log's inserted or updated records
#--
sub getInsertedUpdatedLogRecordsFilter {
	my ($dbh, $lastRefresh) = @_;
	return call_driver_function($dbh, 'snapshotlog_iu_filter', undef, undef, undef, $lastRefresh);
}
