#--
#-- SUB: dbiGetConnection
#-- Connects to a DBI datasource and returns a connection handle
#--
sub dbiGetConnection {
	my ($datasource, $username, $password, $attributes) = @_;
	
	# local variables
	my $dbh;

	$dbh = DBI->connect(
		$datasource
		, $username
		, $password
		, $attributes
		);
	if ($DBI::errstr) {
		my $msg = <<ERR;
Could not connect to database
data source: $datasource
user: $username
password: $password
dbh attributes:
$attributes

$DBI::errstr
ERR
		error ($msg);
	}

	#Defining the client encoding
	$dbh->do('SET NAMES utf8') if $dbh->{Driver}->{Name} eq 'mysql';

	return $dbh;
}
