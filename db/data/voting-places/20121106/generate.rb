#!/usr/bin/env -- ruby

require 'rubygems'
require 'bundler'
Bundler.setup
require 'findit-support'
require 'logger'
require 'csv'

LOG_DEBUG = false

DESCRIPTION = "For the Nov 6, 2012 general election in Travis County."
ELECTION_DAY_VOTING_PLACES = true
INFO_LINK = "http://www.traviscountyclerk.org/eclerk/Content.do?code=E.4"

CONFIG_ELECTION_DAY = {
  :input => "20121106_WEBLoad_FINAL_EDay.csv",
  :hours => [Time.new(2012, 11, 6, 7, 0) ..  Time.new(2012, 11, 6, 19, 0)],
}

CONFIG_EARLY_VOTING_FIXED = {
  :input => "20121106_WEBLoad_FINAL_EVPerm.csv",
  :hours_by_code => {
    'R' => [
      Time.new(2012, 10, 22,  7, 0) .. Time.new(2012, 10, 22, 19, 0),
      Time.new(2012, 10, 23,  7, 0) .. Time.new(2012, 10, 23, 19, 0),
      Time.new(2012, 10, 24,  7, 0) .. Time.new(2012, 10, 24, 19, 0),
      Time.new(2012, 10, 25,  7, 0) .. Time.new(2012, 10, 25, 19, 0),
      Time.new(2012, 10, 26,  7, 0) .. Time.new(2012, 10, 26, 19, 0),
      Time.new(2012, 10, 27,  7, 0) .. Time.new(2012, 10, 27, 19, 0),
      Time.new(2012, 10, 28, 12, 0) .. Time.new(2012, 10, 28, 18, 0),
      Time.new(2012, 10, 29,  7, 0) .. Time.new(2012, 10, 20, 19, 0),
      Time.new(2012, 10, 30,  7, 0) .. Time.new(2012, 10, 30, 19, 0),
      Time.new(2012, 10, 31,  7, 0) .. Time.new(2012, 10, 31, 19, 0),
      Time.new(2012, 11,  1,  7, 0) .. Time.new(2012, 11,  1, 19, 0),
      Time.new(2012, 11,  2,  7, 0) .. Time.new(2012, 11,  2, 19, 0),
    ],
    'V' => [
      Time.new(2012, 10, 22,  7, 0) .. Time.new(2012, 10, 22, 19, 0),
      Time.new(2012, 10, 23,  7, 0) .. Time.new(2012, 10, 23, 19, 0),
      Time.new(2012, 10, 24,  7, 0) .. Time.new(2012, 10, 24, 19, 0),
      Time.new(2012, 10, 25,  7, 0) .. Time.new(2012, 10, 25, 19, 0),
      Time.new(2012, 10, 26,  7, 0) .. Time.new(2012, 10, 26, 19, 0),
      Time.new(2012, 10, 27,  7, 0) .. Time.new(2012, 10, 27, 19, 0),
      Time.new(2012, 10, 28, 12, 0) .. Time.new(2012, 10, 28, 18, 0),
      Time.new(2012, 10, 29,  7, 0) .. Time.new(2012, 10, 29, 19, 0),
      Time.new(2012, 10, 30,  7, 0) .. Time.new(2012, 10, 30, 19, 0),
      Time.new(2012, 10, 31,  7, 0) .. Time.new(2012, 10, 31, 21, 0),
      Time.new(2012, 11,  1,  7, 0) .. Time.new(2012, 11,  1, 21, 0),
      Time.new(2012, 11,  2,  7, 0) .. Time.new(2012, 11,  2, 21, 0),
    ],
  },
  :schedule_formatted_by_code => {
    'R' => [
      "Hours of operation:",
      "\u2022 Mon, Oct 22 - Sat, Oct 27: 7am - 7pm",
      "\u2022 Sun, Oct 28: noon - 6pm",
      "\u2022 Mon, Oct 29 - Fri, Nov 2: 7am - 7pm",
    ],
    'V' => [
      "Hours of operation:",
      "\u2022 Mon, Oct 22 - Sat, Oct 27: 7am - 7pm",
      "\u2022 Sun, Oct 28: noon - 6pm",
      "\u2022 Mon, Oct 29 - Tue, Oct 30: 7am - 7pm",
      "\u2022 Wed, Oct 31 - Fri, Nov 2: 7am - 9pm",
    ],
  },
}

