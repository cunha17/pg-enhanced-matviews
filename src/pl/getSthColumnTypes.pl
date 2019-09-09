#--
#-- SUB: getSthColumnTypes
#-- Returns an array in which every index is the corresponding SQL data type for each column index of the STATEMENT parameter
#--
sub getSthColumnTypes {
	#-- Function parameters
	my ($sth) = @_;

	#-- Local variables
	my @types;

	for (my $i = 0; $i < $sth->{NUM_OF_FIELDS}; ++$i) {
		notice ("DBI TYPE=".$sth->{TYPE}->[$i]." PG_TYPE=".$sth->{pg_type}->[$i]);
		@types[$i] = map2PgType(getUnifiedSqlType($sth, $i));
	}
	return @types;
}
