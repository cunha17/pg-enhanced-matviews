#--
#-- SUB: spiGetCurrentDatabase
#-- Retrieves the current database name
#--
sub spiGetCurrentDatabase {
	my $sql = 'SELECT current_database() as dbname';
        my $sth = spi_exec_query($sql);
	if ($sth eq undef) {
		return undef;
	} else {
		return $sth->{rows}[0]->{"dbname"};
	}
}
