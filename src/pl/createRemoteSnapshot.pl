#--
#-- SUB: createRemoteSnapshot
#-- Creates a snapshot based on a remote database query
#--
sub createRemoteSnapshot {
	#-- Function parameters
	my ($dbh, $schemaname, $snapshotname, $query, $dblinkname, $pbt) = @_;

	#-- Local variables
	my $dbh_remote;
	my $sql;
	my $sth;
	my $dblink;
	my $attr_href;

	#--Test if the DBLINK entry exists
	$sql = 'SELECT * FROM %BASE_SCHEMA%.pg_dblinks WHERE dblinkname=?';
	$sth = $dbh->prepare($sql);
	$sth->execute(($dblinkname));
	if ($sth->err) {
		error ("Table '%BASE_SCHEMA%.pg_dblinks' does not exist!");
		return FALSE;
	}

	#-- Fetch the dblink info
	$dblink = $sth->fetchrow_hashref;
	if (! $dblink->{'dblinkname'}) {
		error ("DBLink '$dblinkname' does not exist!");
		return FALSE;
	}
	$sth->finish;

	#-- Convert the attributes to a hashtable
	$attr_href = eval($dblink->{'attributes'});

	#-- Make the remote database connection
	$dbh_remote = dbiGetConnection(
		$dblink->{'datasource'}
		, $dblink->{'username'}
		, $dblink->{'password'}
		, $attr_href
		);

	#-- holds each column definition of the new table
	my @cols;

	#-- retrieve the structure of the snapshot query (empty query)
	$sql = getQueryWithNoRecords($dbh_remote, $query);
	$sth = $dbh_remote->prepare($sql);
	$sth->execute;

	if ($pbt eq '') {
		#-- Loop through all columns and retrieves the name and type of each one
		#-- Also maps the SQL Perl types to PostgreSQL ones
		#-- Place this info on @cols
		for ( my $i = 0 ; $i < $sth->{NUM_OF_FIELDS} ; $i++ ) {
			my $line = $sth->{NAME}->[$i];
			my $datatype = getUnifiedSqlType($sth, $i);
			my $precision = $sth->{PRECISION}->[$i];
			my $scale = $sth->{SCALE}->[$i];
			my $isnullable = $sth->{NULLABLE}->[$i];
			my $nullable = '';
			if (! $isnullable) {
				$nullable = 'NOT NULL';
			}

			notice ("Parsing structure COLUMN=$line TYPE=$datatype PRECISION=$precision SCALE=$scale NULL=$isnullable");
			if ( $datatype == -5 ) {
				$line .= " INT8 $nullable";
			} elsif ( $datatype == DBI::SQL_INTEGER ) {
				$line .= " INTEGER $nullable";
			} elsif ( $datatype == DBI::SQL_SMALLINT ) {
				$line .= " SMALLINT $nullable";
			} elsif ( $datatype == DBI::SQL_NUMERIC ) {
				$line .= " NUMERIC($precision, $scale) $nullable";
			} elsif ( $datatype == DBI::SQL_FLOAT ) {
				$line .= " FLOAT4 $nullable";
			} elsif ( $datatype == DBI::SQL_DOUBLE ) {
				$line .= " FLOAT8 $nullable";
			} elsif ( $datatype == DBI::SQL_BOOLEAN ) {
				$line .= " BOOLEAN $nullable";
			} elsif ( $datatype == DBI::SQL_CHAR ) {
				if ( $precision eq undef ) {
					$line .= " CHAR $nullable";
				} else {
					$line .= " CHAR($precision) $nullable";
				}
			} elsif ( $datatype == DBI::SQL_VARCHAR ) {
				if ( $precision eq undef ) {
					$line .= " VARCHAR $nullable";
				} else {
					$line .= " VARCHAR($precision) $nullable";
				}
			} elsif ( $datatype == DBI::SQL_CLOB ) {
				$line .= " TEXT $nullable";
			} elsif ( $datatype == DBI::SQL_DATE ) {
				$line .= " DATE $nullable";
			} elsif ( $datatype == DBI::SQL_TIME ) {
				$line .= " TIME $nullable";
			} elsif ( $datatype == DBI::SQL_DATETIME || $datatype == DBI::SQL_TIMESTAMP ) {
				$line .= " TIMESTAMP $nullable";
			} elsif ( $datatype == DBI::SQL_INTERVAL ) {
				$line .= " INTERVAL $nullable";
			} elsif ( $datatype == DBI::SQL_BLOB ) {
				$line .= " BYTEA $nullable";
			} else { #--UNKNOWN
				warning ("Unknown type '$datatype' mapped to 'TEXT'!");
				$line .= " TEXT $nullable";
			}
			push @cols, $line;
		}
		$sth->finish;
	
		#-- Makes the CREATE TABLE SQL statement
		$sql = <<SQL;
CREATE TABLE $schemaname.$snapshotname (
  @{[ join("\n, ", @cols) ]}
)
SQL
		notice ($sql);
		$sth = spi_exec_query($sql);
		if ($sth->{status} eq 'SPI_OK_UTILITY') {
			notice ("Snapshot placeholder created");
		} else {
			error ("Could not create snapshot placeholder: $sql [$sth->{status}]");
		}
	} else {
		my $snapshotname = $pbt;
		my $sth1;
		my $columns;

		for ( my $i = 0 ; $i < $sth->{NUM_OF_FIELDS} ; $i++ ) {
			push @cols, $sth->{NAME}->[$i];
		}
		$columns = join(',', @cols);
		
		#-- execute a query WHERE 1=0 on the existant table
		$sql = <<SQL;
SELECT $columns
FROM $schemaname.$snapshotname
WHERE 1=0
SQL
		$sth1 = $dbh->prepare($sql);
		$sth1->execute;
		if ($sth1->err) {
			error ("Could not execute query: $sql [$sth1->{status}]");
		}
		validateModifyPrebuiltTable($dbh, $schemaname, $snapshotname, $sth, $sth1);
		$sth->finish;
		$sth1->finish;
		$dbh->commit;
	}
	notice ("Disconnecting from remote database...");
	#-- Disconnects from the remote database
	$dbh_remote->disconnect;
}
