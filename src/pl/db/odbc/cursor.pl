#--
#-- SUB: openCursor
#-- try to open a native cursor, if it can't then opens an ODBC cursor
#--
sub odbc_openCursor {
    #-- Function parameters
    my ($dbh, $query) = @_;
    my $connStr = $dbh->{Name};
    my $driver = _getNativeDriverFromConnectionString($connStr);
    my %supported = (
        'pg' => \&pg_openCursor,
        'oracle' => \&oracle_openCursor,
        'sybase' => \&sybase_openCursor,
        'freetds' => \&freetds_openCursor,
    );

    if (defined $supported{$driver}) {
        return $supported{$driver}->($dbh, $query);
    } else {
        notice ("ODBC native driver '$driver' not found. Proceeding with generic ODBC support.");
        #-- Generic ODBC
        return _odbc_openCursor($dbh, $query);
    }
}

#--
#-- SUB: closeCursor
#-- closes an ODBC cursor
#--
sub odbc_closeCursor {
    #-- Function parameters
    my ($dbh, $cursor) = @_;
    my $connStr = $dbh->{Name};
    my $driver = _getNativeDriverFromConnectionString($connStr);

    my %supported = (
        'pg' => \&pg_closeCursor,
        'oracle' => \&oracle_closeCursor,
        'sybase' => \&odbc_closeCursor,
        'freetds' => \&freetds_closeCursor,
    );

    if (defined $supported{$driver}) {
        return $supported{$driver}->($dbh, $cursor);
    } else {
        notice ("ODBC native driver '$driver' not found. Proceeding with generic ODBC support.");
        #-- Generic ODBC
        return _odbc_closeCursor($dbh, $cursor);
    }
}

#--
#-- SUB: fetchCursor
#-- fetches rows from an ODBC cursor
#--
sub odbc_fetchCursor {
    #-- Function parameters
    my ($dbh, $cursor, $count) = @_;
    my $connStr = $dbh->{Name};
    my $driver = _getNativeDriverFromConnectionString($connStr);
    my %supported = (
        'pg' => \&pg_fetchCursor,
        'oracle' => \&oracle_fetchCursor,
        'sybase' => \&sybase_fetchCursor,
        'freetds' => \&freetds_fetchCursor,
    );

    if (defined $supported{$driver}) {
        return $supported{$driver}->($dbh, $cursor, $count);
    } else {
        notice ("ODBC native driver '$driver' not found. Proceeding with generic ODBC support.");
        #-- Generic ODBC
        return _odbc_fetchCursor($dbh, $cursor, $count);
    }
}

#--
#-- SUB: _getNativeDriverFromConnectionString
#-- Retrieves the native driver for a DSN (or connection string)
#--
sub _getNativeDriverFromConnectionString {
    my ($connStr) = @_;
    my $driver;
    if ($connStr =~ /[:;,=]/) {
        $connStr =~ /driver=([^:;,]+)/;
        $driver = lc($1);
    } else {
        my $dsn = $connStr;
        $driver = eval('
            use Config::IniFiles;
            my $cfg = new Config::IniFiles(-nocase => 1, -file => "/etc/odbc.ini");
            return lc($cfg->val($dsn, "driver"))
        ');
    }
    return $driver;
}

#--
#-- SUB: openCursor
#-- opens an ODBC cursor
#--
my $odbc_cursors=0;
sub _odbc_openCursor {
    #-- Function parameters
    my ($dbh, $query) = @_;

    #-- Local variables
    my $sql;
    my $sth;
    my $cursor;

    ++$pg_cursors;
    $cursor = "cursor_$pg_cursors";

    $sth = $dbh->prepare($query);
    if ($dbh->err) {
        return undef;
    }
    $sth->execute();
    return $sth;
}

#--
#-- SUB: closeCursor
#-- closes an ODBC cursor
#--
sub _odbc_closeCursor {
    #-- Function parameters
    my ($dbh, $cursor) = @_;

    #-- Local variables

    $cursor->finish();
}

#--
#-- SUB: fetchCursor
#-- fetches rows from an ODBC cursor
#--
sub _odbc_fetchCursor {
    #-- Function parameters
    my ($dbh, $cursor, $count) = @_;

    return $cursor;
}
