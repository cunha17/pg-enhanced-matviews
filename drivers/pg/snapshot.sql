--
-- Driver for PostgreSQL replication logs
--
CREATE SCHEMA public;
GRANT USAGE ON SCHEMA public TO PUBLIC;

--DROP TABLE public.snapshot_reghosts;
CREATE TABLE public.snapshot_reghosts (
	id	NUMERIC,
	ip	VARCHAR(30),
	mowner	VARCHAR(30),
	mname	VARCHAR(30),
	CONSTRAINT snapshot_reghosts_pk PRIMARY KEY (id)
);
CREATE UNIQUE INDEX snapshot_reghosts_uix ON public.snapshot_reghosts (ip, mowner, mname);
CREATE SEQUENCE public.snapshot_reghosts_id_seq;

CREATE OR REPLACE FUNCTION public.snapshot_do (
	comm_key VARCHAR, 
	op VARCHAR, 
	m_owner VARCHAR,
	m_name VARCHAR,
	additional VARCHAR) RETURNS BOOLEAN SECURITY DEFINER AS
$BODY$
  DECLARE
	slog_id	NUMERIC;
        log_table TEXT;
	client_ip VARCHAR(30);
	lastRefreshed TIMESTAMP;
	snap_id	NUMERIC;
	user_id	NUMERIC;
	ipnum	VARCHAR(30);
	ipn	NUMERIC;
	refreshedTime VARCHAR;
	master_owner VARCHAR;
	master_name VARCHAR;
	p INTEGER;
  BEGIN
	master_owner := lower(m_owner);
	master_name := lower(m_name);

	IF (comm_key <> '123456') THEN
		RAISE EXCEPTION 'LOGIN_DENIED:K';
	END IF;
	
	-- This option allows a remote connection by IP for each MASTER table
	IF (op = 'ALLOW') THEN
		IF (current_user = 'postgres') THEN
			client_ip := additional;
			INSERT INTO public.snapshot_reghosts(id, ip, mowner, mname)
			VALUES (nextval('public.snapshot_reghosts_id_seq'), client_ip, master_owner, master_name);
		ELSE
			RAISE EXCEPTION 'LOGIN_DENIED:A';
		END IF;
		RETURN TRUE;
	END IF;
	
	ipnum := public.getGrantedIp(master_owner, master_name);

	SELECT usesysid
	INTO user_id
	FROM pg_user
	WHERE usename=current_user;

	-- Let's see what the client want to do
	IF (op = 'REGISTER') THEN
		IF (ipnum = '127000000001') THEN
			snap_id := additional;
		ELSE
			snap_id := (additional || ipnum)::NUMERIC;
		END IF;
		BEGIN
			SELECT snapid INTO slog_id
			FROM public.pg_mlogs
				INNER JOIN public.pg_slogs ON pg_mlogs.snaplogid=pg_slogs.snaplogid
			WHERE pg_mlogs.masterschema=master_owner 
				AND pg_mlogs.mastername=master_name 
				AND pg_slogs.snapid=snap_id;
		EXCEPTION
			WHEN OTHERS THEN
				slog_id := NULL;
		END;
		IF (slog_id IS NULL) THEN
			SELECT snaplogid, log INTO slog_id, log_table
			FROM public.pg_mlogs
			WHERE pg_mlogs.masterschema=master_owner 
				AND pg_mlogs.mastername=master_name;

			INSERT INTO public.pg_slogs(snaplogid, snapid, snaptime, userid) 
			VALUES (slog_id,
				snap_id,
				TO_TIMESTAMP('1900-01-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS'),
				user_id);
			EXECUTE 'GRANT SELECT ON ' || master_owner || '.' || log_table || ' TO ' || session_user;
		END IF;
	ELSIF (op = 'UNREGISTER') THEN
		IF (ipnum = '127000000001') THEN
			snap_id := additional;
		ELSE
			snap_id := (additional || ipnum)::NUMERIC;
		END IF;
		DELETE FROM public.pg_slogs
		WHERE snaplogid IN (
			SELECT snaplogid 
			FROM public.pg_mlogs 
			WHERE pg_mlogs.masterschema=master_owner 
				AND pg_mlogs.mastername=master_name
			)
			AND snapid=snap_id;
	ELSIF (op = 'REFRESHED') THEN
		p := strpos(additional, '|');
		IF p = 0 THEN
			RAISE EXCEPTION 'LOGIN_DENIED:R';
		END IF;

		refreshedTime := substr(additional, 1, p - 1); -- TIMESTAMP
		snap_id := substr(additional, p + 1)::NUMERIC; --SNAPID

		IF (ipnum <> '127000000001') THEN
			snap_id := (snap_id || ipnum)::NUMERIC;
		END IF;

		BEGIN		
			SELECT snapid INTO slog_id 
			FROM public.pg_mlogs
				INNER JOIN public.pg_slogs ON pg_mlogs.snaplogid=pg_slogs.snaplogid
			WHERE pg_mlogs.masterschema=master_owner 
				AND pg_mlogs.mastername=master_name 
				AND pg_slogs.snapid=snap_id;
		EXCEPTION
			WHEN OTHERS THEN
				slog_id := NULL;
		END;
		SELECT TO_TIMESTAMP(refreshedTime, 'YYYY-MM-DD HH24:MI:SS') INTO lastRefreshed;
		IF (slog_id IS NULL) THEN
			SELECT snaplogid INTO slog_id 
			FROM public.pg_mlogs
			WHERE pg_mlogs.masterschema=master_owner 
				AND pg_mlogs.mastername=master_name;

			INSERT INTO public.pg_slogs(snaplogid, snapid, snaptime, userid)
				SELECT slog_id,
					snap_id,
					lastRefreshed,
					user_id;
		ELSE
			UPDATE public.pg_slogs
			SET snaptime=lastRefreshed,
				userid=user_id
			WHERE snaplogid IN (
				SELECT snaplogid 
				FROM public.pg_mlogs
				WHERE pg_mlogs.masterschema=master_owner 
					AND pg_mlogs.mastername=master_name
				)
				AND snapid=snap_id;
		END IF;
	ELSIF (op = 'PURGELOG') THEN
		DECLARE
			oldest TIMESTAMP;
			null_values NUMERIC;
			logtable VARCHAR;
		BEGIN
			SELECT count(*)
			INTO null_values
			FROM public.pg_mlogs
				INNER JOIN public.pg_slogs ON pg_mlogs.snaplogid=pg_slogs.snaplogid
			WHERE masterschema=master_owner
				AND mastername=master_name
				AND pg_slogs.snaptime IS NULL;

			SELECT MIN(pg_slogs.snaptime)
			INTO oldest
			FROM public.pg_mlogs
				INNER JOIN public.pg_slogs ON pg_mlogs.snaplogid=pg_slogs.snaplogid
			WHERE masterschema=master_owner
				AND mastername=master_name;

			SELECT log
			INTO logtable
			FROM public.pg_mlogs
			WHERE masterschema=master_owner
				AND mastername=master_name;

			IF (null_values = 0) THEN
				EXECUTE 'DELETE FROM ' || quote_ident(master_owner) || '.' || quote_ident(logtable) || ' WHERE snaptime$$ IS NOT NULL AND snaptime$$ <= TO_TIMESTAMP(' || quote_literal(to_char(oldest, 'YYYY-MM-DD HH24:MI:SS' )) || ', ''YYYY-MM-DD HH24:MI:SS'')';
				END IF;
		END;
	ELSIF (op = 'UPDATE_NULL') THEN
		refreshedTime := additional;
		EXECUTE 'UPDATE ' || master_owner || '.' || public.snapshotlog_name(master_owner, master_name) || ' SET snaptime$$ = TO_TIMESTAMP(' || quote_literal(refreshedTime) || ', ''YYYY-MM-DD HH24:MI:SS'') WHERE snaptime$$ IS NULL ';
	ELSE
		RAISE EXCEPTION 'LOGIN_DENIED:O';
	END IF;
	RETURN TRUE;
   END;
