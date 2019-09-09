#--
#-- SUB: openCursor
#-- opens a driver specific cursor
#--
sub openCursor {
	#-- Function parameters
	my ($dbh, $query) = @_;
	my $driver = lc($dbh->{Driver}->{Name});
	return _openCursor($dbh, $query, $driver);
}

#--
#-- SUB: closeCursor
#-- closes a driver specific cursor
#--
sub closeCursor {
	#-- Function parameters
	my ($dbh, $cursor) = @_;
	my $driver = lc($dbh->{Driver}->{Name});
	return _closeCursor($dbh, $cursor, $driver);
}

#--
#-- SUB: fetchCursor
#-- fetches rows from a driver specific cursor
#--
sub fetchCursor {
	#-- Function parameters
	my ($dbh, $cursor, $count) = @_;
	my $driver = lc($dbh->{Driver}->{Name});
	return _fetchCursor($dbh, $cursor, $count, $driver);
}

#--
#-- SUB: _openCursor
#-- Opens a driver-specified cursor
#--
sub _openCursor {
	my ($dbh, $query, $driver) = @_;
	my %supported = (
        	'pg' => \&pg_openCursor,
        	'oracle' => \&oracle_openCursor,
		'odbc' => \&odbc_openCursor,
		'sybase' => \&sybase_openCursor,
		'freetds' => \&freetds_openCursor,
		'mysql' => \&my_openCursor,
	);

	if (defined $supported{$driver}) {
        	return $supported{$driver}->($dbh, $query);
    	} else {
		error ("Driver not supported: $driver");
    	}
}

#--
#-- SUB: _openCursor
#-- Closes a driver-specified cursor
#--
sub _closeCursor {
	my ($dbh, $cursor, $driver) = @_;
	my %supported = (
        	'pg' => \&pg_closeCursor,
        	'oracle' => \&oracle_closeCursor,
		'odbc' => \&odbc_closeCursor,
		'sybase' => \&sybase_closeCursor,
		'freetds' => \&freetds_closeCursor,
		'mysql' => \&my_closeCursor,
	);

	if (defined $supported{$driver}) {
        	return $supported{$driver}->($dbh, $cursor);
    	} else {
		error ("Driver not supported: $driver");
    	}
}

#--
#-- SUB: _fetchCursor
#-- Fetches data from a driver-specified cursor
#--
sub _fetchCursor {
	my ($dbh, $cursor, $count, $driver) = @_;
	my %supported = (
        	'pg' => \&pg_fetchCursor,
        	'oracle' => \&oracle_fetchCursor,
		'odbc' => \&odbc_fetchCursor,
		'sybase' => \&sybase_fetchCursor,
		'freetds' => \&freetds_fetchCursor,
		'mysql' => \&my_fetchCursor,
	);

	if (defined $supported{$driver}) {
        	return $supported{$driver}->($dbh, $cursor, $count);
    	} else {
		error ("Driver not supported: $driver");
    	}
}
