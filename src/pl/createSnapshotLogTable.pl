#--
#-- SUB: createSnapshotLogTable
#-- Creates the SNAPSHOT LOG table
#--
sub createSnapshotLogTable {
	my ($schemaname, $mastername, $logKeyColumns) = @_;

	my $strcolumns = '';
	my $sql;
	my $sth;

	while (my ($key,$value) = each %$logKeyColumns) {
		notice ("$key=>$value");
		my $entry = "$key $value";
		$strcolumns = "$strcolumns$entry,\n";
	}

	$sql = <<SQL;
CREATE TABLE $schemaname.mlog\$_$mastername (
	$strcolumns
	snaptime\$\$	timestamp,
	dmltype\$\$	varchar(1),
	old_new\$\$	varchar(1),
	change_vector\$\$	varchar(255)
)
SQL

	notice ($sql);

	$sth = spi_exec_query($sql);

	if ($sth->{status} ne 'SPI_OK_UTILITY') {
		error ("Could not create the snapshot log for table '$schemaname.$mastername'. STATUS='".$sth->status."' SQL='$sql'");
	}

	return "mlog\$_$mastername";
}
