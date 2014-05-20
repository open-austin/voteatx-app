#!/usr/bin/env -- ruby

require 'rubygems'
require 'bundler'
Bundler.setup
require "#{Bundler.root}/lib/voteatx/loader.rb"

raise "usage: #{$0} database\n" unless ARGV.length == 1
dbname = ARGV[0]
raise "database file \"#{dbname}\" already exists\n" if File.exist?(dbname)

VoteATX::VotingDistrictsLoader.load(
	:database => dbname,
       	:table => "voting_districts",
       	:shp_defs => "../../voting-districts/2012/loader.defs",
	:log => @log
)

loader = VoteATX::VotingPlacesLoader.new(dbname, :log => @log, :debug => false)


#####
#
# A one-line description of the election
#
# Example: "for the Nov 5, 2013 general election in Travis County"
#
# In the VoteATX app this is displayed below the title of the
# voting place (e.g. "Precinct 31415").
#

loader.election_description = "for the Mar 27, 2014 primary run-off election in Travis County"


#####
#
# Additional information about the election.
#
# This is included near the bottom of the info window that is
# opened up for a voting place. Full HTML is supported. Line
# breaks automatically inserted.
#
# This would be a good place to put a link to the official
# county voting page for this election.
#

loader.election_info = %q{<b>Note:</b> Voting centers are in effect for this election.  That means on election day you can vote at <em>any</em> open Travis County polling place, not just your home precinct.

<i>(<a href="http://www.traviscountyclerk.org/eclerk/Content.do?code=E.4">more information ...</a>)</i>}


#####
#
# Hours voting places are open on election day.
#
# Define this as a range:  Time .. Time
#

# May 27, 2014 7am-7pm
ELECTION_DAY_HOURS = Time.new(2014, 5, 27, 7, 0) .. Time.new(2014, 5, 27, 19, 0)


#####
#
# Hours for the fixed early voting places, indexed by schedule code.
#
# The fixed early voting places spreadsheet has a column with a schedule
# code that identifies the schedule for that place.
#
# Define this as a map of schedule code to a list of open..close time ranges.
#