$BODY$ LANGUAGE plpgsql;

-- Returns the client IP if last refresh that a snapshot did using the snapshot log
CREATE OR REPLACE FUNCTION public.getGrantedIp (
	m_owner VARCHAR,
	m_name VARCHAR) RETURNS VARCHAR SECURITY DEFINER AS
$BODY$
DECLARE
	p	NUMERIC;
	p1	NUMERIC;
	ipnum	VARCHAR(30);
	ipn	NUMERIC;
	host	VARCHAR(30);
	master_owner VARCHAR;
	master_name VARCHAR;
  BEGIN
	master_owner := lower(m_owner);
	master_name := lower(m_name);

	IF (substr(inet_client_addr()::varchar, 1, length(inet_client_addr()::varchar)-3) <> '127.0.0.1') THEN
		-- Let's check if the client IP address is allowed to connect
		SELECT ip INTO host
		FROM public.snapshot_reghosts snt
		WHERE snt.ip=substr(inet_client_addr()::varchar, 1, length(inet_client_addr()::varchar)-3)
			AND snt.mowner=master_owner
			AND snt.mname=master_name;
		IF (host IS NULL) THEN
			RAISE EXCEPTION 'LOGIN_DENIED:H';
		END IF;
		
		-- Valid IP, let's remove dots from IP address and keep each IP part with 3 zero-padded numeric places
		p := 1;
		ipnum := '';
		LOOP
			p1 := strpos(substr(host::text, p::integer), '.');
			IF (p1 > 0) THEN
				p1 := p1 + p::integer - 1;
			END IF;
			IF p1 = 0 THEN
				ipn := substr(host::text, p::integer)::NUMERIC;
			ELSE
				ipn := substr(host::text, p::integer, p1::integer - p::integer)::NUMERIC;
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
$BODY$ LANGUAGE plpgsql;

