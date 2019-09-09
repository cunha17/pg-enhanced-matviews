#--
#-- SUB: snapshotLogExists
#-- Returns whether a master object has a SNAPSHOT LOG
#--
sub snapshotLogExists {
	#-- Function parameters
	my ($dbh, $masterschema, $mastername) = @_;
	my $result;

	eval {
        	my $handler = $SIG{'__WARN__'};
                $SIG{'__WARN__'} = sub { };
                $result = call_driver_function($dbh, 'snapshotlog_exists', undef, $masterschema, $mastername, undef);
                $dbh->set_err (undef, undef);
                $SIG{'__WARN__'} = $handler;
	};
	if ($@) {
		return (1 eq 0);
	} else {
		return ($result eq 'T');
	}
}
