#--
#-- SUB: openCursor
#-- opens a Sybase cursor
#--
my $sybase_cursors=0;
sub sybase_openCursor {
	#-- Function parameters
	my ($dbh, $query) = @_;

	#-- Local variables
	my $sql;
	my $sth;
	my $cursor;

	++$sybase_cursors;
	$cursor = "cursor_$sybase_cursors";
	$sql = <<SQL;
DECLARE $cursor CURSOR FOR $query
SQL
	$sth = $dbh->prepare($sql);
	if ($dbh->err) {
		return undef;
	}
	$sth->execute();
	$sth->finish;
	return $cursor;
}

#--
#-- SUB: closeCursor
#-- closes a Sybase cursor
#--
sub sybase_closeCursor {
	#-- Function parameters
	my ($dbh, $cursor) = @_;

	#-- Local variables
	my $sql;
	my $sth;

	$sql = <<SQL;
CLOSE $cursor
SQL
	$sth = $dbh->prepare($sql);
	if ($dbh->err) {
		error ("Error closing cursor '$cursor'");
	}
	$sth->execute();
	$sth->finish;
}

#--
#-- SUB: fetchCursor
#-- fetches rows from a Sybase cursor
#--
sub sybase_fetchCursor {
	#-- Function parameters
	my ($dbh, $cursor, $count) = @_;

	#-- Local variables
	my $sql;
	my $sth;

	$sql = <<SQL;
FETCH $count FROM $cursor
SQL
	$sth = $dbh->prepare($sql);
	if ($dbh->err) {
		return undef;
	}
        $sth->execute();
	return $sth;
}
