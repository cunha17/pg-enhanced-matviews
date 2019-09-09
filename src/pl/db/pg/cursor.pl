#--
#-- SUB: openCursor
#-- opens a PostgreSQL cursor
#--
my $pg_cursors=0;
sub pg_openCursor {
	#-- Function parameters
	my ($dbh, $query) = @_;

	#-- Local variables
	my $sql;
	my $sth;
	my $cursor;

	++$pg_cursors;
	$cursor = "cursor_$pg_cursors";
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
#-- closes a PostgreSQL cursor
#--
sub pg_closeCursor {
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
#-- fetches rows from a PostgreSQL cursor
#--
sub pg_fetchCursor {
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
