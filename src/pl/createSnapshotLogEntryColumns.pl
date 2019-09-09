sub createSnapshotLogEntryColumns {
	my ($dbh, $schemaname, $mastername, $flag, $log, $snaplogid, $masterPkColumns, $masterFilterColumns) = @_;

	my $sql;
	my $sth;

	#-- Add the Snapshot Log Column to the %BASE_SCHEMA%.pg_mlog_refcols table
	$sql = <<SQL;
	INSERT INTO %BASE_SCHEMA%.pg_mlog_refcols(snaplogid, masterschema, mastername, colname, flag)
	VALUES (?,?,?,?,?)
SQL
	$sth = $dbh->prepare($sql);
	if ($sth->err) {
		error ("Could not prepare the snapshot log column entry on system table '%BASE_SCHEMA%.pg_mlog_refcols'. ERROR='".$sth->errstr."' SQL='$sql'");
	}
	
	if ($flag & 0x42) {
		#-- PK
		while (my ($key,$value) = each %$masterPkColumns) {
			$sth->execute($snaplogid, $schemaname, $mastername, $key, 2);
			if ($sth->err) {
				error("Could not create the snapshot log column entry on system table '%BASE_SCHEMA%.pg_mlog_refcols'. ERROR='".$sth->errstr."' SQL='$sql'");
			}
		}
	}
	if ($flag & 0x04) {
		#-- FILTER
		while (my ($key,$value) = each %$masterFilterColumns) {
			$sth->execute($snaplogid, $schemaname, $mastername, $key, 2);
			if ($sth->err) {
				error ("Could not create the snapshot log column entry on system table '%BASE_SCHEMA%.pg_mlog_refcols'. ERROR='".$sth->errstr."' SQL='$sql'");
			}
		}
	}
}
