#--
#-- SUB: retrieveMasterForSnapshot
#-- Retrieve the MASTER tables for a SNAPSHOT
#--
sub retrieveMasterForSnapshot {
	#-- Function parameters
	my ($dbh, $snapshot) = @_;

	#-- Local variables
	my $masterschema;
	my $mastername;
	my $sql;
	my $sth;
	my $relatedCount;
	my $tablename;
	my @related=();
	my @tables=();
	my $from_index;

	$from_index = -1;
	$tablename = $snapshot->{'query'};
	notice ("Searching for Master on snapshot SQL:" . $tablename);
	@related = $tablename =~ m/((from |join |,) *((([0-9a-z_\$]+|".+")\.)?([0-9a-z_\$]+|".+")))+/gi;

	notice ("Parsing SQL... related:" . join('#', @related));

	for (my $i = 1; $i < @related; $i += 6) {
		notice ("Parsed $i found ".@related[$i]);
		if ( uc(@related[$i]) eq "FROM ") {
			$from_index = $i;
			$i = @related;
		}
        }

	if ( $from_index eq -1) {
		error ("Could not parse snapshot's SQL in order to find tables!");
	}

	for (my $i = $from_index+1; $i < @related; $i += 6) {
		push(@tables, @related[$i]);
	}
	notice ("Parsing SQL... found tables:" . join(',', @tables));

	if (@tables eq 0) {
		error ('Origin TABLES not found !');
	}

	if (@tables eq 1) {
		my $tablename = @tables[0];
		notice ("TABLE=[$tablename]");
		($masterschema, $mastername) = split(/\./, $tablename);
		notice ("MASTERSCHEMA=[$masterschema] MASTERNAME=[$mastername]");
		if ($masterschema eq undef or $mastername eq undef) {
			#-- No Schema
			warning ('Sorry, due to the complexity of your query, I could not guess the Schema name of your tables, so I will try a COMPLETE REFRESH instead.');
			$mastername = $masterschema;
			$snapshot->{'kind'} = 'C';
			$masterschema = undef;
			
		}
		return ($masterschema, $mastername);
	}

	if (($snapshot->{'kind'} eq 'F') || ($snapshot->{'kind'} eq 'R')) {
		warning ("Refresh FAST only work with one-table only queries. Falling back to COMPLETE REFRESH. TABLES=[" . join(',', @tables) . ']');
		$snapshot->{'kind'} = 'C';
	}
	return (undef, undef);
}
