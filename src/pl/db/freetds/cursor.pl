#--
#-- SUB: openCursor
#-- opens a FreeTDS cursor
#--
my $freetds_cursors=0;
sub freetds_openCursor {
	#-- Function parameters
	my ($dbh, $query) = @_;

	#-- Local variables
	my $sql;
	my $sth;
	my $cursor;

	++$freetds_cursors;
	$cursor = "cursor_$freetds_cursors";
	$sql = <<SQL;
DECLARE $cursor CURSOR FOR $query
SQL
	$sth = $dbh->prepare($sql);
	if ($dbh->err) {
		return undef;
	}
	$sth->execute();
	$sth->finish;
$sql = <<SQL;
OPEN $cursor
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
#-- closes a FreeTDS cursor
#--
sub freetds_closeCursor {
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
        $sql = <<SQL;
DEALLOCATE $cursor
SQL
        $sth = $dbh->prepare($sql);
        if ($dbh->err) {
                error("Error deallocating cursor '$cursor'");
        }
        $sth->execute();
        $sth->finish;

}

#--
#-- SUB: fetchCursor
#-- fetches rows from a FreeTDS cursor
#--
sub freetds_fetchCursor {
	#-- Function parameters
	my ($dbh, $cursor, $count) = @_;

	#-- Local variables
	my $sql;
	my $sth;

        #-- The TDS implementation of CURSORS s*cks: you can only fetch
        #-- one record at a time
	$sql = <<SQL;
FETCH NEXT FROM $cursor
SQL
	$sth = $dbh->prepare($sql);
	if ($dbh->err) {
		return undef;
	}
	$sth->execute;
	return $sth;
}
