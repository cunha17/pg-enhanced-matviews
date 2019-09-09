#--
#-- SUB: createSnapshotLogTableIndexes
#-- Creates the INDEXES on the SNAPSHOT LOG table, for performance reasons only
#--
sub createSnapshotLogTableIndexes {
	my ($schemaname, $mastername, $log, $logKeyColumns) = @_;

	my $sth;
	my $sql;

	#-- Create the Snapshot's Log Table Indexes
	my $keys = join(',', keys %$logKeyColumns);
	$sql = <<SQL;
CREATE INDEX ${log}_ix1 on $schemaname.$log ($keys);
SQL
	$sth = spi_exec_query($sql);
	if ($sth->{status} ne 'SPI_OK_UTILITY') {
		error ("Could not create the snapshot log index for table '$schemaname.$mastername'. STATUS='".$sth->status."' SQL='$sql'");
	}
	
	$sql = <<SQL;
CREATE INDEX ${log}_ix2 on $schemaname.$log (snaptime\$\$, dmltype\$\$);
SQL
	$sth = spi_exec_query($sql);
	if ($sth->{status} ne 'SPI_OK_UTILITY') {
		error ("Could not create the snapshot log index for table '$schemaname.$mastername'. STATUS='".$sth->status."' SQL='$sql'");
	}
}
