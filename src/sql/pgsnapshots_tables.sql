--
-- ATTENTION: This is a free software. 
--            View the LICENSE.txt file for license information
--

CREATE SCHEMA %BASE_SCHEMA%;
GRANT USAGE ON SCHEMA %BASE_SCHEMA% TO PUBLIC;

CREATE ROLE "snapshot.users";

------------------------------------------------------------------------------
-- TABLE: %BASE_SCHEMA%.pg_dblinks
--
-- Table that will hold the DBLINK connection info
-- Only visible to the 'postgres' user
------------------------------------------------------------------------------
CREATE TABLE %BASE_SCHEMA%.pg_dblinks (
	dblinkid	serial,
	dblinkname	text,
	datasource	text,
	username	text,
	password	text,
	attributes	text,
	ctime		timestamp DEFAULT now(),
	CONSTRAINT pg_dblink_pk PRIMARY KEY (dblinkid)
);
CREATE UNIQUE INDEX pg_dblinks_uix ON %BASE_SCHEMA%.pg_dblinks(dblinkname);
REVOKE ALL PRIVILEGES ON TABLE %BASE_SCHEMA%.pg_dblinks FROM PUBLIC;
COMMENT ON TABLE %BASE_SCHEMA%.pg_dblinks IS
$$
This table contains the necessary connection information for a DBI
connection.
$$;

------------------------------------------------------------------------------
-- TABLE: %BASE_SCHEMA%.pg_snapshots
--
-- Table that will hold the SNAPSHOT info
------------------------------------------------------------------------------
CREATE TABLE %BASE_SCHEMA%.pg_snapshots (
	snapid		serial,
	schemaname	text not null,
	snapshotname	text not null,
	query           text not null,
	dblinkid	bigint,
	ctime		timestamp default now(),
	snaptime	timestamp,
	elapsedtime	interval,
	auto_time	time,
	auto_interval	interval,
	kind		char(1) check (kind in ('F', 'C', 'R')) default 'R', --F=FAST C=COMPLETE R=FORCE
	pbt_table	text, -- ON PREBUILT TABLE (prebuilt table name)
	CONSTRAINT pg_snapshots_pk primary key (snapid),
	CONSTRAINT pg_snapshots_dblinks_fk foreign key (dblinkid) references %BASE_SCHEMA%.pg_dblinks(dblinkid) ON UPDATE RESTRICT ON DELETE RESTRICT
);
CREATE UNIQUE INDEX pg_snapshots_uix ON %BASE_SCHEMA%.pg_snapshots(schemaname, snapshotname);
CREATE INDEX pg_snapshots_1_ix ON %BASE_SCHEMA%.pg_snapshots(schemaname, pbt_table);
GRANT select ON %BASE_SCHEMA%.pg_snapshots to public;
COMMENT ON TABLE %BASE_SCHEMA%.pg_snapshots IS
$$
This table contains the list of snapshots on your system a the
query/dblink used to create it and to fill it up.
$$;

------------------------------------------------------------------------------
-- TABLE: %BASE_SCHEMA%.pg_mlogs
--
-- Table that will hold the SNAPSHOT LOG info
------------------------------------------------------------------------------
CREATE TABLE %BASE_SCHEMA%.pg_mlogs (
	snaplogid	serial,
	masterschema	text NOT NULL,
	mastername	text NOT NULL,
	flag		numeric NOT NULL,
	log		text NOT NULL,
	CONSTRAINT pg_mlogs_pk PRIMARY KEY (snaplogid)
);
CREATE UNIQUE INDEX pg_mlogs_uix ON %BASE_SCHEMA%.pg_mlogs(masterschema, mastername);
GRANT select ON %BASE_SCHEMA%.pg_mlogs to public;
COMMENT ON TABLE %BASE_SCHEMA%.pg_mlogs IS
$$
This table contains the list of snapshot logs.
$$;

------------------------------------------------------------------------------
-- TABLE: %BASE_SCHEMA%.pg_mlog_refcols
--
-- Table that will hold the SNAPSHOT LOG columns info
------------------------------------------------------------------------------
CREATE TABLE %BASE_SCHEMA%.pg_mlog_refcols (
	snaplogid	bigint,
	masterschema	text NOT NULL,
	mastername	text NOT NULL,
	colname		text NOT NULL,
	oldest		timestamp NOT NULL DEFAULT now(),
	flag		numeric(1),
	CONSTRAINT pg_mlog_refcols_pk PRIMARY KEY (snaplogid, colname),
	CONSTRAINT pg_mlog_refcols_mlog_fk FOREIGN KEY (snaplogid) REFERENCES %BASE_SCHEMA%.pg_mlogs(snaplogid) ON DELETE CASCADE
);
CREATE UNIQUE INDEX pg_mlog_refcols_uix ON %BASE_SCHEMA%.pg_mlog_refcols(masterschema, mastername, colname);
GRANT select ON %BASE_SCHEMA%.pg_mlog_refcols to public;
COMMENT ON TABLE %BASE_SCHEMA%.pg_mlog_refcols IS
$$
This table contains the list of snapshot logs.
$$;

------------------------------------------------------------------------------
-- TABLE: %BASE_SCHEMA%.pg_slogs
--
-- Table that will hold the SNAPSHOT LOG refresh info
------------------------------------------------------------------------------
CREATE TABLE %BASE_SCHEMA%.pg_slogs (
	snaplogid	bigint,
	snapid		bigint,
	snaptime	timestamp not null,
	userid		int4 not null,
	CONSTRAINT pg_slogs_pk primary key (snaplogid, snapid),
	CONSTRAINT pg_slogs_mlog_fk FOREIGN KEY (snaplogid) REFERENCES %BASE_SCHEMA%.pg_mlogs(snaplogid) ON DELETE CASCADE
);
CREATE UNIQUE INDEX pg_slogs_ix_1 on %BASE_SCHEMA%.pg_slogs(snapid, snaplogid);
CREATE UNIQUE INDEX pg_slogs_ix_2 on %BASE_SCHEMA%.pg_slogs(snapid, snaptime, snaplogid);
CREATE UNIQUE INDEX pg_slogs_ix_3 on %BASE_SCHEMA%.pg_slogs(snaplogid, snaptime, snapid);
GRANT select ON %BASE_SCHEMA%.pg_slogs to public;
COMMENT ON TABLE %BASE_SCHEMA%.pg_slogs IS
$$
This table contains the list of master tables that have snapshot logs and are referenced by snapshots elsewhere. This table, along with the master table log, allows fast refreshes of snapshots based on snapshot logs.
$$;
