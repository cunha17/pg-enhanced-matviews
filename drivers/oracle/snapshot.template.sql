--
-- Driver for Oracle replication logs
--
--DROP TABLE sys.snapshot_reghosts;
CREATE TABLE sys.snapshot_reghosts (
	id	NUMBER,
	ip	VARCHAR2(30),
	mowner	VARCHAR2(30),
	mname	VARCHAR2(30),
	CONSTRAINT snapshot_reghosts_pk PRIMARY KEY (id)
);
CREATE UNIQUE INDEX snapshot_reghosts_uix ON sys.snapshot_reghosts (ip, mowner, mname);
CREATE SEQUENCE sys.snapshot_reghosts_id_seq;

-- Returns the client IP if last refresh that a snapshot did using the snapshot log
CREATE OR REPLACE FUNCTION sys.getGrantedIp (
	m_owner IN VARCHAR2,
	m_name IN VARCHAR2) RETURN VARCHAR2 AUTHID DEFINER IS

	p	NUMBER;
	p1	NUMBER;
	ipnum	VARCHAR2(30);
	ipn	NUMBER;
	host	VARCHAR2(30);
	master_owner VARCHAR2(256);
	master_name VARCHAR2(256);
BEGIN
	master_owner := upper(m_owner);
	master_name := upper(m_name);

	IF (SYS_CONTEXT('USERENV','IP_ADDRESS') <> '127.0.0.1') THEN
		-- Let's check if the client IP address is allowed to connect
		BEGIN
			SELECT ip 
			INTO host
			FROM sys.snapshot_reghosts snt
			WHERE snt.ip=SYS_CONTEXT('USERENV','IP_ADDRESS')
				AND snt.mowner=master_owner
				AND snt.mname=master_name;
		EXCEPTION
			WHEN NO_DATA_FOUND THEN
				host := NULL;
		END;
		IF (host IS NULL) THEN
			RAISE LOGIN_DENIED;
		END IF;
		
		-- Valid IP, let's remove dots from IP address and keep each IP part with 3 zero-padded numeric places
		p := 1;
		ipnum := '';
		LOOP
			p1 := instr(host, '.', p);
			dbms_output.put_line(p1);
			IF p1 = 0 THEN
				ipn := TO_NUMBER(substr(host, p));
			ELSE
				ipn := TO_NUMBER(substr(host, p, p1 - p));
			END IF;
			ipnum := ipnum || trim(to_char(ipn, '000'));
			IF p1 = 0 THEN
				EXIT;
			END IF;
			p := p1 + 1;
		END LOOP;
	ELSE
		ipnum := '127000000001';
	END IF;
	RETURN ipnum;
END;
/
show errors;

-- Returns the snapshot log name
CREATE OR REPLACE FUNCTION sys.snapshotlog_name (
	m_owner IN VARCHAR2,
	m_name IN VARCHAR2 ) RETURN VARCHAR2 AUTHID DEFINER IS

	sname	VARCHAR2(256);
	master_owner VARCHAR2(256);
	master_name VARCHAR2(256);
BEGIN
	master_owner := upper(m_owner);
	master_name := upper(m_name);

	SELECT log into sname
	FROM SYS.MLOG$ 
	WHERE MOWNER=master_owner AND MASTER=master_name;
	
	RETURN sname;
EXCEPTION
	WHEN OTHERS THEN
		RETURN NULL;
END;
/

-- Returns the number of modified rown on the snapshot log table
CREATE OR REPLACE FUNCTION sys.count_log_modified_rows (
	mowner VARCHAR2,
	mname VARCHAR2,
	last_refresh VARCHAR2) RETURN NUMBER AUTHID DEFINER IS

	total	NUMBER;
	master_owner VARCHAR2(256);
	master_name VARCHAR2(256);
	sql_stmt VARCHAR2(2048);
