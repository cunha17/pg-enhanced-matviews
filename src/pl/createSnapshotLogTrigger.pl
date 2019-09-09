#--
#-- SUB: createSnapshotLogTrigger
#-- Creates the triggers on the MASTER object in order to fill the SNAPSHOT LOG entries
#--
sub createSnapshotLogTrigger {
	#-- Function parameters
	my ($dbh, $schemaname, $mastername, $log, $masterKeyColumns, $logKeyColumns) = @_;

	#-- Local variables
	my $sth;
	my $sql;

	#-- Get object's metadata
	$sth = getObjectMeta($dbh, $schemaname, $mastername);

	#-- Create the PL/PgSQL code for computing the CHANGEVECTOR field
	my $all_unset_cv = '0' x ($sth->{NUM_OF_FIELDS} / 8);
	my $all_set_cv = 'F' x ($sth->{NUM_OF_FIELDS} / 8);
	
	if (($sth->{NUM_OF_FIELDS} % 8) ne 0) {
		$all_unset_cv = $all_unset_cv . '0';
		$all_set_cv = $all_set_cv.sprintf("%x",(2^($sth->{NUM_OF_FIELDS} % 8)-1));
	}
	
	my $compute_change_vector = '';
	
	for (my $i = 0; $i < $sth->{NUM_OF_FIELDS}; ++$i) {
		my $fieldname = $sth->{NAME}->[$i];
		my $value = 2**$i;
		$compute_change_vector = $compute_change_vector . <<SQL;
			IF (OLD.$fieldname <> NEW.$fieldname) THEN
				CVB = CVB + $value;
			END IF;
SQL
		if ((($i + 1) % 8) eq 0) {
			$compute_change_vector = $compute_change_vector . <<SQL;
			CV = CV || to_hex(CVB);
			ALL_CVB = ALL_CVB + CVB;
			CVB = 0;
SQL
		}
	}
	if (($sth->{NUM_OF_FIELDS} % 8) ne 0) {
		$compute_change_vector = $compute_change_vector . <<SQL;
			CV = CV || to_hex(CVB);
			ALL_CVB = ALL_CVB + CVB;
SQL
	}

	$sth->finish;
	$dbh->commit;

	#-- Create the TRIGGER function
	notice ("Creating trigger function $schemaname.${log}_trgfn()");
	
	my $oldMasterKeys = 'OLD.'.join(', OLD.', keys %$masterKeyColumns);
	my $newMasterKeys = 'NEW.'.join(', NEW.', keys %$masterKeyColumns);
	
	$sql = <<SQL;
CREATE OR REPLACE FUNCTION $schemaname.${log}_trgfn()
RETURNS trigger AS
\$BODYFN\$
DECLARE
	CV		varchar(255);
	CVB		integer;
	ALL_CVB		numeric;
BEGIN
	IF (TG_OP = 'DELETE') THEN
		INSERT INTO $schemaname.$log SELECT $oldMasterKeys,NULL,'D','O','$all_unset_cv';
	ELSIF (TG_OP = 'UPDATE') THEN
		CV = '';
		CVB = 0;
		ALL_CVB = 0;
$compute_change_vector
		IF (ALL_CVB > 0) THEN
			INSERT INTO $schemaname.$log SELECT $oldMasterKeys,NULL,'U','O',CV;
		END IF;
		IF (OLD.oid <> NEW.oid) THEN
			INSERT INTO $schemaname.$log SELECT $newMasterKeys,NULL,'U','N',CV;
		END IF;
	ELSIF (TG_OP = 'INSERT') THEN
		INSERT INTO $schemaname.$log SELECT $newMasterKeys,NULL,'I','N','$all_set_cv';
	END IF;
	RETURN NULL;
END;
\$BODYFN\$
LANGUAGE 'plpgsql' VOLATILE;
SQL
	
	notice ($sql);
	
	$dbh->do($sql);
	if ($dbh->err) {
		error ("Could not create the snapshot log trigger function for table '$schemaname.$mastername'. ERR='".$dbh->errstr."' SQL='$sql'");
	}
	
	#-- Create TRIGGER on master table
	notice ("Creating trigger ${log}_trg on $schemaname.${mastername}");
	$sql = <<SQL;
CREATE TRIGGER ${log}_trg AFTER INSERT OR UPDATE OR DELETE
ON $schemaname.${mastername} FOR EACH ROW
EXECUTE PROCEDURE $schemaname.${log}_trgfn ()
SQL
	
	$dbh->do($sql);
	if ($dbh->err) {
		error ("Could not create the snapshot log trigger on table '$schemaname.$mastername'. ERR='".$dbh->errstr."' SQL='$sql'");
	}
}
