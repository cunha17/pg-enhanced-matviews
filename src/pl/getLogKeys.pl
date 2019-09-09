#--
#-- SUB: getLogKeys
#-- Maps the MASTER keys to SNAPSHOT LOG keys
#--
sub getLogKeys {
	#-- Function parameters
	my ($masterKeys) = @_;

	#-- Local variables
	my @arrLogKeys = ();
	my $logKeys;
	my @keys = split(/,/, $masterKeys);

	for (my $i = 0; $i < @keys; ++$i) {
		my $col = @keys[$i];
		if ($col eq 'oid') {
			push (@arrLogKeys, 'm_row$$');
		} else {
			push (@arrLogKeys, $col);
		}
	}
	$logKeys = join(',', @arrLogKeys);
	return ($logKeys, \@arrLogKeys);
}

