sub validateModifyPrebuiltTable {
	#-- Function parameters
	my ($dbh, $schemaname, $snapshotname, $sth_source, $sth_target) = @_;

	#-- Local variables
	my $sql;
	my $sth;
	#-- compare column names, types and position
	for ( my $i = 0 ; $i < $sth_source->{NUM_OF_FIELDS} ; $i++ ) {
		my $columnName = $sth_source->{NAME}->[$i];
		if (getUnifiedSqlType($sth_source, $i) ne getUnifiedSqlType($sth_target, $i)) {
			error ("Types of column $columnName mismatch");
		}
		if ($sth_source->{PRECISION}->[$i] > $sth_target->{PRECISION}->[$i]) {
			error ("Precision of column $columnName on source exceeds precision on target");
		}
		if ($sth_source->{SCALE}->[$i] > $sth_target->{SCALE}->[$i]) {
			error ("Scale of column $columnName on source exceeds scale on target");
		}
		if ( $sth_source->{NULLABLE}->[$i] ne $sth_target->{NULLABLE}->[$i] ) {
			my $n;
			my $n1;
			if (! $sth_source->{NULLABLE}->[$i]) {
				$n = 'NOT NULLABLE';
				$n1 = 'NULLABLE';
			} else {
				$n = 'NULLABLE';
				$n1 = 'NOT NULLABLE';
			}
			warning ("Column $columnName is $n on source but is $n1 on target");
		}
	}
	notice ("Prebuilt table matches source query.");

	#-- tests if the $pbt column exists
	$sql = <<SQL;
SELECT pbt\$
FROM $schemaname.$snapshotname
WHERE 1=0
SQL
	eval {
		my $handler = $SIG{'__WARN__'};
		$SIG{'__WARN__'} = sub { };
		$sth = $dbh->prepare($sql);
		$sth->execute();
		$SIG{'__WARN__'} = $handler;
	};
	my $err = $sth->err;
	$sth->finish();
	$dbh->commit;
	if ($err) {
		#-- column $pbt does not exist
		$sql = <<SQL;
ALTER TABLE $schemaname.$snapshotname
ADD COLUMN pbt\$ NUMERIC default 0
SQL
		$dbh->do($sql);
		if ($dbh->err) {
			error ("Could not add the 'pbt\$' column to $schemaname.$snapshotname. SQL=$sql. [".$dbh->errstr.']');
		}
	} else {
		warning ("Column \$pbt already exists on $schemaname.$snapshotname");
	}
	$sql = <<SQL;
UPDATE $schemaname.$snapshotname
SET pbt\$=0
WHERE pbt\$ IS NULL
SQL
	$dbh->do($sql);
	if ($dbh->err) {
		error ("Could not set 'pbt\$' column on existing rows to 0 on $schemaname.$snapshotname. SQL=$sql. [".$dbh->errstr.']');
	}
	$dbh->commit;

	$sql = <<SQL;
ALTER TABLE $schemaname.$snapshotname
ALTER COLUMN pbt\$ SET NOT NULL
SQL
	$dbh->do($sql);
	if ($dbh->err) {
		error ("Could not modify the 'pbt\$' column to NOT NULL on $schemaname.$snapshotname. SQL=$sql. [".$dbh->errstr.']');
	}

	$sql = <<SQL;
CREATE INDEX ${snapshotname}_pbt\$_ix
ON $schemaname.$snapshotname (pbt\$)
SQL
	$dbh->do($sql);
	if ($dbh->err) {
		warning ("Could not create index on 'pbt\$' column on $schemaname.$snapshotname. SQL=$sql. [".$dbh->errstr.']');
	}
	$dbh->commit;

	$sql = <<SQL;
CREATE OR REPLACE FUNCTION $schemaname.${snapshotname}_pbt\$_trgfn()
RETURNS trigger AS
\$BODYFN\$
BEGIN
	IF (TG_OP = 'UPDATE') THEN
		IF ((OLD.pbt\$ <> 0) OR (NEW.pbt\$ <> 0)) THEN
			RAISE EXCEPTION 'Invalid operation on snapshot-based data!';
		END IF;
	ELSIF (TG_OP = 'DELETE') THEN
		IF (OLD.pbt\$ <> 0) THEN
			RAISE EXCEPTION 'Invalid operation on snapshot-based data!';
		END  IF;
	ELSIF (TG_OP = 'INSERT') THEN
		IF ((NEW.pbt\$ IS NOT NULL) AND (NEW.pbt\$ <> 0)) THEN
			RAISE EXCEPTION 'You cannot insert snapshot-based data manually!';
		END IF;
	END IF;
	RETURN NULL;
END;
\$BODYFN\$
LANGUAGE 'plpgsql' VOLATILE;
SQL
	
	notice ($sql);
	
	$dbh->do($sql);
	if ($dbh->err) {
		error ("Could not create the prebuilt table trigger function for table '$schemaname.$snapshotname'. ERR='".$dbh->errstr."' SQL='$sql'");
	}
	
	#-- Create TRIGGER on the prebuilt table
	notice ("Creating trigger ${snapshotname}_pbt\$_trg on $schemaname.${snapshotname}");
	$sql = <<SQL;
CREATE TRIGGER ${snapshotname}_pbt\$_trg AFTER INSERT OR UPDATE OR DELETE
ON $schemaname.${snapshotname} FOR EACH ROW
EXECUTE PROCEDURE $schemaname.${snapshotname}_pbt\$_trgfn ()
SQL
	$dbh->do($sql);
	if ($dbh->err) {
		warning ("Could not create the prebuilt table trigger on table '$schemaname.$snapshotname'. ERR='".$dbh->errstr."' SQL='$sql'");
	}
}
