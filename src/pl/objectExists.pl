#--
#-- SUB: objectExists
#-- Returns whether an object exists or not
#--
sub objectExists {
	my ($dbh, $schemaname, $snapshotname) = @_;

	# local variables
	my $sql;
	my $sth;
	my $row;

	$sql = <<SQL;
SELECT count(*) as total
FROM pg_catalog.pg_class c
        LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname=? AND c.relname = ?
SQL
	$sth = $dbh->prepare($sql);
	$sth->execute(($schemaname, $snapshotname));
	$row = $sth->fetchrow_hashref;
	return ($row->{total} ne 0);
}
