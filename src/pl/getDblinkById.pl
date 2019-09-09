#--
#-- SUB: getDblinkById
#-- Returns a DBLINK by its ID
#--
sub getDblinkById {
	#-- Function parameters
	my ($dbh, $dblinkid) = @_;

	#-- Local variables
	my $sql;
	my $sth;

	#--get dblink info
	$sql = 'SELECT * FROM %BASE_SCHEMA%.pg_dblinks WHERE dblinkid=?';
	$sth = $dbh->prepare($sql);
	$sth->execute(($dblinkid));
	if ($sth->err) {
		error ("DBLINK '$dblinkid' does not exist!");
	}
	return $sth->fetchrow_hashref;
}
