#!/usr/bin/env -- ruby

require 'rubygems'
require 'bundler'
Bundler.setup
require 'findit-support'
require 'logger'
require 'csv'
require 'cgi'

LOG_DEBUG = false

FIELD_SITE_NAME = "Name"
FIELD_PCT = "Pct"
FIELD_COMBINED_PCTS = "Combined Pcts."
FIELD_LOCATION_ADDRESS = "Address"
FIELD_LOCATION_CITY = "City"
FIELD_LOCATION_ZIP = "Zipcode"
FIELD_LOCATION_LONGITUDE = "Longitude"
FIELD_LOCATION_LATITUDE = "Latitude"
FIELD_SCHEDULE_CODE = "Hours"
FIELD_SCHEDULE_DATE = "Date"
FIELD_SCHEDULE_TIME_OPENS = "Start Time"
FIELD_SCHEDULE_TIME_CLOSES = "End Time"

RANGE_LNG = Range.new(-98.057163, -97.407671)
RANGE_LAT = Range.new(30.088999, 30.572025)

INFO_FOOTER = [
  "",
  "For the Nov 5, 2013 general election in Travis County.",
  "",
  "<b>Note:</b> For this election, on election day you can vote at your",
  "regular home precinct or <em>any other</em> Travis County polling place.",
  "",
  "<i><a href=\"http://www.traviscountyclerk.org/eclerk/Content.do?code=E.4\">more information ...</a></i>",
]

CONFIG_ELECTION_DAY = {
  :input => "20131105_WEBLoad_G13_FINAL_EDay.csv",
  :hours => [Time.new(2012, 11, 6, 7, 0) ..  Time.new(2012, 11, 6, 19, 0)],
}

