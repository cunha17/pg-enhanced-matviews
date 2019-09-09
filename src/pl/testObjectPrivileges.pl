#--
#-- SUB: testObjectPrivileges
#-- Tests the passed privileges of the current user against the target databse object and returns a result array
#--
sub testObjectPrivileges {
	#-- Function parameters
	my ($schemaname,$snapshotname,@privileges) = @_;

	#-- Local variables
	my $sql;
	my $sth;
	my @result=();

	#-- Create the query
	$sql = 'SELECT ';
	for (my $i=0; $i < @privileges; ++$i) {
		my $privilege = @privileges[$i];
		$sql = "$sql has_table_privilege('$schemaname.$snapshotname', '$privilege') as has_$privilege,";
	}
	chop $sql;
	notice ($sql);
	$sth = spi_exec_query($sql);
	for (my $i=0; $i < @privileges; ++$i) {
		my $privilege = @privileges[$i];
		@result[$i] = $sth->{rows}[0]->{"has_${privilege}"} eq 't';
	}
	notice ('PRIVILEGES:('.join(',', @privileges).')=('.join(',', @result).')');
	return @result;
}
