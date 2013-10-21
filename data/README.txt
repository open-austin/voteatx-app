= VoteATX Database Generation

The VoteATX database has the following key tables:

  * voting_places - A voting place of any kind (early, mobile, election
    day) for this election.

    * voting_locations - A location where a voting place is.

    * voting_schedules - A schedule of hours for a voting place.

      * voting_schedule_entries - The open and close times for a single day in a schedule.

  * voting_districts - Boundaries of all the voting precincts.

  * election_defs - Defintions to customize results for this election.

The database is generated from two sets of data:

  * voting districts - A GIS "shape" file that defines the boundaries
    of all the voting districts.

  * voting places - A collection of spreadsheets that list the voting places.

The source data are organized into directories:

  * data/voting-districts/<YEAR> - Voting districts published at the indicated time.

  * data/voting-places/<YYYYMMDD> - Voting place information for the
    election on the indicated date.

To generate the database:

  * cd into the "data/voting-places/<YYYYMMDD>" directory.

  * run: sh ../create_db.sh voteatx.db

  * symlink the resulting "voteatx.db" file into the top-level directory of the project


NOTE: This procedure works only for directories that have a "generate.rb" script.

NOTE: The database format was changed for the 20131105 election. The current application
will not work with earlier databases.

TODO: Document process of setting up "voting places" for a new election.

