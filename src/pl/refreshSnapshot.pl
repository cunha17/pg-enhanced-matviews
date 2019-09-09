#--
#-- SUB: refreshSnapshot
#-- Refresh a SNAPSHOT with a database query result
#--

#-- Perl trim function to remove whitespace from the start and end of the string
sub trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

#-- Returns the current date/time
sub getNow {
	my @timeData = localtime();
	my $now = sprintf('%d-%02d-%02d %02d:%02d:%02d',
		@timeData[5]+1900, @timeData[4], @timeData[3],
		@timeData[2], @timeData[1], @timeData[0]);
	return $now;
}

sub refreshSnapshot {
	#-- Function parameters
	my ($dbh_local, $snapshot, $dblink) = @_;

	#-- Local variables
	my $recs = 0;
	my $attr_href;
	my $dbh_remote;
	my $masterschema;
	my $mastername;
	my $kind;
	my $lastRefresh;
	my $refreshTime;

	if ($dblink) {
		#--create the remote database connection
		$attr_href = eval($dblink->{'attributes'});
		$dbh_remote = dbiGetConnection(
			$dblink->{'datasource'}
			, $dblink->{'username'}
			, $dblink->{'password'}
			, $attr_href
			);
	} else {
		$dbh_remote = DBI->connect(getCurrentDatabaseConnectionString(), '%SUPERUSER%', undef, {AutoCommit => 0});
	}
	$dbh_remote->{LongReadLen} = 64 * 1024; #--LOB <= 64Kb

	if ($snapshot->{'kind'} eq 'C') {
		$masterschema = undef;
		$mastername = undef;
		$kind = 'C';
		$lastRefresh = undef;
	} else {
		($masterschema, $mastername, $kind, $lastRefresh) = prepareForRefresh($dbh_remote, $snapshot);
	}
	$refreshTime = getNow();

	if ($kind eq 'C') {
		#-- Refresh Complete
		$recs = performCompleteRefresh($dbh_local, $dbh_remote, $snapshot);
	} else {
		#-- Refresh FAST
		$recs = performFastRefresh($dbh_local, $dbh_remote, $snapshot, $masterschema, $mastername, $lastRefresh);
	}
	finalizeRefresh($dbh_remote, $masterschema, $mastername, $snapshot->{'snapid'}, $refreshTime);
	if (snapshotLogExists($dbh_remote, $masterschema, $mastername)) {
		notice ('Purging Log');
		purgeSnapshotLog($dbh_remote, $masterschema, $mastername);
	}
	if ($recs eq '0E0') {
		$recs = 0;
	}
	$dbh_remote->disconnect;
	return $recs;
}
