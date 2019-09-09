#--
#-- SUB: getPgTypeName
#-- Returns the textual name of a PostgreSQL datatype
#--
sub getPgTypeName {
	use DBI qw(:sql_types);
	use DBD::Pg qw(:pg_types);
	my ($pgType) = @_;

	my $pgTypeName;

	if ( ref $pgType ) {
		$pgType = $pgType -> { pg_type };
	}
	if ( $pgType == PG_INT4 ) {
		$pgTypeName = 'int4';
	} elsif ( $pgType == PG_INT2 ) {
		$pgTypeName = 'int2';
        } elsif ( $pgType == PG_INT8 ) {
		$pgTypeName = 'int8';
	} elsif ( $pgType == PG_FLOAT4 ) {
		$pgTypeName = 'float4';
	} elsif ( $pgType == PG_FLOAT8 ) {
		$pgTypeName = 'float8';
	} elsif ( $pgType == PG_TIMESTAMP ) {
		$pgTypeName = 'timestamp';
	} elsif ( $pgType == SQL_NUMERIC ) {
		$pgTypeName = 'numeric';
	} elsif ( $pgType == SQL_BOOLEAN ) {
		$pgTypeName = 'boolean';
	} elsif ( $pgType == SQL_CHAR ) {
		$pgTypeName = 'char';
	} elsif ( $pgType == PG_VARCHAR ) {
		$pgTypeName = 'varchar';
	} elsif ( $pgType == PG_DATE ) {
		$pgTypeName = 'date';
	} elsif ( $pgType == PG_TIME ) {
		$pgTypeName = 'time';
	} elsif ( $pgType == SQL_INTERVAL ) {
		$pgTypeName = 'interval';
	} elsif ( $pgType == PG_BYTEA ) {
		$pgTypeName = 'bytea';
	} else {
		$pgTypeName = undef;
	}
	return $pgTypeName;
}
