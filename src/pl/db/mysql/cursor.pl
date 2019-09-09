#--
#-- SUB: openCursor
#-- opens a MySQL cursor
#--
my $my_cursors=0;
sub my_openCursor {
	#-- Function parameters
	my ($dbh, $query) = @_;

	#-- Local variables
	my $sql;
	my $sth;
	my $cursor;

	++$my_cursors;
	$cursor = "cursor_$my_cursors";
	$sql = $query;
	$sth = $dbh->prepare($sql);
	if ($dbh->err) {
		return undef;
	}
	$sth->execute();
	return $sth;
}

#--
#-- SUB: closeCursor
#-- closes a MySQL cursor
#--
sub my_closeCursor {
	#-- Function parameters
	my ($dbh, $cursor) = @_;

	$cursor->finish();
}

#--
#-- SUB: fetchCursor
#-- fetches rows from a MySQL cursor
#--
sub my_fetchCursor {
	#-- Function parameters
	my ($dbh, $cursor, $count) = @_;

	return $cursor;
}
