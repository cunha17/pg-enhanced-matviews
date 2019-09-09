#--
#-- SUB: dblinkExists
#-- Returns whether a DBLINK exists or not
#--
sub dblinkExists {
	my ($dbh, $dblinkname) = @_;

	# local variables
	my $sql;
	my $sth;
	my $row;

	$sql = <<SQL;
SELECT count(*) as total
FROM %BASE_SCHEMA%.pg_dblinks
WHERE dblinkname=?
SQL
	$sth = $dbh->prepare($sql);
	if ($dbh->err) {
		error ($dbh->errstr);
	}
	$sth->execute(($dblinkname));
	if ($sth->err) {
		error ("Could not find %BASE_SCHEMA%.pg_dblink! ");
	}
	$row = $sth->fetchrow_hashref;
	return ($row->{'total'} ne 0);
}
