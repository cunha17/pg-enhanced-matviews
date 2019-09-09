#--
#-- SUB: call_driver_function
#-- Calls a driver function (native) on the database pointed by the database handle ($dbh)
#--
sub call_driver_function {
	my ($dbh, $function_name, $operation, $masterschema, $mastername, $additional) = @_;
	$masterschema = uc($masterschema);
	$mastername = uc($mastername);

	notice ("Calling DRIVER function $function_name ($operation, $masterschema, $mastername, $additional)");
	if ($function_name eq 'snapshot_do') {
		dbi_execute_stored_procedure($dbh, '%BASE_SCHEMA%.snapshot_do', ('%COMMUNICATION_KEY%', $operation, $masterschema, $mastername, $additional));
	} elsif ($function_name eq 'snapshotlog_exists') {
		return dbi_call_function($dbh, '%BASE_SCHEMA%.snapshotlog_exists', ($masterschema, $mastername));
	} elsif ($function_name eq 'last_log_refresh') {
		return dbi_call_function($dbh, '%BASE_SCHEMA%.last_log_refresh' , ($masterschema, $mastername, $additional));
	} elsif ($function_name eq 'snapshotlog_columns') {
		return dbi_call_function($dbh, '%BASE_SCHEMA%.snapshotlog_columns', ($masterschema, $mastername));
	} elsif ($function_name eq 'snapshotlog_name') {
		return dbi_call_function($dbh, '%BASE_SCHEMA%.snapshotlog_name', ($masterschema, $mastername));
	} elsif ($function_name eq 'count_log_modified_rows') {
		return dbi_call_function($dbh, '%BASE_SCHEMA%.count_log_modified_rows', ($masterschema, $mastername, $additional));
	} elsif ($function_name eq 'snapshotlog_ud_filter') {
		return dbi_call_function($dbh, '%BASE_SCHEMA%.snapshotlog_ud_filter', ($additional));
	} elsif ($function_name eq 'snapshotlog_iu_filter') {
		return dbi_call_function($dbh, '%BASE_SCHEMA%.snapshotlog_iu_filter', ($additional));
	} else {
		error ("Could not call DRIVER function: $function_name");
	}
	$dbh->commit;
}

sub dbi_execute_stored_procedure {
	use DBI::Const::GetInfoType;
	my ($dbh, $procname, @parameters) = @_;
	my $dbname = lc($dbh->get_info( $GetInfoType{SQL_DBMS_NAME} ));
	my $sql;
	my $sth;
	my $qmarks = '?,' x @parameters;
	chop $qmarks;

	if ($dbname eq 'oracle') {
		$sql = "BEGIN $procname($qmarks); END;";
	} elsif ($dbname eq 'postgresql') {
		$sql = "SELECT $procname($qmarks)";
	} else {
		$sql = "SELECT $procname($qmarks)";
	}
	$sth = $dbh->prepare($sql);
	if ($dbh->err) {
		error ($dbh->errstr."' SQL='$sql'");
	}
	$sth->execute(@parameters);
	if ($sth->err) {
		error ($sth->errstr."' SQL='$sql'");
	}
}

sub dbi_call_function {
	use DBI::Const::GetInfoType;
	my ($dbh, $funcname, @parameters) = @_;
	my $dbname = lc($dbh->get_info( $GetInfoType{SQL_DBMS_NAME} ));
	my $sql;
	my $sth;
	my @row;
	my $qmarks = '?,' x @parameters;
	chop $qmarks;

	if ($dbname eq 'oracle') {
		$sql = "SELECT $funcname($qmarks) FROM DUAL";
	} elsif ($dbname eq 'postgresql') {
		$sql = "SELECT $funcname($qmarks)";
	} else {
		$sql = "SELECT $funcname($qmarks)";
	}
	$sth = $dbh->prepare($sql);
	if ($dbh->err) {
		error ($dbh->errstr."' SQL='$sql'");
	}
	$sth->execute(@parameters);
	if ($sth->err) {
		error ($sth->errstr."' SQL='$sql'");
	}
	@row = $sth->fetchrow_array;
	my $result = @row[0];
	return $result;
}
