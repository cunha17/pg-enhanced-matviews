#--
#-- SUB: setTriggerStatus
#-- Enable/Disable a trigger
#--
sub setTriggerStatus {
	#-- Function parameters
	my ($dbh, $schemaname, $tablename, $triggername, $status) = @_;
	my $sth;

	
	
	if ($status) {
		notice ("Enabling trigger $triggername for table $schemaname.$tablename ");
		$sql = <<SQL;
ALTER TABLE $schemaname.$tablename 
ENABLE TRIGGER $triggername
SQL
	} else {
		notice ("Disabling trigger $triggername for table $schemaname.$tablename ");
		$sql = <<SQL;
ALTER TABLE $schemaname.$tablename 
DISABLE TRIGGER $triggername
SQL
	}
	notice ($sql);
	$sth = $dbh->prepare($sql);
	$sth->execute();

	if ($sth->err) {
		error ($sth->errstr);
	}
	return;

	#-- Local variables
	my $sql;
	my $sth;
	my $tgenabled = ($status == TRUE) ? 'TRUE' : 'FALSE';

	$sql = <<SQL;
SELECT c.oid
FROM pg_class c
	LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname=? 
	AND c.relname=?
SQL
	my ($tableid) = sqlLookup($dbh, $sql, ($schemaname, $tablename));
	if ("$tableid" eq "") {
		error ("Could not retrieve TABLEID for table $schemaname.$tablename");
	}

	notice ("Disabling trigger for table ID=$tableid NAME=$triggername");
	$sql = <<SQL;
UPDATE pg_trigger 
SET tgenabled = '$tgenabled'
WHERE tgrelid=? 
	AND tgname=?
SQL
	notice ($sql);
	$sth = $dbh->prepare($sql);
	$sth->execute(($tableid, $triggername));

	#-- Dummy update to refresh new trigger status
	if ($sth->err) {
		error ($sth->errstr);
	}
	$sql = <<SQL;
UPDATE pg_class
SET relname=relname
WHERE oid=?
SQL
	$sth = $dbh->prepare($sql);
	$sth->execute(($tableid));
	if ($sth->err) {
		error ($sth->errstr);
	}
}