-- Returns the last refresh that a snapshot did using the snapshot log
CREATE OR REPLACE FUNCTION public.last_log_refresh (
	mowner VARCHAR,
	mname VARCHAR,
	snapshot_id NUMERIC ) RETURNS TIMESTAMP SECURITY DEFINER AS
$BODY$
DECLARE
	lastRefresh TIMESTAMP;
	snap_id	NUMERIC;
	master_owner VARCHAR;
	master_name VARCHAR;
	ipnum VARCHAR;
  BEGIN
	master_owner := lower(mowner);
	master_name := lower(mname);

	ipnum := public.getGrantedIp(master_owner, master_name);
	IF (ipnum = '127000000001') THEN
		snap_id := snapshot_id;
	ELSE
		snap_id := (snapshot_id || ipnum)::NUMERIC;
	END IF;

	SELECT snaptime INTO lastRefresh
	FROM public.pg_mlogs
		INNER JOIN public.pg_slogs ON pg_mlogs.snaplogid=pg_slogs.snaplogid
	WHERE pg_mlogs.masterschema=master_owner 
		AND pg_mlogs.mastername=master_name 
		AND pg_slogs.snapid=snap_id;

	RETURN lastRefresh;
END;
$BODY$ LANGUAGE plpgsql;

-- Returns whether a snapshot log exists or not
CREATE OR REPLACE FUNCTION public.snapshotlog_exists (
	mowner VARCHAR,
	mname VARCHAR ) RETURNS VARCHAR SECURITY DEFINER AS
$BODY$
DECLARE
	total	NUMERIC;
	master_owner VARCHAR;
	master_name VARCHAR;
  BEGIN
	master_owner := lower(mowner);
	master_name := lower(mname);

	SELECT count(*) 
	INTO total
	FROM public.pg_mlogs
	WHERE masterschema=master_owner 
		AND mastername=master_name;

	IF ( total > 0 ) THEN
		EXECUTE 'SELECT 1 from '||master_owner||'.' || public.snapshotlog_name(master_owner, master_name) || ' WHERE 1=0';
		RETURN 'T';
	ELSE
		RETURN 'F';
	END IF;
EXCEPTION
	WHEN OTHERS THEN
		RETURN 'F';
END;
$BODY$ LANGUAGE plpgsql;

-- Returns the snapshot log columns as a CSV
CREATE OR REPLACE FUNCTION public.snapshotlog_columns (
	mowner VARCHAR,
	mname VARCHAR ) RETURNS VARCHAR SECURITY DEFINER AS
