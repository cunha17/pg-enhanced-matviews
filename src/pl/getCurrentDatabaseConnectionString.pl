#--
#-- SUB: getCurrentDatabaseConnectionString
#-- Returns the correct connection string to the current(local) database
#--
sub getCurrentDatabaseConnectionString {
	#-- Local variables
	my $dbname = spiGetCurrentDatabase();
	return "dbi:Pg:dbname=$dbname";
}
