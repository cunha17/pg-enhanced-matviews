#--
#-- SUB: getColumnList
#-- Returns an array with all columns on a statement
#--
sub getColumnList {
	my ($sth) = @_;
	my @cols = ();

	for ( my $i = 0 ; $i < $sth->{NUM_OF_FIELDS} ; $i++ ) {
		push @cols, $sth->{NAME}->[$i];
	}
	return @cols;
}