# EARLY VOTING LOCATIONS for the
# May 27, 2014 Joint Primary Runoff Election
# Monday, May 19 through Friday, May 23
EARLY_VOTING_FIXED_HOURS = {

  # Mon – Fri 7 a.m. to 7 p.m.
  'R' => [
    Time.new(2014,  5, 19,  7,  0) .. Time.new(2014,  5, 19, 19,  0), # Mo
    Time.new(2014,  5, 20,  7,  0) .. Time.new(2014,  5, 20, 19,  0), # Tu
    Time.new(2014,  5, 21,  7,  0) .. Time.new(2014,  5, 21, 19,  0), # We
    Time.new(2014,  5, 22,  7,  0) .. Time.new(2014,  5, 22, 19,  0), # Th
    Time.new(2014,  5, 23,  7,  0) .. Time.new(2014,  5, 23, 19,  0), # Fr
  ],

  # Mon - Thu 10 a.m. – 7 p.m., Fri Closed
  'V|Carver Library and Museum Complex' => [
    Time.new(2014,  5, 19, 10,  0) .. Time.new(2014,  5, 19, 19,  0), # Mo
    Time.new(2014,  5, 20, 10,  0) .. Time.new(2014,  5, 20, 19,  0), # Tu
    Time.new(2014,  5, 21, 10,  0) .. Time.new(2014,  5, 21, 19,  0), # We
    Time.new(2014,  5, 22, 10,  0) .. Time.new(2014,  5, 22, 19,  0), # Th
    Time.new(2014,  5, 23,  0,  0) .. Time.new(2014,  5, 23,  0,  0), # Fr (closed)
  ],

  # Mon – Thu 10 a.m. – 7 .p.m., Fri Closed
  'V|Dan Ruiz Public Library' => [
    Time.new(2014,  5, 19, 10,  0) .. Time.new(2014,  5, 19, 19,  0), # Mo
    Time.new(2014,  5, 20, 10,  0) .. Time.new(2014,  5, 20, 19,  0), # Tu
    Time.new(2014,  5, 21, 10,  0) .. Time.new(2014,  5, 21, 19,  0), # We
    Time.new(2014,  5, 22, 10,  0) .. Time.new(2014,  5, 22, 19,  0), # Th
    Time.new(2014,  5, 23,  0,  0) .. Time.new(2014,  5, 23,  0,  0), # Fr (closed)
  ],

  # Mon – Thu 9 a.m. – 7 p.m., Fri 9 a.m. – 6 p.m.
  'V|Gus Garcia Recreation Center' => [
    Time.new(2014,  5, 19,  9,  0) .. Time.new(2014,  5, 19, 19,  0), # Mo
    Time.new(2014,  5, 20,  9,  0) .. Time.new(2014,  5, 20, 19,  0), # Tu
    Time.new(2014,  5, 21,  9,  0) .. Time.new(2014,  5, 21, 19,  0), # We
    Time.new(2014,  5, 22,  9,  0) .. Time.new(2014,  5, 22, 19,  0), # Th
    Time.new(2014,  5, 23,  9,  0) .. Time.new(2014,  5, 23, 18,  0), # Fr
  ],

  # Mon – Wed 10 a.m. – 7 p.m., Thu Closed, Fri 10 a.m. – 5:30 p.m.
  'V|Howson Branch Library' => [
    Time.new(2014,  5, 19, 10,  0) .. Time.new(2014,  5, 19, 19,  0), # Mo
    Time.new(2014,  5, 20, 10,  0) .. Time.new(2014,  5, 20, 19,  0), # Tu
    Time.new(2014,  5, 21, 10,  0) .. Time.new(2014,  5, 21, 19,  0), # We
    Time.new(2014,  5, 22,  0,  0) .. Time.new(2014,  5, 22,  0,  0), # Th (closed)
    Time.new(2014,  5, 23, 10,  0) .. Time.new(2014,  5, 23, 17, 30), # Fr
  ],

  # Mon – Thu 11 a.m. – 7 p.m., Fri 11 a.m. – 6 p.m.
  'V|Parque Zaragoza Recreation Center' => [
    Time.new(2014,  5, 19, 11,  0) .. Time.new(2014,  5, 19, 19,  0), # Mo
    Time.new(2014,  5, 20, 11,  0) .. Time.new(2014,  5, 20, 19,  0), # Tu
    Time.new(2014,  5, 21, 11,  0) .. Time.new(2014,  5, 21, 19,  0), # We
    Time.new(2014,  5, 22, 11,  0) .. Time.new(2014,  5, 22, 19,  0), # Th
    Time.new(2014,  5, 23, 11,  0) .. Time.new(2014,  5, 23, 18,  0), # Fr
  ],

  # Mon – Fri 8 a.m. to 7 p.m.
  'V|Wheatsville Food Co-op' => [
    Time.new(2014,  5, 19,  8,  0) .. Time.new(2014,  5, 19, 19,  0), # Mo
    Time.new(2014,  5, 20,  8,  0) .. Time.new(2014,  5, 20, 19,  0), # Tu
    Time.new(2014,  5, 21,  8,  0) .. Time.new(2014,  5, 21, 19,  0), # We
    Time.new(2014,  5, 22,  8,  0) .. Time.new(2014,  5, 22, 19,  0), # Th
    Time.new(2014,  5, 23,  8,  0) .. Time.new(2014,  5, 23, 19,  0), # Fr
  ],

}


#####
#
# Some definitions used for input validation.
#

loader.valid_lng_range = -98.057163 .. -97.383048
loader.valid_lat_range = 30.088999 .. 30.572025
loader.valid_zip_regexp = /^78[67]\d\d$/


#####
#
# Perform the load.
#

loader.create_tables
loader.load_eday_places("20140527_PR14_Webload_FINAL_EDay.csv", ELECTION_DAY_HOURS)
loader.load_evfixed_places("20140527_PR14_Webload_FINAL_EVPerm.csv", EARLY_VOTING_FIXED_HOURS)
loader.load_evmobile_places("20140527_PR14_Webload_FINAL_Mobile.csv")
loader.log.info("done")

