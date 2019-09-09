#--
#-- SUB: getKeyColumns
#-- Returns the keys(on master and on snapshot log) involved on a "create snapshot WITH" statement
#--
sub getKeyColumns {
	#-- Function parameters
	my ($dbh, $schemaname, $mastername, $withwhat) = @_;

	#-- Local variables
	my $sth;
	my %masterKeyColumns = ();
	my %logKeyColumns = ();
	my %masterFilterColumns = ();
	my %masterPkColumns = ();
	my %tbFields = ();
	my @pk;
	my $fields;
	my $flag = 0x20; #-- ALL=0x20 HASPK=0x40 ROWID=0x01 PK=0x02 FILTER=0x04

	#-- Get object's metadata
	$sth = getObjectMeta($dbh, $schemaname, $mastername);

	#-- Creates a hashmap for FIELD NAME to FIELD TYPE mapping
	for (my $i = 0; $i < $sth->{NUM_OF_FIELDS}; ++$i) {
		my $fieldname = lc($sth->{NAME}->[$i]);
		my $type = getPgTypeName(map2PgType(getUnifiedSqlType($sth, $i)));
		%tbFields->{$fieldname} = $type;
	}
	
	#-- Get the table's primary key fields
	@pk = $dbh->primary_key( undef, $schemaname, $mastername );
	$dbh->commit;
	
	notice ('MASTER=(FIELDS:'.join(',', keys %tbFields).' TYPES:'.join(',', values %tbFields).' PK:'.join(',', @pk).')');
	
	$withwhat = lc($withwhat);
	$fields = '';
	if ( $withwhat =~ m/.*\(.*\).*/ ) {
		#-- We have parenthesis = additional fields
		$fields = $withwhat;
		#-- Save the additional fields
		$fields =~ s/^.*\((.*)\).*$/$1/;
		#-- Remove the additional fields from WITH
		$withwhat =~ s/^(.*)\(.*\)(.*)$/$1$2/;
	}
	
	#-- Parse the remaining arguments of WITH
	my @aux = split(/,/, $withwhat);
	for (my $i=0; $i < @aux; ++$i) {
		if (@aux[$i] eq 'oid') {
			$flag |= 0x01;
			%masterKeyColumns->{'oid'}=1;
			%logKeyColumns->{'m_row$$'}='oid';
		} elsif (@aux[$i] eq 'primary key') {
			$flag |= 0x02;
			$flag |= 0x40;
			if (@pk eq 0) {
				error ('Source does not have a PRIMARY KEY');
			}
			for (my $j=0; $j < @pk; ++$j) {
				%masterPkColumns->{@pk[$j]}=1;
				%masterKeyColumns->{@pk[$j]}=1;
				%logKeyColumns->{@pk[$j]}=%tbFields->{@pk[$j]};
			}
		} else {
			error ('Syntax error on WITH clause: '.@aux[$i]);
		}
	}

	#-- Parse the additional fields of WITH
	@aux = split(/,/, $fields);
	for (my $i=0; $i < @aux; ++$i) {
		my $column = @aux[$i];
		if (%tbFields->{$column} eq undef) {
			error ("Column not found: [$column]");
		}
		%masterFilterColumns->{$column}=1;
		%masterKeyColumns->{$column}=1;
		%logKeyColumns->{$column} = %tbFields->{$column};
		$flag |= 0x04;
	}
	notice ('KEY='.join(',', keys %logKeyColumns) . ' TYPES='.join(',', values %logKeyColumns));
	return ($flag, \%masterKeyColumns, \%logKeyColumns, \%masterPkColumns, \%masterFilterColumns);
}