$BODY$
DECLARE
	total	NUMERIC;
	sflag	NUMERIC;
	scolumns VARCHAR(2048);
	colsrow	RECORD;
	c_scolumns refcursor;
	master_owner VARCHAR;
	master_name VARCHAR;
  BEGIN
	master_owner := lower(mowner);
	master_name := lower(mname);

	scolumns := '';
	OPEN c_scolumns FOR
		SELECT *
		FROM public.pg_mlog_refcols
		WHERE masterschema=master_owner
			AND mastername=master_name;
	LOOP
		FETCH c_scolumns INTO colsrow;
		IF NOT FOUND THEN
			EXIT;
		END IF;
		scolumns := scolumns || ',' || colsrow.colname;
	END LOOP;
	CLOSE c_scolumns;

	SELECT flag into sflag
	FROM public.pg_mlogs 
	WHERE masterschema=master_owner 
		AND mastername=master_name;

	IF (int4and(sflag::integer, 1::integer) = 1) THEN
		scolumns := scolumns || ',OID';
	END IF;
	RETURN LOWER(SUBSTR(scolumns, 2));
EXCEPTION
	WHEN OTHERS THEN
		RETURN NULL;
END;
$BODY$ LANGUAGE plpgsql;

-- Returns the snapshot log name
CREATE OR REPLACE FUNCTION public.snapshotlog_name (
	mowner VARCHAR,
	mname VARCHAR ) RETURNS VARCHAR SECURITY DEFINER AS
$BODY$
DECLARE
	sname	VARCHAR(256);
	master_owner VARCHAR;
	master_name VARCHAR;
  BEGIN
	master_owner := lower(mowner);
	master_name := lower(mname);

	SELECT log into sname
	FROM public.pg_mlogs 
	WHERE masterschema=master_owner 
		AND mastername=master_name;
	
	RETURN sname;
EXCEPTION
	WHEN OTHERS THEN
		RETURN NULL;
END;
$BODY$ LANGUAGE plpgsql;

-- Returns the number of modified rown on the snapshot log table
CREATE OR REPLACE FUNCTION public.count_log_modified_rows (
	mowner VARCHAR,
	mname VARCHAR,
	last_refresh VARCHAR) RETURNS NUMERIC SECURITY DEFINER AS
$BODY$
DECLARE
	total	NUMERIC;
	master_owner VARCHAR;
	master_name VARCHAR;
	c_dynsql refcursor;
	colsrow	RECORD;
  BEGIN
	master_owner := lower(mowner);
	master_name := lower(mname);

	
	OPEN c_dynsql FOR EXECUTE 'SELECT count(*) as total FROM ' || master_owner || '.' || public.snapshotlog_name(master_owner, master_name) || ' WHERE ((snaptime$$ > TO_TIMESTAMP(' || quote_literal(last_refresh) || ', ''YYYY-MM-DD HH24:MI:SS'')) OR (snaptime$$ IS NULL))';
	FETCH c_dynsql INTO colsrow;
	total := colsrow.total;
	CLOSE c_dynsql;
	
	RETURN total;
END;
$BODY$ LANGUAGE plpgsql;

-- Returns the snapshot log filter for retrieving the snapshot log updated or deleted records
CREATE OR REPLACE FUNCTION public.snapshotlog_ud_filter (
	last_refresh VARCHAR) RETURNS VARCHAR SECURITY DEFINER AS
$BODY$
BEGIN
	RETURN '((snaptime$$ > TO_TIMESTAMP(' || quote_literal(last_refresh) || ',''YYYY-MM-DD HH24:MI:SS'')) OR (snaptime$$ IS NULL))
	AND dmltype$$ IN (''U'', ''D'')';
END;
$BODY$ LANGUAGE plpgsql;

-- Returns the snapshot log filter for retrieving the snapshot log inserted or updated records
CREATE OR REPLACE FUNCTION public.snapshotlog_iu_filter (
	last_refresh VARCHAR) RETURNS VARCHAR SECURITY DEFINER AS
$BODY$
BEGIN
	RETURN '((snaptime$$ > TO_TIMESTAMP(' || quote_literal(last_refresh) || ',''YYYY-MM-DD HH24:MI:SS'')) OR (snaptime$$ IS NULL))
	AND dmltype$$ IN (''I'', ''U'')';
END;
$BODY$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION public.snapshot_do(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.last_log_refresh(VARCHAR, VARCHAR, NUMERIC) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.snapshotlog_exists(VARCHAR, VARCHAR) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.snapshotlog_columns(VARCHAR, VARCHAR) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.snapshotlog_name(VARCHAR, VARCHAR) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.count_log_modified_rows(VARCHAR,VARCHAR,VARCHAR) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.snapshotlog_ud_filter(VARCHAR) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.snapshotlog_iu_filter(VARCHAR) TO PUBLIC;
