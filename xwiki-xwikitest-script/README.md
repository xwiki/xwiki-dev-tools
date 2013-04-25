# XWiki Test Scripts

This BASH script ease the deployment of any released (including snapshot)
jetty distributions directly from the XWiki Maven repository for the purpose
of testing. It automate all the tasks to get any XWiki version properly
running with any of the supported database in couple of second. It avoid any
human mistake during deployment, allowing quick discovering of potential
regression. It also aims simplifying developers and testers life, isolating
them from the syntax and constraints imposed by the different databases, 
allowing easy and uniform dump/restore procedure for repetive testing tasks.

This script can automate the following steps:

* Download a distribution package, either release or snapshot (using a jetty
based distrbution)
* Deploy that package, and configure it for any supported database
* Cleanup/Create the needed database, user and grants
* Restore a saved permanent directory
* Import a database dump (previously exported with this same tool)
* Launch the configured XWiki under Jetty
* Backup the database and/or the permanent directory after XWiki shutdown

All operations could be done in a multiuser environment, using common databases, 
without getting conflicting users, databases, ports, ...

## Requirements

This script does not provide any help preparing a test machine, and you will 
need a working test configuration to use it fully. It require a linux machine 
with MySQL, PostgreSQL and Oracle databases properly deployed and configured.

At the very beginning of this script, there is configuration section that 
should be setup to match your existing configuration. The default value are
setup for a properly configured Ubuntu 12.04 server, with Oracle deployed in
`/opt/oracle`, and other database deployed by APT. The Oracle JDBC driver and
the MySQL ConnectorJ driver should be made available in a shared folder, 
which default to `/usr/local/shared/java`. For MySQL MyISAM to work properly
on MySQL 5.x, a `MySQL5MyISAMDialect` class should be custom made, and provided
in the same shared folder, as a `.class` file.

## Usage

While this script provide tons of options, it is really easy to use and usual
command-line are simple and repetitive. The script always proceed to the
same steps in the same other, and skip uneeded steps depending on choosen 
options.

The steps are:

 1. Check that the requested test is not already running. A `xwiki.lck` file is
    store in the deployment folder during execution. In case of abnormal
    shutdown, you may need to delete it manually.

 2. Download into the current working folder the archive required
    based on `-e`, `-f`, `-r` and `-v`. Skipped unless `-w` is used and the
    archive is not yet available locally. When skipped, the archive must be
    available locally, or the script will halt. The archive came from
    `maven.xwiki.org`, and is a jetty based distribution.

 3. Unzip the archive in a subfolder of the current working folder. Remove
    the permanent directory if hsqldb package is used for testing another DB.
    This step is skipped if `-z`, `-B`, `-I`, `-L` or `-U` is used.

 4. Restore the permanent directory when `-l` or `-L` is used.

 5. Delete any old database with the current database prefixe (`-s`) available 
    in the chosen database engine (`-d`). Then, create the main wiki database, 
    the xwiki user, and grants required privileges.
    This step is skipped if `-k`, `-B`, `-L` or `-U` is used.

 6. Import the provided database backup when `-i` or `-I` is used.

 7. Configure the requested database in `hibernate.cfg.xml`, and copy the 
    required driver (and dialect for MySQL MyISAM) to the deployment folder.
    Configure the database prefix, and main database name in `xwiki.cfg`.
    Activate the snapshot repository for extension when a snapshot release
    is used in `xwiki.properties`.
    This step is skipped for HSQLDB database or if `-z`, `-B`, `-I`, `-L` or `-U`
    is used.

 8. Start the jetty server, waiting for CTRL-C or another signal to stop it.
    This step is skipped if `-n`, `-B`, `-I`, `-L` or `-U` is used.

 9. Dump all database with the current database prefixe (`-s`) when `-b` or
    `-B` is used. Save the permanent data directory (excluding the HSQLDB)
    if `-u` or `-U` is used.

Almost all option combination is possible. The last option overide any earlier
conflicting options.

## Examples

    xwikitest

If the package is available locally, configure and run the default version
(currently XE 4.5.3) using the jetty-hsqldb package for a MySQL innoDB 
database. If the package is not available, fails with an error and usage
message.

    xwikitest -v 5.0-rc-1 -d oracle -w

The package jetty-hsqldb of XE 5.0RC1 is downloaded as needed, deployed and 
run immediately in a matter of second with a fresh empty oracle database.

    xwikitest -v 3.5.1 -d psql -e manager -w -b psql351.sql -u psql351.zip

The package jetty-mysql of XEM 3.5.1 is downloaded as needed, deployed and
run with a fresh empty PostgreSQL database. Once the jetty server is halted
using CTRL-C, the database, and the permanent directory are saved.

    xwikitest -v 5.0-milestone-2 -d psql -e manager -w -i psql351.sql -l psql351.zip

The package jetty-mysql of XEM 5.0M2 is downloaded as needed, deployed, the
previously saved 3.5.1 database, and permanent directory are restored, than
XWiki is run, which on first request will test a migration from 3.5.1 to 5.0M2.

    xwikitest -v 5.0-milestone-2 -d mysql -e manager -B psql5M2.sql

The current databases in MySQL are dumped. This will fail if the XEM 5.0M2 is not
available, but will proceed even if the databases are not 5.0M2 version.

    xwikitest -v 5.0-milestone-2 -d mysql -e manager -U psql351.zip