CONFIG_EARLY_VOTING_FIXED = {
  :input => "20131105_WEBLoad_G13_FINAL_EVPerm.csv",
  :hours_by_code => {

    'R' => [
      Time.new(2012, 10, 21,  7,  0) .. Time.new(2012, 10, 21, 19,  0), # Mo
      Time.new(2012, 10, 22,  7,  0) .. Time.new(2012, 10, 22, 19,  0), # Tu
      Time.new(2012, 10, 23,  7,  0) .. Time.new(2012, 10, 23, 19,  0), # We
      Time.new(2012, 10, 24,  7,  0) .. Time.new(2012, 10, 24, 19,  0), # Th
      Time.new(2012, 10, 25,  7,  0) .. Time.new(2012, 10, 25, 19,  0), # Fr
      Time.new(2012, 10, 26,  7,  0) .. Time.new(2012, 10, 26, 19,  0), # Sa
      Time.new(2012, 10, 27, 12,  0) .. Time.new(2012, 10, 27, 18,  0), # Su
      Time.new(2012, 10, 28,  7,  0) .. Time.new(2012, 10, 28, 19,  0), # Mo
      Time.new(2012, 10, 29,  7,  0) .. Time.new(2012, 10, 20, 19,  0), # Tu
      Time.new(2012, 10, 30,  7,  0) .. Time.new(2012, 10, 30, 19,  0), # We
      Time.new(2012, 10, 31,  7,  0) .. Time.new(2012, 10, 31, 19,  0), # Th
      Time.new(2012, 11,  1,  7,  0) .. Time.new(2012, 11,  1, 19,  0), # Fr
    ],

    # Mon – Wed 10 am – 5:30 pm, Thu 10 am – 7 pm, Fri 10 am – 4:30 pm, Sat 10 am – 3:30 pm, Sun Closed
    'V1' => [
      Time.new(2012, 10, 21, 10,  0) .. Time.new(2012, 10, 21, 17, 30), # Mo
      Time.new(2012, 10, 22, 10,  0) .. Time.new(2012, 10, 22, 17, 30), # Tu
      Time.new(2012, 10, 23, 10,  0) .. Time.new(2012, 10, 23, 17, 30), # We
      Time.new(2012, 10, 24, 10,  0) .. Time.new(2012, 10, 24, 19,  0), # Th
      Time.new(2012, 10, 25, 10,  0) .. Time.new(2012, 10, 25, 16, 30), # Fr
      Time.new(2012, 10, 26, 10,  0) .. Time.new(2012, 10, 26, 16, 30), # Sa
      # closed Su
      Time.new(2012, 10, 28, 10,  0) .. Time.new(2012, 10, 28, 17, 30), # Mo
      Time.new(2012, 10, 29, 10,  0) .. Time.new(2012, 10, 20, 17, 30), # Tu
      Time.new(2012, 10, 30, 10,  0) .. Time.new(2012, 10, 30, 17, 30), # We
      Time.new(2012, 10, 31, 10,  0) .. Time.new(2012, 10, 31, 19,  0), # Th
      Time.new(2012, 11,  1, 10,  0) .. Time.new(2012, 11,  1, 16, 30), # Fr
    ],

    # Mon – Thu 10 am – 7 pm, Fri Closed, Sat 10 am – 4:30 pm, Sun 2 pm – 5:30 pm
    'V2' => [
      Time.new(2012, 10, 21, 10,  0) .. Time.new(2012, 10, 21, 19,  0), # Mo
      Time.new(2012, 10, 22, 10,  0) .. Time.new(2012, 10, 22, 19,  0), # Tu
      Time.new(2012, 10, 23, 10,  0) .. Time.new(2012, 10, 23, 19,  0), # We
      Time.new(2012, 10, 24, 10,  0) .. Time.new(2012, 10, 24, 19,  0), # Th
      # close Fr
      Time.new(2012, 10, 26, 10,  0) .. Time.new(2012, 10, 26, 16, 30), # Sa
      Time.new(2012, 10, 27, 14,  0) .. Time.new(2012, 10, 27, 17, 30), # Su
      Time.new(2012, 10, 28, 10,  0) .. Time.new(2012, 10, 28, 19,  0), # Mo
      Time.new(2012, 10, 29, 10,  0) .. Time.new(2012, 10, 20, 19,  0), # Tu
      Time.new(2012, 10, 30, 10,  0) .. Time.new(2012, 10, 30, 19,  0), # We
      Time.new(2012, 10, 31, 10,  0) .. Time.new(2012, 10, 31, 19,  0), # Th
      Time.new(2012, 11,  1, 10,  0) .. Time.new(2012, 11,  1, 19,  0), # Fr
    ],

    # Mon – Thu 9 am – 7 pm, Fri 9 am – 6 pm, Sat 9 am – 4 pm, Sun Closed
    'V3' => [
      Time.new(2012, 10, 21,  9,  0) .. Time.new(2012, 10, 21, 19,  0), # Mo
      Time.new(2012, 10, 22,  9,  0) .. Time.new(2012, 10, 22, 19,  0), # Tu
      Time.new(2012, 10, 23,  9,  0) .. Time.new(2012, 10, 23, 19,  0), # We
      Time.new(2012, 10, 24,  9,  0) .. Time.new(2012, 10, 24, 19,  0), # Th
      Time.new(2012, 10, 25,  9,  0) .. Time.new(2012, 10, 25, 18,  0), # Fr
      Time.new(2012, 10, 26,  9,  0) .. Time.new(2012, 10, 26, 16,  0), # Sa
      # closed Su
      Time.new(2012, 10, 28,  9,  0) .. Time.new(2012, 10, 28, 19,  0), # Mo
      Time.new(2012, 10, 29,  9,  0) .. Time.new(2012, 10, 20, 19,  0), # Tu
      Time.new(2012, 10, 30,  9,  0) .. Time.new(2012, 10, 30, 19,  0), # We
      Time.new(2012, 10, 31,  9,  0) .. Time.new(2012, 10, 31, 19,  0), # Th
      Time.new(2012, 11,  1,  9,  0) .. Time.new(2012, 11,  1, 18,  0), # Fr
    ],

    # Mon – Wed 10 am – 7 pm, Thu Closed, Fri 10 am – 5:30 pm, Sat 10 am – 4:30 pm, Sun Closed
    'V4' => [
      Time.new(2012, 10, 21, 10,  0) .. Time.new(2012, 10, 21, 19,  0), # Mo
      Time.new(2012, 10, 22, 10,  0) .. Time.new(2012, 10, 22, 19,  0), # Tu
      Time.new(2012, 10, 23, 10,  0) .. Time.new(2012, 10, 23, 19,  0), # We
      # closed Th
      Time.new(2012, 10, 25, 10,  0) .. Time.new(2012, 10, 25, 17, 30), # Fr
      Time.new(2012, 10, 26, 10,  0) .. Time.new(2012, 10, 26, 16, 30), # Sa
      # closed Su
      Time.new(2012, 10, 28, 10,  0) .. Time.new(2012, 10, 28, 19,  0), # Mo
      Time.new(2012, 10, 29, 10,  0) .. Time.new(2012, 10, 20, 19,  0), # Tu
      Time.new(2012, 10, 30, 10,  0) .. Time.new(2012, 10, 30, 19,  0), # We
      # closed Th
      Time.new(2012, 11,  1, 10,  0) .. Time.new(2012, 11,  1, 19,  0), # Fr
    ],

    # Mon – Thu 11 am – 7 pm, Fri 11 am – 6 pm, Sat 11 am – 5 pm, Sun Closed
    'V5' => [
      Time.new(2012, 10, 21, 11,  0) .. Time.new(2012, 10, 21, 19,  0), # Mo
      Time.new(2012, 10, 22, 11,  0) .. Time.new(2012, 10, 22, 19,  0), # Tu
      Time.new(2012, 10, 23, 11,  0) .. Time.new(2012, 10, 23, 19,  0), # We
      Time.new(2012, 10, 24, 11,  0) .. Time.new(2012, 10, 24, 19,  0), # Th
      Time.new(2012, 10, 25, 11,  0) .. Time.new(2012, 10, 25, 18,  0), # Fr
      Time.new(2012, 10, 26, 11,  0) .. Time.new(2012, 10, 26, 17,  0), # Sa
      # closed Su
      Time.new(2012, 10, 28, 11,  0) .. Time.new(2012, 10, 28, 19,  0), # Mo
      Time.new(2012, 10, 29, 11,  0) .. Time.new(2012, 10, 20, 19,  0), # Tu
      Time.new(2012, 10, 30, 11,  0) .. Time.new(2012, 10, 30, 19,  0), # We
      Time.new(2012, 10, 31, 11,  0) .. Time.new(2012, 10, 31, 19,  0), # Th
      Time.new(2012, 11,  1, 11,  0) .. Time.new(2012, 11,  1, 18,  0), # Fr
    ],

  },
  :schedule_formatted_by_code => {
    'R' => [
      "Hours of operation:",
      "\u2022 Mon, Oct 21 - Sat, Oct 26: 7am - 7pm",
      "\u2022 Sun, Oct 27: noon - 6pm",
      "\u2022 Mon, Oct 28 - Fri, Nov 1: 7am - 7pm",
    ],

    'V1' => [
      "Hours of operation:",
      "\u2022 to be done",
    ],

    'V2' => [
      "Hours of operation:",
      "\u2022 to be done",
    ],

    'V3' => [
      "Hours of operation:",
      "\u2022 to be done",
    ],

    'V4' => [
      "Hours of operation:",
      "\u2022 to be done",
    ],

    'V5' => [
      "Hours of operation:",
      "\u2022 to be done",
    ],

  },
}

