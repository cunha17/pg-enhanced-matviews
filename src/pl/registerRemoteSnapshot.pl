#--
##-- SUB: registerRemoteSnapshot
##-- Register the remote snapshot at the source's catalog
##--
#
sub registerRemoteSnapshot {
	#-- Function parameters
	my ($dbh_local, $schemaname, $snapshotname, $dblinkname) = @_;

	#-- Local variables
	my $attr_href;
	my $dbh_remote;
	my $masterschema;
	my $mastername;

	my $snapshot = getSnapshot($dbh_local, $schemaname, $snapshotname);
	my $dblink = getDblinkById($dbh_local, $snapshot->{'dblinkid'});

	if ($dblink) {
		#--create the remote database connection
		$attr_href = eval($dblink->{'attributes'});
		$dbh_remote = dbiGetConnection(
			$dblink->{'datasource'}
			, $dblink->{'username'}
			, $dblink->{'password'}
			, $attr_href
			);
	}

	$dbh_remote->{LongReadLen} = 64 * 1024; #--LOB <= 64Kb

	if ($snapshot->{'kind'} ne 'C') {
		my ($masterschema, $mastername) = retrieveMasterForSnapshot($dbh_remote, $snapshot);
	     call_driver_function($dbh_remote, 'snapshot_do', 'REGISTER', $masterschema, $mastername, $snapshot->{'snapid'});
	}
}
