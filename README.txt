If you want the Oracle's materialized views on PostgreSQL, this is your
project. It was based and inspired by the DBI-Link project.

PostgreSQL::Snapshots requires PostgreSQL 8.0 or better, and has been tested with Perl 5.8.5.  Backports to older versions of PostgreSQL are unlikely, and earlier versions of Perl only if there is an excellent reason.

This first release is fully functional and implements snapshots between two
PostgreSQL databases and between a PostgreSQL database and an Oracle database.

The next milestone will implement automatic refresh based on intervals.
 
