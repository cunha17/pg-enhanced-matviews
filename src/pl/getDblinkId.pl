#--
#-- SUB: getDblinkId
#-- Maps a DBLINK name to a DBLINK id
#--
sub getDblinkId {
	#-- Function parameters
	my ($dbh, $dblinkname) = @_;

	#-- Local variables
	my $sql;
	my $dblink;
	my $sth;

	if ("$dblinkname" eq '') {
		return undef;
	}

	#--Get DBLINK Id
	$sql = 'SELECT dblinkid FROM %BASE_SCHEMA%.pg_dblinks WHERE dblinkname=?';
	$sth = $dbh->prepare($sql);
	$sth->execute(($dblinkname));

	#-- Fetch the dblink info
	$dblink = $sth->fetchrow_hashref;
	return $dblink->{'dblinkid'};
}
