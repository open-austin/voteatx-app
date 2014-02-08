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

loader.election_description = "for the Mar 4, 2014 joint primary election in Travis County"


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

# Mar 4, 2014 7am-7pm
ELECTION_DAY_HOURS = Time.new(2014, 3, 4, 7, 0) .. Time.new(2014, 3, 4, 19, 0)


#####
#
# Hours for the fixed early voting places, indexed by schedule code.
#
# The fixed early voting places spreadsheet has a column with a schedule
# code that identifies the schedule for that place.
#
# Define this as a map of schedule code to a list of open..close time ranges.
#

# Tue, Feb 18 - Fri, Feb 28
EARLY_VOTING_FIXED_HOURS = {

  # Mon-Sat 7am-7pm, Sun noon-6pm
  'R' => [
    Time.new(2014,  2, 18,  7,  0) .. Time.new(2014,  2, 18, 19,  0), # Tu
    Time.new(2014,  2, 19,  7,  0) .. Time.new(2014,  2, 19, 19,  0), # We
    Time.new(2014,  2, 20,  7,  0) .. Time.new(2014,  2, 20, 19,  0), # Th
    Time.new(2014,  2, 21,  7,  0) .. Time.new(2014,  2, 21, 19,  0), # Fr
    Time.new(2014,  2, 22,  7,  0) .. Time.new(2014,  2, 22, 19,  0), # Sa
    Time.new(2014,  2, 23, 12,  0) .. Time.new(2014,  2, 23, 18,  0), # Su
    Time.new(2014,  2, 24,  7,  0) .. Time.new(2014,  2, 24, 19,  0), # Mo
    Time.new(2014,  2, 25,  7,  0) .. Time.new(2014,  2, 25, 19,  0), # Tu
    Time.new(2014,  2, 26,  7,  0) .. Time.new(2014,  2, 26, 19,  0), # We
    Time.new(2014,  2, 27,  7,  0) .. Time.new(2014,  2, 27, 19,  0), # Th
    Time.new(2014,  2, 28,  7,  0) .. Time.new(2014,  2, 28, 19,  0), # Fr
  ],

  # Mon - Wed 10 a.m.-5:30 p.m., Thu 10 a.m.- 7 p.m., Fri 10 a.m.-4:30 p.m., Sat 10 a.m. – 3:30 p.m., Sun Closed 
  'V|Carver Library and Museum Complex' => [
    Time.new(2014,  2, 18, 10,  0) .. Time.new(2014,  2, 18, 17, 30), # Tu
    Time.new(2014,  2, 19, 10,  0) .. Time.new(2014,  2, 19, 17, 30), # We
    Time.new(2014,  2, 20, 10,  0) .. Time.new(2014,  2, 20, 19,  0), # Th
    Time.new(2014,  2, 21, 10,  0) .. Time.new(2014,  2, 21, 16, 30), # Fr
    Time.new(2014,  2, 22, 10,  0) .. Time.new(2014,  2, 22, 15, 30), # Sa
    Time.new(2014,  2, 23,  0,  0) .. Time.new(2014,  2, 23,  0,  0), # Su (closed)
    Time.new(2014,  2, 24, 10,  0) .. Time.new(2014,  2, 24, 17, 30), # Mo
    Time.new(2014,  2, 25, 10,  0) .. Time.new(2014,  2, 25, 17, 30), # Tu
    Time.new(2014,  2, 26, 10,  0) .. Time.new(2014,  2, 26, 17, 30), # We
    Time.new(2014,  2, 27, 10,  0) .. Time.new(2014,  2, 27, 19,  0), # Th
    Time.new(2014,  2, 28, 10,  0) .. Time.new(2014,  2, 28, 16, 30), # Fr
  ],

  # Mon – Thu 10 a.m. – 7 p.m., Fri Closed, Sat 10 a.m. – 4:30 p.m., Sun 2 p.m. – 5:30 p.m. 
  'V|Dan Ruiz Public Library' => [
    Time.new(2014,  2, 18, 10,  0) .. Time.new(2014,  2, 18, 19,  0), # Tu
    Time.new(2014,  2, 19, 10,  0) .. Time.new(2014,  2, 19, 19,  0), # We
    Time.new(2014,  2, 20, 10,  0) .. Time.new(2014,  2, 20, 19,  0), # Th
    Time.new(2014,  2, 21,  0,  0) .. Time.new(2014,  2, 21,  0,  0), # Fr (closed)
    Time.new(2014,  2, 22, 10,  0) .. Time.new(2014,  2, 22, 16, 30), # Sa
    Time.new(2014,  2, 23, 14,  0) .. Time.new(2014,  2, 23, 17, 30), # Su
    Time.new(2014,  2, 24, 10,  0) .. Time.new(2014,  2, 24, 19,  0), # Mo
    Time.new(2014,  2, 25, 10,  0) .. Time.new(2014,  2, 25, 19,  0), # Tu
    Time.new(2014,  2, 26, 10,  0) .. Time.new(2014,  2, 26, 19,  0), # We
    Time.new(2014,  2, 27, 10,  0) .. Time.new(2014,  2, 27, 19,  0), # Th
    Time.new(2014,  2, 28,  0,  0) .. Time.new(2014,  2, 28,  0,  0), # Fr (closed)
  ],

  # Mon – Thu 9 a.m. – 7 p.m., Fri 9 a.m. – 6 p.m., Sat 9 a.m. – 4 p.m., Sunday Closed
  'V|Gus Garcia Recreation Center' => [
    Time.new(2014,  2, 18,  9,  0) .. Time.new(2014,  2, 18, 19,  0), # Tu
    Time.new(2014,  2, 19,  9,  0) .. Time.new(2014,  2, 19, 19,  0), # We
    Time.new(2014,  2, 20,  9,  0) .. Time.new(2014,  2, 20, 19,  0), # Th
    Time.new(2014,  2, 21,  9,  0) .. Time.new(2014,  2, 21, 18,  0), # Fr
    Time.new(2014,  2, 22,  9,  0) .. Time.new(2014,  2, 22, 16,  0), # Sa
    Time.new(2014,  2, 23,  0,  0) .. Time.new(2014,  2, 23,  0,  0), # Su (closed)
    Time.new(2014,  2, 24,  9,  0) .. Time.new(2014,  2, 24, 19,  0), # Mo
    Time.new(2014,  2, 25,  9,  0) .. Time.new(2014,  2, 25, 19,  0), # Tu
    Time.new(2014,  2, 26,  9,  0) .. Time.new(2014,  2, 26, 19,  0), # We
    Time.new(2014,  2, 27,  9,  0) .. Time.new(2014,  2, 27, 19,  0), # Th
    Time.new(2014,  2, 28,  9,  0) .. Time.new(2014,  2, 28, 18,  0), # Fr
  ],

  # Mon – Wed 10 a.m. – 7 p.m., Thu Closed, Fri 10 a.m. – 5:30 p.m., Sat 10 a.m. – 4:30 p.m., Sun Closed
  'V|Howson Branch Library' => [
    Time.new(2014,  2, 18, 10,  0) .. Time.new(2014,  2, 18, 19,  0), # Tu
    Time.new(2014,  2, 19, 10,  0) .. Time.new(2014,  2, 19, 19,  0), # We
    Time.new(2014,  2, 20,  0,  0) .. Time.new(2014,  2, 20,  0,  0), # Th (closed)
    Time.new(2014,  2, 21, 10,  0) .. Time.new(2014,  2, 21, 17, 30), # Fr
    Time.new(2014,  2, 22, 10,  0) .. Time.new(2014,  2, 22, 16, 30), # Sa
    Time.new(2014,  2, 23,  0,  0) .. Time.new(2014,  2, 23,  0,  0), # Su (closed)
    Time.new(2014,  2, 24, 10,  0) .. Time.new(2014,  2, 24, 19,  0), # Mo
    Time.new(2014,  2, 25, 10,  0) .. Time.new(2014,  2, 25, 19,  0), # Tu
    Time.new(2014,  2, 26, 10,  0) .. Time.new(2014,  2, 26, 19,  0), # We
    Time.new(2014,  2, 27,  0,  0) .. Time.new(2014,  2, 27,  0,  0), # Th (closed)
    Time.new(2014,  2, 28, 10,  0) .. Time.new(2014,  2, 28, 17, 30), # Fr
  ],

  # Mon – Thu 11 a.m. – 7 p.m., Fri 11 a.m. – 6 p.m., Sat 11 a.m. – 5 p.m., Sun Closed
  'V|Parque Zaragoza Recreation Center' => [
    Time.new(2014,  2, 18, 11,  0) .. Time.new(2014,  2, 18, 19,  0), # Tu
    Time.new(2014,  2, 19, 11,  0) .. Time.new(2014,  2, 19, 19,  0), # We
    Time.new(2014,  2, 20, 11,  0) .. Time.new(2014,  2, 20, 19,  0), # Th
    Time.new(2014,  2, 21, 11,  0) .. Time.new(2014,  2, 21, 18,  0), # Fr
    Time.new(2014,  2, 22, 11,  0) .. Time.new(2014,  2, 22, 17,  0), # Sa
    Time.new(2014,  2, 23,  0,  0) .. Time.new(2014,  2, 23,  0,  0), # Su (closed)
    Time.new(2014,  2, 24, 11,  0) .. Time.new(2014,  2, 24, 19,  0), # Mo
    Time.new(2014,  2, 25, 11,  0) .. Time.new(2014,  2, 25, 19,  0), # Tu
    Time.new(2014,  2, 26, 11,  0) .. Time.new(2014,  2, 26, 19,  0), # We
    Time.new(2014,  2, 27, 11,  0) .. Time.new(2014,  2, 27, 19,  0), # Th
    Time.new(2014,  2, 28, 11,  0) .. Time.new(2014,  2, 28, 18,  0), # Fr
  ],

  # Mon – Sat 8:00 a.m. to 7 p.m., Sunday Noon to 6 p.m. 
  'V|Wheatsville Food Co-op South Lamar' => [
    Time.new(2014,  2, 18,  8,  0) .. Time.new(2014,  2, 18, 19,  0), # Tu
    Time.new(2014,  2, 19,  8,  0) .. Time.new(2014,  2, 19, 19,  0), # We
    Time.new(2014,  2, 20,  8,  0) .. Time.new(2014,  2, 20, 19,  0), # Th
    Time.new(2014,  2, 21,  8,  0) .. Time.new(2014,  2, 21, 19,  0), # Fr
    Time.new(2014,  2, 22,  8,  0) .. Time.new(2014,  2, 22, 19,  0), # Sa
    Time.new(2014,  2, 23, 12,  0) .. Time.new(2014,  2, 23, 18,  0), # Su
    Time.new(2014,  2, 24,  8,  0) .. Time.new(2014,  2, 24, 19,  0), # Mo
    Time.new(2014,  2, 25,  8,  0) .. Time.new(2014,  2, 25, 19,  0), # Tu
    Time.new(2014,  2, 26,  8,  0) .. Time.new(2014,  2, 26, 19,  0), # We
    Time.new(2014,  2, 27,  8,  0) .. Time.new(2014,  2, 27, 19,  0), # Th
    Time.new(2014,  2, 28,  8,  0) .. Time.new(2014,  2, 28, 19,  0), # Fr
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
loader.load_eday_places("20140304_WEBLoad_P14_FINAL_EDay.csv", ELECTION_DAY_HOURS)
loader.load_evfixed_places("20140304_WEBLoad_P14_FINAL_EVPerm.csv", EARLY_VOTING_FIXED_HOURS)
loader.load_evmobile_places("20140304_WEBLoad_P14_FINAL_EVMobile.csv")
loader.log.info("done")

