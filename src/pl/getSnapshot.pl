#--
#-- SUB: getSnapshot
#-- Returns the named SNAPSHOT
#--
sub getSnapshot {
	#-- Function parameters
	my ($dbh, $schemaname, $snapshotname) = @_;

	#-- Local variables
	my $sql;
	my $sth;

	#-- Get snapshot info
	$sql = 'SELECT * FROM %BASE_SCHEMA%.pg_snapshots WHERE schemaname=? AND snapshotname=?';
	$sth = $dbh->prepare($sql);
	$sth->execute(($schemaname, $snapshotname));
	return $sth->fetchrow_hashref;
}
