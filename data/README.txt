==== VoteATX Database Generation ===

--- Overview of Database Tables ---

The VoteATX database has the tables:

  * voting_places - A voting place of any kind (early, mobile, election
    day) for this election. This is the table searched to find places
    to vote.

  * voting_locations - A location where a voting place is.
    "voting_places.location_id" is a foreign key into this table.

  * voting_schedules - A schedule of hours for a voting place.
    "voting_places.schedule_id" is a foreign key into this table.

  * voting_schedule_entries - The line item details for a voting
    schedule. Each row is the open and close times for a single day
    in a schedule.  The "schedule_id" column is a foreign key into the
    "voting_schedules" table.

  * voting_districts - Boundaries of all the voting precincts.
    This is made from a completely separate data source: the geospatial
    "shape" file of voting districts. This is used to locate the precinct
    number for a given location (longitude/latitude).

  * election_defs - Defintions to customize results for this election
    are stored here. The app should not require changes when updating
    to a new election. The information that might change, such as the
    election description, is stored here.

The database is generated from two sets of data:

  voting districts

    The Travis County Clerk has provided a spreadsheet with three tables,
    one each for the various voting place types (election day, early
    fixed, early mobile). We manually convert them to individual CSV
    files, and then use a loader utility to load the voting place table.

    This information is in the "data/voting-districts/YYYY" subdirectory,
    where "YYYY" is the year in which the voting districts were drawn.

  voting places

    The Travis County Tax Acessor-Collector office has provided a
    geospatial "shape" file that defines the boundaries of all the
    voting districts. We use "spatialite_tool" to load the SHP file
    into the database.

    This information is in the "data/voting-places/YYYYMMDD" subdirectory,
    where "YYYYMMDD" is the data of the election.


--- How to Create the Database ---

This procedure works only for voting-places subdirectories that contain a
"generate.rb" script. (20121106 and later)

  * cd into the "data/voting-places/YYYYMMDD" directory.

  * run: sh ../create_db.sh voteatx.db

  * cd back to the top-level project directory

  * run: ln -s data/voting-places/YYYYMMDD/voteatx.db


--- How to Setup Database for a New Election ---

Here is the process I use to setup the data for a new election.

  * Create a "data/voting-places/YYYYMMDD" directory. That's where all the
    files will be created and work will be stored.

  * Contact the Travis County Clerk's Elections Division
    (elections@co.travis.tx.us) in advance of the election to get a copy
    of the voting places dataset.

  * In the past, the dataset has been provided to me as an XLSX
    spreadsheet with three sheets, one for each voting place type.
    Manually export each sheet to a CSV file.

  * I've found I've had to do some data cleanup, so I recommend making
    a copy of each CSV (with ".csv.orig" filetype) for reference purposes.

  * Copy the "generate.rb" script from the most recent election to this
    directory.

  * Tailor the "generate.rb" script for this election. See the comments
    in the script for additional information.

  * Run the "create_db.sh" script, as described above.

  * Make corrections to the data ("CSV" files) as needed, and re-run
    the creation script.


--- Problems and Feedback ---

If you encounter any difficulties or have any feedback, please use the
issue tracker:

https://github.com/chip-rosenthal/voteatx/issues

--
Chip Rosenthal
chip@unicom.com
