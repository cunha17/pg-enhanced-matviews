#--
#-- SUB: createLocalSnapshot
#-- Creates a snapshot based on a local database query
#--
sub createLocalSnapshot {
	#-- Function parameters
	my ($dbh, $schemaname, $snapshotname, $query, $pbt) = @_;

	#-- Local variables
	my $sql;
	my $sth;

	if ($pbt eq '') {
		#-- Creates an empty table based on the query
		$sql = <<SQL;
CREATE TABLE $schemaname.$snapshotname AS
	SELECT query.* 
	FROM ($query) query 
	WHERE 1=0
SQL
		$sth = spi_exec_query($sql);
		if ($sth->{status} eq 'SPI_OK_SELINTO') {
			notice ("Snapshot placeholder created");
		} else {
			error ("Could not create snapshot placeholder: $sql [".$sth->status."]");
		}
	} else {
		my $snapshotname = $pbt;

		#-- execute the query WHERE 1=0
		$sql = <<SQL;
SELECT query.* 
FROM ($query) query 
WHERE 1=0
SQL
		$sth = $dbh->prepare($sql);
		$sth->execute;
		if ($sth->err) {
			error ("Could not execute query: $sql [$sth->{errstr}]");
		}

		my $sth1;
		my $columns;
		my @cols = ();

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
			error ("Could not execute query: $sql [$sth1->{errstr}]");
		}
		validateModifyPrebuiltTable($dbh, $schemaname, $snapshotname, $sth, $sth1);
		$sth1->finish();
		$dbh->commit;
		$sth->finish();
	}
}
