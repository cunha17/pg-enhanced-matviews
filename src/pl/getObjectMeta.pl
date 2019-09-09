#--
#-- SUB: getObjectMeta
#-- Returns an empty result STATEMENT in order to retrieve the object's METADATA
#--
sub getObjectMeta {
	my ($dbh, $schemaname, $mastername) = @_;

	my $sql;
	my $sth;

	$sql = <<SQL;
SELECT * from $schemaname.$mastername
WHERE 1=0
SQL
	$sth = $dbh->prepare($sql);
	if (! $sth->err) {
		$sth->execute();
	}
	return $sth;
}