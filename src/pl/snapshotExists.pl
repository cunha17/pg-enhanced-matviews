#--
#-- SUB: snapshotExists
#-- Returns whether a snapshot exists or not
#--
sub snapshotExists {
	#-- Function parameters
	my ($dbh, $schemaname, $snapshotname) = @_;

	# local variables
	my $sql;
	my $sth;
	my $row;

	$sql = <<SQL;
SELECT count(*) as total
FROM %BASE_SCHEMA%.pg_snapshots
WHERE schemaname=?
	and snapshotname=?
SQL
	$sth = $dbh->prepare($sql);
	$sth->execute(($schemaname, $snapshotname));
	if ($sth->err) {
		error ("Could not find %BASE_SCHEMA%.pg_snapshots !!!");
	}
	$row = $sth->fetchrow_hashref;
	return ($row->{'total'} ne 0);
}
