#--
#-- SUB: map2PgType
#-- Maps a DBI type to a PostgreSQL native type or a SQL type supported by PostgreSQL
#--
sub map2PgType {
	use DBI qw(:sql_types);
	use DBD::Pg qw(:pg_types);
	my ($dbiType) = @_;

	my $pgType;

	if ( $dbiType eq undef) {
		return undef;
	}

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

#--PG_BOOL PG_BYTEA PG_CHAR PG_INT8 PG_INT2 PG_INT4 PG_TEXT PG_OID
#--PG_FLOAT4 PG_FLOAT8 PG_ABSTIME PG_RELTIME PG_TINTERVAL PG_BPCHAR
#--PG_VARCHAR PG_DATE PG_TIME PG_TIMESPAN PG_TIMESTAMP
	if ( $dbiType == SQL_INTEGER ) {
		$pgType = { pg_type => PG_INT4 };
	} elsif ( $dbiType == SQL_SMALLINT ) {
		$pgType = { pg_type => PG_INT2 };
        } elsif ( $dbiType == -5 ) { #--SQL_BIGINT
		$pgType = { pg_type => PG_INT8 };
	} elsif ( $dbiType == SQL_FLOAT ) {
		$pgType = { pg_type => PG_FLOAT4 };
	} elsif ( $dbiType == SQL_DOUBLE ) {
		$pgType = { pg_type => PG_FLOAT8 };
	} elsif ( $dbiType == SQL_TIMESTAMP ) {
		$pgType = { pg_type => PG_TIMESTAMP };
	} elsif ( $dbiType == SQL_NUMERIC ) {
		$pgType = SQL_NUMERIC;
	} elsif ( $dbiType == SQL_BOOLEAN ) {
		$pgType = SQL_BOOLEAN;
	} elsif ( $dbiType == SQL_CHAR ) {
		$pgType = SQL_CHAR;
	} elsif ( $dbiType == SQL_VARCHAR ) {
		$pgType = { pg_type => PG_VARCHAR };
	} elsif ( $dbiType == SQL_CLOB ) {
		$pgType = { pg_type => PG_VARCHAR };
	} elsif ( $dbiType == SQL_DATETIME ) {
		$pgType = { pg_type => PG_TIMESTAMP };
	} elsif ( $dbiType == SQL_DATE ) {
		$pgType = { pg_type => PG_DATE };
	} elsif ( $dbiType == SQL_TIME ) {
		$pgType = { pg_type => PG_TIME };
	} elsif ( $dbiType == SQL_INTERVAL ) {
		$pgType = SQL_INTERVAL;
	} elsif ( $dbiType == SQL_BLOB ) {
		$pgType = { pg_type => PG_BYTEA };
	} else {
		$pgType = { pg_type => PG_TEXT };
	}
	return $pgType;
}
