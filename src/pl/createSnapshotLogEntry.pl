sub createSnapshotLogEntry {
	my ($dbh, $schemaname, $mastername, $flag, $log, $masterPkColumns, $masterFilterColumns) = @_;

	my $sth;

	#-- Add the Snapshot Log to the %BASE_SCHEMA%.pg_mlogs table
	$sql = <<SQL;
	INSERT INTO %BASE_SCHEMA%.pg_mlogs(masterschema, mastername, flag, log)
	VALUES (?,?,?,?)
SQL
	$sth = $dbh->prepare($sql);
	if ($sth->err) {
		error ("Could not prepare the snapshot log entry on system table '%BASE_SCHEMA%.pg_mlogs'. ERROR='".$sth->errstr."' SQL='$sql'");
	}
	$sth->execute(($schemaname, $mastername, $flag, $log));
	if ($sth->err) {
		error ("Could not create the snapshot log entry on system table '%BASE_SCHEMA%.pg_mlogs'. ERROR='".$sth->errstr."' SQL='$sql'");
	}

	my $snaplogid;
	my @row;

	$sql = <<SQL;
	SELECT snaplogid
	FROM %BASE_SCHEMA%.pg_mlogs
	WHERE masterschema=?
		AND mastername=?
SQL
	$sth = $dbh->prepare($sql);
	$sth->execute(($schemaname, $mastername));
	if ($sth->err) {
		error ($sth->errstr."' SQL='$sql'");
	}
	@row = $sth->fetchrow_array;
	
	$snaplogid = @row[0];

	notice ('SNAPLOGID='.$snaplogid);

	createSnapshotLogEntryColumns($dbh, $schemaname, $mastername, $flag, $log, $snaplogid, $masterPkColumns, $masterFilterColumns);
}