CONFIG_EARLY_VOTING_MOBILE = {
  :input => "20131105_WEBLoad_G13_FINAL_EVMobile.csv",
}

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
  def escape_html
    CGI.escape_html(self)
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


class VotingPlaceInfo

  def initialize(title, location, schedule, footer = INFO_FOOTER)
    @title = title
    @location = location
    @schedule = schedule
    @footer = footer
    @middle = []

  end

  def <<(stuff)
    @middle << ""
    case stuff
    when Array
      @middle += stuff
    else
      @middle << stuff
    end
  end

  def to_s
    to_a.join("\n")
  end

  def to_a
    [
      "<b>" + @title.escape_html + "</b>",
      @location[:name].escape_html ,
      @location[:street].escape_html ,
      (@location[:city] + ", " + @location[:state] + " " + @location[:zip]).escape_html ,
      "",
    ] + @schedule + @middle + @footer
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
  mm, dd, yyyy = get_date(row, FIELD_SCHEDULE_DATE)
  start_hh, start_mm = get_time(row, FIELD_SCHEDULE_TIME_OPENS)
  end_hh, end_mm = get_time(row, FIELD_SCHEDULE_TIME_CLOSES)
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
    #String :link, :size => 80, :null => false
    Text :info
  end

end


def make_location(row)
  ensure_not_empty(row, "Name", "Address", "City", "Zipcode", "Longitude", "Latitude")

  name = row[FIELD_SITE_NAME].sub(/^Combined\s+@\s+\d+\s+/, "")

  v = row[FIELD_LOCATION_LONGITUDE]
  raise "required column \"#{"Longitude"}\" not defined: #{row}" if v.empty?
  lng = v.to_f
  raise "longitude \"#{lng}\" outside of expected range (#{RANGE_LNG}): #{row}" unless RANGE_LNG.include?(lng)

  v = row[FIELD_LOCATION_LATITUDE]
  raise "required column \"#{"Latitude"}\" not defined: #{row}" if v.empty?
  lat = v.to_f
  raise "latitude \"#{lat}\" outside of expected range (#{RANGE_LAT}): #{row}" unless RANGE_LAT.include?(lat)

  zip = row[FIELD_LOCATION_ZIP]
  raise "bad zip value \"Zipcode\": #{zip}" unless zip =~ /^78[67]\d\d$/

  loc = @db[:voting_locations] \
    .filter{ST_Equals(:geometry, MakePoint(lng, lat, 4326))} \
    .fetch_one

  rec = {
    :name => name,
    :street => row[FIELD_LOCATION_ADDRESS],
    :city => row[FIELD_LOCATION_CITY],
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
    loc
  else
    @log.debug("voting_locations: creating: #{rec}")
    id = @db[:voting_locations].insert(rec)
    @db[:voting_locations][:id => id]
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


def load_eday_places(config)
  @log.info("reading input file \"#{config[:input]}\" ...")

  # Create schedule record for election day.
  schedule_id = make_schedule(config[:hours])

  # Ensure there is a formatted schedule string for election day.
  schedule_formatted = config[:schedule_formatted] || format_schedule(config[:hours])

  CSV.foreach(config[:input], :headers => true) do |row|

    cleanup_row(row)

    precinct = row[FIELD_PCT].to_i
    raise "failed to parse precinct from: #{row}" if precinct == 0

    location = make_location(row)

    info = VotingPlaceInfo.new("Precinct #{precinct}", location, schedule_formatted)

    unless row[FIELD_COMBINED_PCTS].empty?
      a = [precinct] + row[FIELD_COMBINED_PCTS].split(",").map {|s| s.to_i}
      info << "Combined precincts " + a.sort.join(", ")
    end

    @log.debug("load_eday_places: creating: precinct=#{precinct} location_id=#{location[:id]}")
    @db[:voting_places] << {
      :place_type => "ELECTION_DAY",
      :precinct => precinct,
      :location_id => location[:id],
      :schedule_id => schedule_id,
      :info => info.to_s,
    }

  end
end


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

    schedule_code = row[FIELD_SCHEDULE_CODE]
    unless valid_schedule_code[schedule_code]
      raise "unknown schedule code \"#{schedule_code}\": #{row}"
    end

    location = make_location(row)

    info = VotingPlaceInfo.new("Early Voting Location", location, schedule_formatted_by_code[schedule_code])

    @log.debug("places_early_fixed: creating: location_id=#{location[:id]}")
    @db[:voting_places] << {
      :place_type => "EARLY_FIXED",
      :location_id => location[:id],
      :schedule_id => schedule_id_by_code[schedule_code],
      :info => info.to_s,
    }

  end
end


def load_evmobile_places(config)
  @log.info("reading input file \"#{config[:input]}\" ...")

  CSV.foreach(config[:input], :headers => true) do |row|

    cleanup_row(row)

    location = make_location(row)

    opens, closes = get_datetimes(row)

    place = @db[:voting_places] \
      .filter(:place_type => "EARLY_MOBILE") \
      .filter(:location_id => location[:id]) \
      .limit(1)

    if place.empty?
      schedule_id = make_schedule([opens..closes])
      info = VotingPlaceInfo.new("Mobile Early Voting Location", location, format_schedule([opens..closes]))

      @db[:voting_places] << {
        :place_type => "EARLY_MOBILE",
        :location_id => location[:id],
        :schedule_id => schedule_id,
        :info => info.to_s
      }
    else
      add_schedule_entry(place.get(:schedule_id), opens..closes)
      info = place.get(:info) + "\n" + format_schedule_line(opens..closes)
      place.update(:info => info)
    end

  end

end

create_tables
load_eday_places(CONFIG_ELECTION_DAY)
load_evfixed_places(CONFIG_EARLY_VOTING_FIXED)
load_evmobile_places(CONFIG_EARLY_VOTING_MOBILE)
@log.info("done")

# vim:autoindent:shiftwidth=2:tabstop=2:expandtab
