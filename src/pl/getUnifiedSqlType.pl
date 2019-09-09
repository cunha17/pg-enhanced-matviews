#--
#-- SUB: getUnifiedSqlType
#-- Maps a set of SQL types into a single SQL type
#--
sub getUnifiedSqlType {
	my ($sth, $column_index) = @_;
	my $dbiType = $sth->{TYPE}->[$column_index];

	#--------------------------------
	#-- SQL datatype codes
	#-- SQL_GUID                         (-11)
	#-- SQL_WLONGVARCHAR                 (-10)
	#-- SQL_WVARCHAR                      (-9)
	#-- SQL_WCHAR                         (-8)
	#-- SQL_BIT                           (-7)
	#-- SQL_TINYINT                       (-6)
	#-- SQL_BIGINT                        (-5)
	#-- SQL_LONGVARBINARY                 (-4)
	#-- SQL_VARBINARY                     (-3)
	#-- SQL_BINARY                        (-2)
	#-- SQL_LONGVARCHAR                   (-1)
	#-- SQL_UNKNOWN_TYPE                    0
	#-- SQL_ALL_TYPES                       0
	#-- SQL_CHAR                            1
	#-- SQL_NUMERIC                         2
	#-- SQL_DECIMAL                         3
	#-- SQL_INTEGER                         4
	#-- SQL_SMALLINT                        5
	#-- SQL_FLOAT                           6
	#-- SQL_REAL                            7
	#-- SQL_DOUBLE                          8
	#-- SQL_DATETIME                        9
	#-- SQL_DATE                            9
	#-- SQL_INTERVAL                       10
	#-- SQL_TIME                           10
	#-- SQL_TIMESTAMP                      11
	#-- SQL_VARCHAR                        12
	#-- SQL_BOOLEAN                        16
	#-- SQL_UDT                            17
	#-- SQL_UDT_LOCATOR                    18
	#-- SQL_ROW                            19
	#-- SQL_REF                            20
	#-- SQL_BLOB                           30
	#-- SQL_BLOB_LOCATOR                   31
	#-- SQL_CLOB                           40
	#-- SQL_CLOB_LOCATOR                   41
	#-- SQL_ARRAY                          50
	#-- SQL_ARRAY_LOCATOR                  51
	#-- SQL_MULTISET                       55
	#-- SQL_MULTISET_LOCATOR               56
	#-- SQL_TYPE_DATE                      91
	#-- SQL_TYPE_TIME                      92
	#-- SQL_TYPE_TIMESTAMP                 93
	#-- SQL_TYPE_TIME_WITH_TIMEZONE        94
	#-- SQL_TYPE_TIMESTAMP_WITH_TIMEZONE   95
	#-- SQL_INTERVAL_YEAR                 101
	#-- SQL_INTERVAL_MONTH                102
	#-- SQL_INTERVAL_DAY                  103
	#-- SQL_INTERVAL_HOUR                 104
	#-- SQL_INTERVAL_MINUTE               105
	#-- SQL_INTERVAL_SECOND               106
	#-- SQL_INTERVAL_YEAR_TO_MONTH        107
	#-- SQL_INTERVAL_DAY_TO_HOUR          108
	#-- SQL_INTERVAL_DAY_TO_MINUTE        109
	#-- SQL_INTERVAL_DAY_TO_SECOND        110
	#-- SQL_INTERVAL_HOUR_TO_MINUTE       111
	#-- SQL_INTERVAL_HOUR_TO_SECOND       112
	#-- SQL_INTERVAL_MINUTE_TO_SECOND     113
	#--------------------------------

	#-- SQL_GEOMETRY                      500
	#-- SQL_GEOGRAPHY                     501

#--PG_BOOL PG_BYTEA PG_CHAR PG_INT8 PG_INT2 PG_INT4 PG_TEXT PG_OID
#--PG_FLOAT4 PG_FLOAT8 PG_ABSTIME PG_RELTIME PG_TINTERVAL PG_BPCHAR
#--PG_VARCHAR PG_DATE PG_TIME PG_TIMESPAN PG_TIMESTAMP
	notice ("DBI Type $dbiType"); 
	if (($dbiType == DBI::SQL_INTEGER)) {
		return DBI::SQL_INTEGER;
	} elsif (($dbiType == DBI::SQL_SMALLINT)
		|| ($dbiType == DBI::SQL_TINYINT )) {
		return DBI::SQL_SMALLINT;
	} elsif (($dbiType == DBI::SQL_TYPE_TIME_WITH_TIMEZONE)
		|| ($dbiType == DBI::SQL_TYPE_TIMESTAMP_WITH_TIMEZONE)
		|| ( $dbiType == DBI::SQL_TIMESTAMP )
		|| ( $dbiType == DBI::SQL_TYPE_TIMESTAMP ) ) { #--TIMESTAMP
		return DBI::SQL_TIMESTAMP;
	} elsif ( $dbiType == -5 ) { #--SQL_BIGINT
		return -5;
	} elsif (($dbiType == DBI::SQL_NUMERIC )
		|| ($dbiType == DBI::SQL_DECIMAL )) {#--NUMERIC
		return DBI::SQL_NUMERIC;
	} elsif (($dbiType == DBI::SQL_FLOAT )
		|| ($dbiType == DBI::SQL_REAL )) {#--FLOAT
		return DBI::SQL_FLOAT;
	} elsif (($dbiType == DBI::SQL_DOUBLE )) {#--DOUBLE
		return DBI::SQL_DOUBLE;
	} elsif ( ( $dbiType == DBI::SQL_BOOLEAN )
		|| ( $dbiType == DBI::SQL_BIT ) ) { #--BOOLEAN
		return DBI::SQL_BOOLEAN;
	} elsif ( ($dbiType == DBI::SQL_CHAR )
		|| ( $dbiType == DBI::SQL_WCHAR ) ) { #--CHAR
		return DBI::SQL_CHAR;
	} elsif ( ($dbiType == DBI::SQL_VARCHAR )
		|| ( $dbiType == DBI::SQL_WVARCHAR )) { #--VARCHAR
		return DBI::SQL_VARCHAR;
	} elsif ( ( $dbiType == DBI::SQL_LONGVARCHAR )
		|| ( $dbiType == DBI::SQL_WLONGVARCHAR )
		|| ( $dbiType == DBI::SQL_CLOB ) ) { #--CLOB
		return DBI::SQL_CLOB;
	} elsif ( $dbiType == DBI::SQL_DATETIME ) {
		return DBI::SQL_DATETIME;
	} elsif ( ( $dbiType == DBI::SQL_DATE )
		|| ( $dbiType == DBI::SQL_TYPE_DATE ) ) { #--DATE
		return DBI::SQL_DATE;
	} elsif ( ( $dbiType == DBI::SQL_TIME )
		|| ( $dbiType == DBI::SQL_TYPE_TIME ) ) { #--TIME
		return DBI::SQL_TIME;
	} elsif ( ( $dbiType == DBI::SQL_INTERVAL )
		|| ( $dbiType == DBI::SQL_INTERVAL_YEAR )
		|| ( $dbiType == DBI::SQL_INTERVAL_MONTH )
		|| ( $dbiType == DBI::SQL_INTERVAL_DAY )
		|| ( $dbiType == DBI::SQL_INTERVAL_HOUR )
		|| ( $dbiType == DBI::SQL_INTERVAL_MINUTE )
		|| ( $dbiType == DBI::SQL_INTERVAL_SECOND )
		|| ( $dbiType == DBI::SQL_INTERVAL_YEAR_TO_MONTH )
		|| ( $dbiType == DBI::SQL_INTERVAL_DAY_TO_HOUR )
		|| ( $dbiType == DBI::SQL_INTERVAL_DAY_TO_MINUTE )
		|| ( $dbiType == DBI::SQL_INTERVAL_DAY_TO_SECOND )
		|| ( $dbiType == DBI::SQL_INTERVAL_HOUR_TO_MINUTE )
		|| ( $dbiType == DBI::SQL_INTERVAL_HOUR_TO_SECOND )
		|| ( $dbiType == DBI::SQL_INTERVAL_MINUTE_TO_SECOND ) ) { #--INTERVAL
		return DBI::SQL_INTERVAL;
	} elsif ( ( $dbiType == DBI::SQL_BINARY )
		|| ( $dbiType == DBI::SQL_VARBINARY )
		|| ( $dbiType == DBI::SQL_LONGVARBINARY )
		|| ( $dbiType == DBI::SQL_BLOB ) ) { #--BLOB
		return $dbiType == DBI::SQL_BLOB;
	} else {
		if ( $dbiType == 0 ) {

			return undef;

			#-- Unknown
			my $dbh = $sth->{Database};
			my $sql;
			my $sth1;
			my $type;
			my @row;
			my $column = $sth->{NAME}->[$column_index];
			my $sql_statement = $sth->{Statement};

			$sql = <<SQL;
SELECT pg_typeof($column) 
FROM ($sql_statement OR 1=1 LIMIT 1) s
SQL
			notice ("SQL statement=$sql");
			$sth = $dbh->prepare($sql);
			if (! $sth->err) {
				$sth->execute();
			}
			@row = $sth->fetchrow_array;
			$type = @row[0];
			notice ("Row PG type name:".$type);
			if ( $type == 'geometry' ) {
				return 500;
			} elsif ( $type == 'geography' ) {
				return 501;
			}
		}
		return DBI::SQL_VARCHAR; #-- default: VARCHAR
	}
}
