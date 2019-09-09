#--
#-- SUB: openCursor
#-- opens an Oracle cursor
#--
my $oracle_cursors=0;
sub oracle_openCursor {
	#-- Function parameters
	my ($dbh, $query) = @_;

	#-- Local variables
	my $sql;
	my $sth;
	my $cursor;

	++$oracle_cursors;
	$cursor = "cursor_$oracle_cursors";
	$sql = <<SQL;
BEGIN OPEN :$cursor FOR $query; END;
SQL
	$sth = $dbh->prepare($sql);
	if ($dbh->err) {
		return undef;
	}
	my $sth2;
	my $tipo;
	eval ("use DBD::Oracle qw(:ora_types);
		\$tipo = ORA_RSET;");
	$sth->bind_param_inout(":$cursor", \$sth2, 0, { ora_type => $tipo } );
	$sth->execute;
	return $sth2;
}

#--
#-- SUB: closeCursor
#-- closes the Oracle cursor
#--
sub oracle_closeCursor {
	#-- Function parameters
	my ($dbh, $cursor) = @_;
	$cursor->finish;
}

#--
#-- SUB: fetchCursor
#-- fetches rows from a Oracle cursor
#--
sub oracle_fetchCursor {
	#-- Function parameters
	my ($dbh, $cursor, $count) = @_;

	return $cursor;
}