The current permanent directory in the deployed XEM 5.0M2 will be saved.

    xwikitest -v 5.1 -r 20130423.165616-8 -d hsqldb -w -i hsqldb351.zip -b hsqldb51.zip

The package jetty-hsqldb of a snapshot of XE 5.1 will downloaded as needed,
deployed and run on a previously backup HSQLDB database (probably from release
3.5.1 according to the name) and a migration will occurs on first request. At 
jetty server termination, the resulting database will backup. Note that the 
permanent directory will be left as in the 5.1 package, and in this example 
may cause the distribution wizard to think that it should not to appear.
A better test would be to also restore a permanent directory. This only happen
with jetty-hsqldb package or the HSQLDB database, since for other database
the permanent directory is at least discarded.

## Command-line options

 * `-b destination`

   Backup database to the given `destination` just before ending this script.
   Depending on the database, `destination` is either a sql filename (mysql,
   psql), a zip filename (hsqldb), or a folder name (oracle). The name is 
   relative to the working folder, and the file will be erased just before
   starting the backup.

 * `-B destination`

   Backup current database to the given `destination`. This option works
   exactly like `-b`, and is a shortcut for `-knzb destination`.

 * `-d database`

   The target database, could be any of

   * `mysql-myisam`: MySQL server using MyISAM engine
   * `mysql` or `mysql-innodb`: MySQL server using innoDB engine
   * `postgresql` or `psql`: PostgreSQL single database (using schema mode)
   * `oracle` or `ora`: Oracle (> 10g)
   * `hsqldb`: HSQLDB

   The default is to use MySQL innoDB engine.

 * `-e distribution`

   The XWiki distribution (enterprise or manager). The default is to
   use the enterprise distribution.

 * `-f package`

   The jetty distribution base package (hsqldb or mysql). The default is to
   use the hsqldb package for the enterprise distribution, and the mysql package
   for the manager distribution. Except for HSQLDB, which require an hsqldb
   package, any available package will do, and will be reconfigured for the
   target database.

 * `-i source`

   Import the given `source` dump into the database before starting XWiki.
   Depending on the database, `source` is either a sql filename (mysql,
   psql), a zip filename (hsqldb), or a folder name (oracle). The name is
   relative to the working folder, and the file will only be imported if it is
   found and readable. The `source` should have been produce by this same tools
   using the `-b` option, but it could be done with a different release of
   XWiki, which allows testing migration procedure repetitively.

 * `-I source`

   Only import the given `source` in the database without running XWiki.
   This option works like `-i` and is a shortcut for `-nzi`.

 * `-h`

   Display an help message describing the usage of this script. At the end of
   most options, it also shows the current values of these options. It could
   be used as a dry run solution for beginners.

 * `-k`

   Prevent the automatic cleaning of the database, keeping the current
   database AS IS. This could use after a initial run to start the same
   or a later XWiki release on the same database.

 * `-l data.zip`

   Restore a backup of the permanent directory from the given zip file. The name
   of the zip file is taken relatively to the current working folder. The file
   should have been created earlier by using the '-u' option. The HSQLDB 
   database is excluded from this operation, and is preserved for HSQLDB 
   database tests.

 * `-L data.zip`

   Only restore a backup of the permanent directory without running XWiki.
   This option works like `-L and is a shortcut for `-nkzl data.zip`.

 * `-n`

   Do not run XWiki, only deploy as request, and proceed to other steps like
   import, export, ...

 * `-p port`

   Port number on which the Jetty web server will be listening for HTTP requests.
   Unless specified, this port is automatically chosen based on your user UID,
   which avoid any collision with other users on the same host. The listening is
   only done on localhost loopback interface, and could be forwarded throught
   SSH using -L<port>:localhost:<port>.

 * `-r snapshot`

   The target snapshot release number (ie: 20120410.161114-97). If specified, a
   snapshot version will be retrived and deployed in a version-SNAPSHOT folder.

 * `-s dbsuffix`

   This name is appended to the default `xwiki` name to create the prefix of all
   databased created for the current test. The default is to take your username.
   This is needed to avoind database name collision in a multiuser environment.
   It could also be use to keep differents test databases for the same user in
   the same database engine.

 * `-t port`

   Port number used by Jetty for its control chanel, allowing its termination.
   Unless specified, this port is automatically chosen based on your user UID.

 * `-u data.zip`

   Save a backup of the permanent directory into the given zip file just before
   ending this script. The zip filename is relative to the current working
   folder and the file will be erased just before starting the backup. The
   resulting file could be used with `-l` to restore the current data folder in
   another run of this version or a later release version 

 * `-U data.zip`

   Save a backup of the current permanent directory. This option works like `-u`
   and is a shortcut for `-nkzu data.zip`.

 * `-v version`

   The target XWiki version for this test (ie: 4.5.3). It defaults to 4.5.3.

 * `-w`

   Allow downloading the needed archive from maven.xwiki.org. If this option is
   not specified, the needed archive should be available in the current working
   folder, else this script will end immediately.

 * `-z`

   Do not redeploy and reconfigure. A previously deployed XWiki with the exact
   same version should be available and will be used. No check of compatibility
   with the current option is done. You should use this option with care.

