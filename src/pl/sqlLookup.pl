#--
#-- SUB: sqlLookup
#-- Returns a one row result from a SQL query
#--
sub sqlLookup {
        my ($dbh, $sql, @params) = @_;
	return sqlLookup2 ($dbh, $sql, \@params, TRUE);
}
sub sqlLookupSoft {
	my ($dbh, $sql, @params) = @_;
	return sqlLookup2 ($dbh, $sql, \@params, FALSE);
}

sub sqlLookup2 {
	my ($dbh, $sql, $params, $errorsAreFatal) = @_;
	my $sth;
	my @row;

	notice ("Lookup at SQL:$sql with ".((@$params ne 0) ? join(',', @$params) : '<none>'));

	eval {
                my $handler = $SIG{'__WARN__'};
                $SIG{'__WARN__'} = sub { };
                $sth = $dbh->prepare($sql);

                if (@$params ne 0) {
                    $sth->execute(@$params);
                } else {
                    $sth->execute();
                }

                $SIG{'__WARN__'} = $handler;
        };

	if ($sth->err) {
		if ($errorsAreFatal) {
			error ("Fatal error! SQL=$sql ERROR=".$sth->errstr);
		}
	}
	my @row = $sth->fetchrow_array;
	$sth->finish;
	return @row;
}
