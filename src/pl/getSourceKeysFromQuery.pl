#--
#-- getSourceKeysFromQuery
#--
sub getSourceKeysFromQuery {
	my ($query, @masterKeys) = @_;
	my @keys=();

        my @related = $query =~ m/ +([0-9a-z_\$]+|".+") +as +([0-9a-z_\$]+|".+")/gi;
	my $found;

	for (my $i = 0; $i < @masterKeys; ++$i) {
		$found = FALSE;
		for (my $j = 0; $j < @related; $j += 2) {
			if (@masterKeys[$i] eq @related[$j]) {
				push(@keys, @related[$j+1]);
				$found = TRUE;
				last;
			}
		}
		if (! $found) {
			push(@keys, @masterKeys[$i]);
		}
	}
	return @keys;
}