CONFIG_EARLY_VOTING_MOBILE = {
  :input => "20121106_WEBLoad_FINAL_EVMobile.csv",
}

RANGE_LNG = Range.new(-98.056777, -97.407671)
RANGE_LAT = Range.new(30.088999, 30.571213)

@log = Logger.new($stderr)
@log.level = (LOG_DEBUG ? Logger::DEBUG : Logger::INFO)

raise "usage: #{$0} database" unless ARGV.length == 1
@database = ARGV.first
raise "file \"#{@database}\" not found" unless File.exist?(@database)

@db = Sequel.spatialite(@database)
@db.logger = @log
@db.sql_log_level = :debug

############################################################################
#
# no user servicable parts below
#

class String
  def cleanup
    strip
  end
end

class Array
  def cleanup
    map {|s| s.cleanup}
  end
end

class NilClass
  def empty?
    true
  end
  def cleanup
    nil
  end
end

class Notes

  def initialize
    @notes = ["", DESCRIPTION]
  end

  def <<(stuff)
    @notes << ""
    case stuff
    when Array
      @notes += stuff
    else
      @notes << stuff
    end
  end

  def to_s
    @notes.join("\n")
  end

end


def cleanup_row(row)
  row.each {|k,v| row[k] = v.cleanup}
end

def ensure_not_empty(row, *cols)
  cols.each do |col|
    raise "required column \"#{col}\" not defined: #{row}" if row[col].empty?
  end
end

# Extract date as [mm,dd,yyyy] from specified col in form "MM/DD/YYYY"
def get_date(row, col)
  ensure_not_empty(row, col)
  m = row[col].match(%r[^(\d\d)/(\d{1,2})/(\d\d\d\d)$])
  raise "bad #{col} value \"#{row[col]}\": #{row}" unless m && m.length-1 == 3
  m.captures.map {|s| s.to_i}
end

# Extract time as [hh,mm] from specified col "HH:MM"
def get_time(row, col)
  ensure_not_empty(row, col)
  m = row[col].match(%r[^(\d{1,2}):(\d\d)$])
  raise "bad #{col} value \"#{row[col]}\": #{row}" unless m && m.length-1 == 2
  m.captures.map {|s| s.to_i}
end

# Extract [start_time, end_time] from info in database record
def get_datetimes(row)
  mm, dd, yyyy = get_date(row, "Date")
  start_hh, start_mm = get_time(row, "Start Time")
  end_hh, end_mm = get_time(row, "End Time")
  [Time.local(yyyy, mm, dd, start_hh, start_mm), Time.local(yyyy, mm, dd, end_hh, end_mm)]
end

def format_start_time(t)
  t.strftime("%a, %b %-d: %-l:%M%P").sub(/:00([ap]m)/, "\\1").sub(/12am/, 'midnight').sub(/12pm/, 'noon')
end

def format_end_time(t)
    t.strftime("%-l:%M%P").sub(/:00([ap]m)/, "\\1").sub(/12am/, 'midnight').sub(/12pm/, 'noon')
end

def format_schedule_line(h, leader = "\u2022 ", separator = " - ")
    leader + format_start_time(h.first) + separator + format_end_time(h.last)
end

def format_schedule(hours, title = "Hours of operation:")
  [title] + hours.map {|h| format_schedule_line(h)}
end