BEGIN
	master_owner := lower(mowner);
	master_name := lower(mname);
	
	sql_stmt := 'SELECT count(*) as total FROM ' || master_owner || '.' || snapshotlog_name(master_owner, master_name) || ' WHERE ((snaptime$$ > TO_DATE(''' || last_refresh || ''', ''YYYY-MM-DD HH24:MI:SS'')) OR (snaptime$$ IS NULL))';
	EXECUTE IMMEDIATE sql_stmt INTO total;

	RETURN total;
END;
/
show errors;

CREATE OR REPLACE PROCEDURE sys.snapshot_do (
	comm_key IN VARCHAR2, 
	op IN VARCHAR2, 
	m_owner IN VARCHAR2,
	m_name IN VARCHAR2,
	additional IN VARCHAR2) AUTHID DEFINER IS
   
	slog_id	NUMBER;
	client_ip VARCHAR2(30);
	lastRefreshed DATE;
	snap_id	NUMBER;
	user_id	NUMBER;
	ipnum	VARCHAR2(30);
	ipn	NUMBER;
	refreshedTime	VARCHAR2(256);
	master_owner	VARCHAR2(256);
	master_name	VARCHAR2(256);
	p	NUMBER;
	username	VARCHAR2(256);
   BEGIN
	master_owner := upper(m_owner);
	master_name := upper(m_name);

	IF (comm_key <> '%COMMUNICATION_KEY%') THEN
		RAISE LOGIN_DENIED;
	END IF;
	
	SELECT USER INTO username FROM DUAL;

	-- This option allows a remote connection by IP for each MASTER table
	IF (substr(op, 1, 5) = 'ALLOW') THEN
		
		IF (username = 'SYS') THEN
			client_ip := substr(op, 7);
			INSERT INTO sys.snapshot_reghosts(id, ip, mowner, mname)
			VALUES (sys.snapshot_reghosts_id_seq.nextval, client_ip, master_owner, master_name);
			COMMIT;
		ELSE
			RAISE LOGIN_DENIED;
		END IF;
		RETURN;
	END IF;

	ipnum := getGrantedIp(master_owner, master_name);

	SELECT "USER#"
	INTO user_id
	FROM sys.user$
	WHERE name=username;

	-- Let's see what the client want to do
	IF (op = 'REGISTER') THEN
		IF (ipnum = '127000000001') THEN
			snap_id := additional;
		ELSE
			snap_id := TO_NUMBER(additional || ipnum);
		END IF;
		BEGIN
			SELECT SNAPID INTO slog_id 
			FROM SYS.SLOG$ 
			WHERE MOWNER=master_owner 
				AND MASTER=master_name 
				AND SNAPID=snap_id;
		EXCEPTION
			WHEN OTHERS THEN
				slog_id := NULL;
		END;
		IF (slog_id IS NULL) THEN
			INSERT INTO SYS.SLOG$(MOWNER, MASTER, SNAPID, SNAPTIME, "USER#") 
			VALUES (master_owner,
				master_name,
				snap_id,
				TO_DATE('1900-01-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS'),
				user_id);
		END IF;
	ELSIF (op = 'UNREGISTER') THEN
		IF (ipnum = '127000000001') THEN
			snap_id := additional;
		ELSE
			snap_id := TO_NUMBER(additional || ipnum);
		END IF;
		DELETE FROM SYS.SLOG$ 
		WHERE MOWNER=master_owner 
			AND MASTER=master_name
			AND SNAPID=snap_id;
	ELSIF (op = 'REFRESHED') THEN
		p := instr(additional, '|');
		IF p = 0 THEN
			RAISE LOGIN_DENIED;
		END IF;

		refreshedTime := substr(additional, 1, p - 1); -- TIMESTAMP
		snap_id := TO_NUMBER(substr(additional, p + 1)); --SNAPID

		IF (ipnum <> '127000000001') THEN
			snap_id := TO_NUMBER(snap_id || ipnum);
		END IF;

		BEGIN
			SELECT SNAPID INTO slog_id 
			FROM SYS.SLOG$ 
			WHERE MOWNER=master_owner 
				AND MASTER=master_name
				AND SNAPID=snap_id;
		EXCEPTION
			WHEN OTHERS THEN
				slog_id := NULL;
		END;
		SELECT TO_DATE(refreshedTime, 'YYYY-MM-DD HH24:MI:SS') INTO lastRefreshed FROM DUAL;
		IF (slog_id IS NULL) THEN
			INSERT INTO SYS.SLOG$(MOWNER, MASTER, SNAPID, SNAPTIME,"USER#")
				SELECT master_owner,
					master_name,
					snap_id,
					lastRefreshed,
					user_id
				FROM DUAL;
		ELSE
			UPDATE SYS.SLOG$ 
			SET snaptime=lastRefreshed,
				"USER#"=user_id
			WHERE MOWNER=master_owner 
				AND MASTER=master_name
				AND SNAPID=snap_id;
		END IF;
	ELSIF (op = 'PURGELOG') THEN
		DECLARE
			oldest DATE;
			null_values NUMBER;
			logtable VARCHAR2(256);
		BEGIN
			SELECT count(*)
			INTO null_values
			FROM sys.slog$
			WHERE mowner=master_owner
				AND master=master_name
				AND snaptime IS NULL;

			SELECT MIN(snaptime)
			INTO oldest
			FROM sys.slog$
			WHERE mowner=master_owner
				AND master=master_name;

			SELECT log
			INTO logtable
			FROM sys.mlog$
			WHERE mowner=master_owner
				AND master=master_name;

			IF (null_values = 0) THEN
				EXECUTE IMMEDIATE 'DELETE FROM ' || master_owner || '.' || logtable || ' WHERE snaptime$$ IS NOT NULL AND snaptime$$ <= TO_DATE(''' || TO_CHAR(oldest, 'YYYY-MM-DD HH24:MI:SS') || ''', ''YYYY-MM-DD HH24:MI:SS'')';
			END IF;
		EXCEPTION
			WHEN OTHERS THEN
				null_values:=0;
		END;
	ELSIF (op = 'UPDATE_NULL') THEN
		refreshedTime := additional;
		EXECUTE IMMEDIATE 'UPDATE ' || master_owner || '.mlog$_' || master_name || ' SET snaptime$$ = TO_DATE(''' || refreshedTime || ''', ''YYYY-MM-DD HH24:MI:SS'')' || ' WHERE (snaptime$$ IS NULL) OR (snaptime$$=TO_DATE(''4000-01-01 00:00:00'', ''YYYY-MM-DD HH24:MI:SS''))';
	ELSE
		RAISE LOGIN_DENIED;
	END IF;
	COMMIT;
   END;
/
show errors;

-- Returns the last refresh that a snapshot did using the snapshot log
CREATE OR REPLACE FUNCTION sys.last_log_refresh (
	m_owner IN VARCHAR2,
	m_name IN VARCHAR2,
	snapshot_id	IN NUMBER ) RETURN VARCHAR2 AUTHID DEFINER IS

	lastRefresh	DATE;
	snap_id		NUMBER;
	master_owner VARCHAR2(256);
	master_name VARCHAR2(256);
	ipnum VARCHAR2(256);
BEGIN
	master_owner := upper(m_owner);
	master_name := upper(m_name);

	ipnum := getGrantedIp(master_owner, master_name);
	IF (ipnum = '127000000001') THEN
		snap_id := snapshot_id;
	ELSE
		snap_id := TO_NUMBER(snapshot_id || ipnum);
	END IF;

	SELECT snaptime INTO lastRefresh
	FROM sys.slog$
	WHERE mowner=master_owner 
		AND master=master_name 
		AND snapid=snap_id;

	RETURN TO_CHAR(lastRefresh, 'YYYY-MM-DD HH24:MI:SS');
EXCEPTION
	WHEN OTHERS THEN
		RETURN NULL;
END;
/

-- Returns whether a snapshot log exists or not
CREATE OR REPLACE FUNCTION sys.snapshotlog_exists (
	m_owner IN VARCHAR2,
	m_name IN VARCHAR2 ) RETURN VARCHAR2 AUTHID DEFINER IS

	total	NUMBER;
	master_owner VARCHAR2(256);
	master_name VARCHAR2(256);
BEGIN
	master_owner := upper(m_owner);
	master_name := upper(m_name);

	SELECT count(*) into total
	FROM SYS.MLOG$
	WHERE MOWNER=master_owner AND MASTER=master_name;

	IF ( total > 0 ) THEN
		EXECUTE IMMEDIATE 'SELECT 1 from '||master_owner||'.mlog$_' || master_name || ' WHERE 1=0';
		RETURN 'T';
	ELSE
		RETURN 'F';
	END IF;
EXCEPTION
	WHEN OTHERS THEN
		RETURN 'F';
END;
/

-- Returns the snapshot log columns as a CSV
CREATE OR REPLACE FUNCTION sys.snapshotlog_columns (
	m_owner IN VARCHAR2,
	m_name IN VARCHAR2 ) RETURN VARCHAR2 AUTHID DEFINER IS

	total	NUMBER;
	sflag	NUMBER;
	scolumns VARCHAR2(2048);
	colname	SYS.MLOG_REFCOL$.colname%TYPE;
	master_owner VARCHAR2(256);
	master_name VARCHAR2(256);
	CURSOR c_scolumns IS
		SELECT colname
		FROM SYS.MLOG_REFCOL$
		WHERE MOWNER=upper(m_owner) 
			AND MASTER=upper(m_name);
BEGIN
	master_owner := upper(m_owner);
	master_name := upper(m_name);

	scolumns := '';
	OPEN c_scolumns;
	LOOP
		FETCH c_scolumns INTO colname;
		EXIT WHEN NOT c_scolumns%FOUND;
		scolumns := scolumns || ',' || colname;
	END LOOP;
	CLOSE c_scolumns;

	SELECT flag into sflag
	FROM SYS.MLOG$ 
	WHERE MOWNER=master_owner 
		AND MASTER=master_name;

	IF (BITAND(sflag, 1) = 1) THEN
		scolumns := scolumns || ',OID';
	END IF;

	RETURN LOWER(SUBSTR(scolumns, 2));
EXCEPTION
	WHEN OTHERS THEN
		RETURN NULL;
END;
/

-- Returns the snapshot log filter for retrieving the snapshot log updated or deleted records
CREATE OR REPLACE FUNCTION sys.snapshotlog_ud_filter (
	last_refresh IN VARCHAR2) RETURN VARCHAR2 AUTHID DEFINER IS
BEGIN
	RETURN '((snaptime$$ > TO_DATE(''' || last_refresh || ''',''YYYY-MM-DD HH24:MI:SS'')) OR (snaptime$$ IS NULL))
	AND dmltype$$ IN (''U'', ''D'')';
END;
/

-- Returns the snapshot log filter for retrieving the snapshot log inserted or updated records
CREATE OR REPLACE FUNCTION sys.snapshotlog_iu_filter (
	last_refresh IN VARCHAR2) RETURN VARCHAR2 AUTHID DEFINER IS
BEGIN
	RETURN '((snaptime$$ > TO_DATE(''' || last_refresh || ''',''YYYY-MM-DD HH24:MI:SS'')) OR (snaptime$$ IS NULL))
	AND dmltype$$ IN (''I'', ''U'')';
END;
/

GRANT EXECUTE ON sys.getGrantedIp TO PUBLIC;
GRANT EXECUTE ON sys.count_log_modified_rows TO PUBLIC;
GRANT EXECUTE ON sys.snapshot_do TO PUBLIC;
GRANT EXECUTE ON sys.last_log_refresh TO PUBLIC;
GRANT EXECUTE ON sys.snapshotlog_exists TO PUBLIC;
GRANT EXECUTE ON sys.snapshotlog_columns TO PUBLIC;
GRANT EXECUTE ON sys.snapshotlog_name TO PUBLIC;
GRANT EXECUTE ON sys.snapshotlog_ud_filter TO PUBLIC;
GRANT EXECUTE ON sys.snapshotlog_iu_filter TO PUBLIC;

CREATE OR REPLACE PUBLIC SYNONYM getGrantedIp for sys.getGrantedIp;
CREATE OR REPLACE PUBLIC SYNONYM count_log_modified_rows for sys.count_log_modified_rows;
CREATE OR REPLACE PUBLIC SYNONYM snapshot_do for sys.snapshot_do;
CREATE OR REPLACE PUBLIC SYNONYM last_log_refresh for sys.last_log_refresh;
CREATE OR REPLACE PUBLIC SYNONYM snapshotlog_exists for sys.snapshotlog_exists;
CREATE OR REPLACE PUBLIC SYNONYM snapshotlog_columns for sys.snapshotlog_columns;
CREATE OR REPLACE PUBLIC SYNONYM snapshotlog_name for sys.snapshotlog_name;
CREATE OR REPLACE PUBLIC SYNONYM snapshotlog_ud_filter for sys.snapshotlog_ud_filter;
CREATE OR REPLACE PUBLIC SYNONYM snapshotlog_iu_filter for sys.snapshotlog_iu_filter;

COMMIT;
