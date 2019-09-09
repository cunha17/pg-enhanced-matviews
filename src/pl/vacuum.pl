#--
#-- SUB: vacuum
#-- Performs a VACUUM ANALYZE on a target object
#--
sub vacuum {
	#-- Function parameters
	my ($dbh, $schemaname, $snapshotname) = @_;

	#-- Local variables
	my $sql;

	$sql = "VACUUM ANALYZE $schemaname.$snapshotname";
	$dbh->do($sql);
	return (! $dbh->err);
}