def create_tables

  @log.info("creating table \"voting_locations\" ...")
  @db.create_table :voting_locations do
    primary_key :id
    String :name, :size => 20, :null => false
    String :street, :size => 40, :null => false
    String :city, :size => 20, :null => false
    String :state, :size=> 2, :null => false
    String :zip, :size => 10, :null => false
  end
  rc = @db.get{AddGeometryColumn('voting_locations', 'geometry', 4326, 'POINT', 'XY')}
  raise "AddGeometryColumn failed (rc=#{rc})" unless rc == 1
  rc = @db.get{CreateSpatialIndex('voting_locations', 'geometry')}
  raise "CreateSpatialIndex failed (rc=#{rc})" unless rc == 1

  @log.info("creating table \"voting_schedules\" ...")
  @db.create_table :voting_schedules do
    primary_key :id
  end

  @log.info("creating table \"voting_schedule_entries\" ...")
  @db.create_table :voting_schedule_entries do
    primary_key :id
    foreign_key :schedule_id, :voting_schedules, :null => false
    DateTime :opens, :null => false, :index => true
    DateTime :closes, :null => false, :index => true
  end

  @log.info("creating table \"voting_places\" ...")
  @db.create_table :voting_places do
    primary_key :id
    String :place_type, :size => 16, :null => false
    Integer :precinct, :unique => true, :null => true
    foreign_key :location_id, :voting_locations, :null => false
    foreign_key :schedule_id, :voting_schedules, :null => false
    String :link, :size => 80, :null => false
    Text :notes
  end

end


def make_location(row)
  ensure_not_empty(row, "Name", "Address", "City", "Zipcode", "Longitude", "Latitude")

  name = row["Name"].sub(/^Combined\s+@\s+\d+\s+/, "")

  zip = row["Zipcode"]
  raise "bad zip value \"Zipcode\": #{zip}" unless zip =~ /^78[67]\d\d$/

  v = row["Longitude"]
  raise "required column \"#{"Longitude"}\" not defined: #{row}" if v.empty?
  lng = v.to_f
  raise "longitude \"#{lng}\" outside of expected range (#{RANGE_LNG}): #{row}" unless RANGE_LNG.include?(lng)

  v = row["Latitude"]
  raise "required column \"#{"Latitude"}\" not defined: #{row}" if v.empty?
  lat = v.to_f
  raise "latitude \"#{lat}\" outside of expected range (#{RANGE_LAT}): #{row}" unless RANGE_LAT.include?(lat)

  loc = @db[:voting_locations] \
    .filter{ST_Equals(:geometry, MakePoint(lng, lat, 4326))} \
    .fetch_one

  rec = {
    :name => name,
    :street => row["Address"],
    :city => row["City"],
    :state => "TX",
    :zip => zip,
    :geometry => Sequel.function(:MakePoint, lng, lat, 4326),
  }

  if loc
    [:name, :street, :city, :state, :zip].each do |field|
      if loc[field] != rec[field]
        @log.warn("voting_locations(id #{loc[:id]}): inconsistent \"#{field}\" values [\"#{loc[field]}\", \"#{rec[field]}\"]")
      end
    end
    loc[:id]
  else
    @log.debug("voting_locations: creating: #{rec}")
    @db[:voting_locations].insert(rec)
  end

end


def make_schedule(hours)
  id = @db[:voting_schedules].insert({})
  hours.each {|e| add_schedule_entry(id, e)}
  id
end

def add_schedule_entry(id, hours_entry)
  @db[:voting_schedule_entries] << {
    :schedule_id => id,
    :opens => hours_entry.first,
    :closes => hours_entry.last,
  }
  id
end


#
# Example record:
#   <CSV::Row
#     "Pct.":"416"
#     "Name":"Akins High School"
#     "Combined Pcts.":"411"  (note: may be nil, or comma separated list)
#     "Address":"10701 South 1st Street "
#     "City":"Austin"
#     "Date":"11/6/2012"
#     "Start Time":"7:00"
#     "End Time":"19:00"
#     "Zipcode":"78748"
#     "Latitude":"30.149237"
#     "Longitude":"-97.800872"
#     "Area of the City":"S"
#     "Type":"ED"
#     "Hours":"R"
#     "Election Code":"G12">
def load_eday_places(config)
  @log.info("reading input file \"#{config[:input]}\" ...")

  # Create schedule record for election day.
  schedule_id = make_schedule(config[:hours])

  # Ensure there is a formatted schedule string for election day.
  schedule_formatted = config[:schedule_formatted] || format_schedule(config[:hours])

  CSV.foreach(config[:input], :headers => true) do |row|

    cleanup_row(row)

    precinct = row["Pct."].to_i
    raise "failed to parse precinct from: #{row}" if precinct == 0

    location_id = make_location(row)

    notes = Notes.new

    if ELECTION_DAY_VOTING_PLACES
      notes << [
        "NOTE: For this election, you can vote at your regular home precinct",
        "or ANY OTHER Travis County polling place.",
      ]
    end

    notes << schedule_formatted

    unless row["Combined Pcts."].empty?
      a = [precinct] + row["Combined Pcts."].split(",").map {|s| s.to_i}
      notes << "Combined precincts " + a.sort.join(", ")
    end

    @log.debug("load_eday_places: creating: precinct=#{precinct} location_id=#{location_id}")
    @db[:voting_places] << {
      :place_type => "ELECTION_DAY",
      :precinct => precinct,
      :location_id => location_id,
      :schedule_id => schedule_id,
      :link => INFO_LINK,
      :notes => notes.to_s,
    }

  end
