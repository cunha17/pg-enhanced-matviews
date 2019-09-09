#--
#-- SUB: getQueryWithNoRecords
#-- Places a FALSE filter into a query in order to retrieve no records (query structure only)
#--
sub getQueryWithNoRecords {
	#-- Function parameters
	my ($dbh, $query) = @_;

	my $sth;
	my $sql;

	#-- some fake databases do not support subqueries, so we need to modify
	#-- the original query and insert "1=0 AND " or "WHERE 1=0" as needed
	#-- of course, we try "SELECT * FROM ($query) WHERE 1=0" first,
	#-- for databases that support subqueries, or better: REAL databases
	$sql = "SELECT * FROM ($query) query WHERE 1=0";
	notice ($sql);
	$sth = $dbh->prepare($sql);
	if ($DBI::errstr) {
		$query =~ tr/\n/ /;
		my $lc_query = lc($query);
		my $wherepos = rindex($lc_query, " where ");
		if ($wherepos > 0) {
			$sql = substr($query, 0, $wherepos) . ' WHERE 1=0 AND ' . substr($query, $wherepos + length(" where "));
		} else {
			my $orderbypos = rindex($lc_query, " order by ");
			my $groupbypos = rindex($lc_query, " group by ");
			if ($orderbypos < $groupbypos) {
				$wherepos = $orderbypos;
			} else {
				$wherepos = $groupbypos;
			}
			if ($wherepos == -1) {
				$wherepos = length($lc_query);
			}
			$sql = substr($query, 0, $wherepos) . ' WHERE 1=0 ' . substr($query, $wherepos);
		}
	
		notice ($sql);
		$sth = $dbh->prepare($sql);
		if ($DBI::errstr) {
			my $err = <<_ERR;
Cannot prepare

$sql

$DBI::errstr
_ERR
			error ($err);
		}
	}
	return $sql;
}
