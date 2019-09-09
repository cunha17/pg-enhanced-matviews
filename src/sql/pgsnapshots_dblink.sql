--
-- ATTENTION: This is a free software. 
--            View the LICENSE.txt file for license information
--

------------------------------------------------------------------------------
-- FUNCTION: %BASE_SCHEMA%.create_dblink
--
-- Creates a DATABASE LINK to any databases supported by PERL
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION %BASE_SCHEMA%.create_dblink(dblinkname text, datasource text, username text, password text, attributes text)
  RETURNS bool AS
$BODY$
use strict;
use DBI;
use constant TRUE => 1;
use constant FALSE => "";
#-- Function parameters
my ($dblinkname, $datasource, $username, $password, $attributes) = @_;
$dblinkname = lc($dblinkname);
my $attr_href = eval($attributes);
#-- Set this to 1 for debugging messages
$main::DEBUG=0;
#-- Localhost superuser connection
my $dbh_local = DBI->connect(getCurrentDatabaseConnectionString(), '%SUPERUSER%', undef, {AutoCommit => 0});
#-- Remote database connection
my $dbh;
#-- variables
my $sql;
my $sth;

#-- Test if DBLINK already exists
if (dblinkExists($dbh_local, $dblinkname)) {
	elog ERROR, "DBLink $dblinkname already created";
}

#-- Try to connect to the remote database
$dbh = dbiGetConnection($datasource, $username, $password, $attr_href);
$dbh->disconnect;

#-- Create the DBLINK entry on %BASE_SCHEMA%.pg_dblinks table
$sql = <<SQL;
INSERT INTO %BASE_SCHEMA%.pg_dblinks(dblinkname, datasource, username, password, attributes)
VALUES (?, ?, ?, ?, ?)
SQL
$sth = $dbh_local->prepare($sql);
$sth->execute(($dblinkname, $datasource, $username, $password, $attributes));

if (! $sth->err) {
	elog NOTICE, "DBLink created" if $main::DEBUG==1;
} else {
	elog ERROR, "Could not create DBLink '$dblinkname' ERROR=". $sth->errstr;
}
$dbh_local->commit;
$dbh_local->disconnect;

#-- All done. Let's return TRUE
return TRUE;

INCLUDE 'sqlLookup.pl'
INCLUDE 'dblinkExists.pl'
INCLUDE 'dbiGetConnection.pl'
INCLUDE 'getCurrentDatabaseConnectionString.pl'

INCLUDE 'spiGetCurrentDatabase.pl'

$BODY$
  LANGUAGE 'plperlu' VOLATILE;

ALTER FUNCTION %BASE_SCHEMA%.create_dblink(dblinkname text, datasource text, username text, password text, attributes text) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION %BASE_SCHEMA%.create_dblink(text, text, text, text, text) TO "snapshot.users";
COMMENT ON FUNCTION %BASE_SCHEMA%.create_dblink(dblinkname text, datasource text, username text, password text, attributes text) IS $$
This function is part of PostgreSQL::Snapshots project.
This is the function that creates a dblink. First it test the connection then it adds a record on the %BASE_SCHEMA%.pg_dblinks table.
$$;

------------------------------------------------------------------------------
-- FUNCTION: %BASE_SCHEMA%.drop_dblink
--
-- Removes a previously created DATABASE LINK
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION %BASE_SCHEMA%.drop_dblink(dblinkname text)
  RETURNS bool AS
$BODY$
use strict;
use DBI;
use constant TRUE => 1;
use constant FALSE => "";
#-- Function parameters
my ($dblinkname) = @_;
$dblinkname = lc($dblinkname);
#-- Set this to 1 for debugging messages
$main::DEBUG=0;
#-- Localhost superuser connection
my $dbh_local = DBI->connect(getCurrentDatabaseConnectionString(), '%SUPERUSER%', undef, {AutoCommit => 0});
#-- variables
my $sql;
my $sth;

#-- Lets make shure that the DBLINK exists
if (! dblinkExists($dbh_local, $dblinkname)) {
	elog ERROR, "DBLink '$dblinkname' does not exist";
}

#-- Delete the DBLINK entry
$sql = <<SQL;
DELETE FROM %BASE_SCHEMA%.pg_dblinks WHERE dblinkname=?
SQL
$sth = $dbh_local->prepare($sql);
$sth->execute(($dblinkname));

if (! $sth->err) {
	elog NOTICE, "DBLink removed" if $main::DEBUG==1;
} else {
	elog ERROR, "Could not remove DBLink '$dblinkname' ERROR=".$sth->errstr;
}
$dbh_local->commit;
$dbh_local->disconnect;
#-- All done. Let's return TRUE
return TRUE;

INCLUDE 'message.pl'
INCLUDE 'dblinkExists.pl'
INCLUDE 'sqlLookup.pl'
INCLUDE 'getCurrentDatabaseConnectionString.pl'

INCLUDE 'spiGetCurrentDatabase.pl'

$BODY$
  LANGUAGE 'plperlu' VOLATILE;
ALTER FUNCTION %BASE_SCHEMA%.drop_dblink(dblinkname text) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION %BASE_SCHEMA%.drop_dblink(text) TO "snapshot.users";
COMMENT ON FUNCTION %BASE_SCHEMA%.drop_dblink(dblinkname text) IS $$
This function is part of PostgreSQL::Snapshots project.
This is the function that removes a dblink.
$$;