end


# Process CSV containing fixed-location early voting places.
#
# Example record:
#   <CSV::Row
#     "Name":"Ben Hur Shriners Hall"
#     "Address":"7811 Rockwood Lane "
#     "City":"Austin"
#     "Zipcode":"78757"
#     "Latitude":"30.358129"
#     "Longitude":"-97.738055"
#     "Area of the City":"NC"
#     "Type":"EV"
#     "Hours":"R"
#     "Election Code":"G12">
def load_evfixed_places(config)
  @log.info("reading input file \"#{config[:input]}\" ...")

  # Create schedule records and formatted displays for early voting schedules.
  valid_schedule_code = {}
  schedule_id_by_code = {}
  schedule_formatted_by_code = config[:schedule_formatted_by_code] || {}
  config[:hours_by_code].each do |code, hours|
    valid_schedule_code[code] = true
    schedule_id_by_code[code] = make_schedule(hours)
    schedule_formatted_by_code[code] ||= format_schedule(hours)
  end

  CSV.foreach(config[:input], :headers => true) do |row|

    cleanup_row(row)

    schedule_code = row["Hours"]
    unless valid_schedule_code[schedule_code]
      raise "unknown schedule code \"#{schedule_code}\": #{row}"
    end

    location_id = make_location(row)

    notes = Notes.new
    notes << schedule_formatted_by_code[schedule_code]

    @log.debug("places_early_fixed: creating: location_id=#{location_id}")
    @db[:voting_places] << {
      :place_type => "EARLY_FIXED",
      :location_id => location_id,
      :schedule_id => schedule_id_by_code[schedule_code],
      :link => INFO_LINK,
      :notes => notes.to_s,
    }

  end
end


# Process CSV containing varying location early voting places.
#
# Example record:
#   <CSV::Row
#    "Name":"ACC Rio Grande Campus"
#    "Site Address":"1212 Rio Grande Street"
#    "City":"Austin"
#    "Date":"10/22/2012"
#    "Zipcode":"78701"
#    "Start Time":"8:00"
#    "End Time":"19:00"
#    "Latitude":"30.27648"
#    "Longitude":"-97.7471"
#    "Area of the City":"C"
#    "Type":"EM"
#    "Hours":"V"
#    "Election Code":"G12">
def load_evmobile_places(config)
  @log.info("reading input file \"#{config[:input]}\" ...")

  CSV.foreach(config[:input], :headers => true) do |row|

    cleanup_row(row)
    row["Address"] = row["Site Address"]

    location_id = make_location(row)

    opens, closes = get_datetimes(row)

    place = @db[:voting_places] \
      .filter(:place_type => "EARLY_MOBILE") \
      .filter(:location_id => location_id) \
      .limit(1)

    if place.empty?
      schedule_id = make_schedule([opens..closes])
      notes = Notes.new
      notes << format_schedule([opens..closes])

      @db[:voting_places] << {
        :place_type => "EARLY_MOBILE",
        :location_id => location_id,
        :schedule_id => schedule_id,
        :link => INFO_LINK,
        :notes => notes.to_s
      }
    else
      add_schedule_entry(place.get(:schedule_id), opens..closes)
      notes = place.get(:notes) + "\n" + format_schedule_line(opens..closes)
      place.update(:notes => notes)
    end

  end

end

create_tables
load_eday_places(CONFIG_ELECTION_DAY)
load_evfixed_places(CONFIG_EARLY_VOTING_FIXED)
load_evmobile_places(CONFIG_EARLY_VOTING_MOBILE)
@log.info("done")

# vim:autoindent:shiftwidth=2:tabstop=2:expandtab
