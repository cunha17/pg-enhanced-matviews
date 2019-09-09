#--
#-- SUB: getSnapshotLog
#-- Returns the SNAPSHOT LOG associated with a MASTER TABLE
#--
sub getSnapshotLog {
	#-- Function arguments
	my ($dbh, $masterschema, $mastername) = @_;

	#-- Local variables
	my $snaplogid = undef;
	my $sql;
	my $sth;
	my $row;
	
	$sql = <<SQL;
SELECT *
FROM %BASE_SCHEMA%.pg_snapshotlogs
WHERE masterschema=? AND mastername=?
SQL
	$sth = $dbh->prepare($sql);
	$sth->execute(($masterschema, $mastername));
	if ($sth->err) {
		error("Could not find %BASE_SCHEMA%.pg_snapshotlogs!");
	}
	$row = $sth->fetchrow_hashref;
	if ($row->{'snaplogid'} ne undef) {
		#-- Test if LOG physically exists ($masterschema.mlog\$_$mastername)
		$sql = <<SQL;
SELECT 1 from $masterschema.mlog\$_$mastername
SQL
		eval {
			my $handler = $SIG{'__WARN__'};
			$SIG{'__WARN__'} = sub { };
			$dbh->do($sql);
			$SIG{'__WARN__'} = $handler;
		};
		if (! $dbh->err) {
			$snaplogid = $row->{'snaplogid'};
		}
	}
	$dbh->commit;
	return $row;
}
