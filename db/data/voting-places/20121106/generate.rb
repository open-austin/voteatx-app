#!/usr/bin/env -- ruby
  
require 'rubygems'
require 'bundler'
Bundler.setup
require 'findit-support'
require 'logger'
require 'csv'

DATABASE = "voteatx.db"

INFILE = {
  :EDAY => "20121106_WEBLoad_FINAL_EDay.csv",
  :EVFIXED => "20121106_WEBLoad_FINAL_EVPerm.csv",
  :EVMOBILE => "20121106_WEBLoad_FINAL_EVMobile.csv",
}

ELECTION_DESCRIPTION = "For the Nov 6, 2012 general election in Travis County."

ALLOW_ANY_VOTING_PLACE_ON_ELECTION_DAY = true
ELECTION_DAY_OPENS = Time.new(2012, 11, 6, 7, 0)
ELECTION_DAY_CLOSES = Time.new(2012, 11, 6, 19, 0)
ELECTION_DAY_SCHEDULE_TYPE = "E"

EVFIXED_SCHEDULE = {
  "R" => [    
    "Mon, Oct 22 - Sat, Oct 27: 7am - 7pm",
    "Sun, Oct 28: noon - 6pm",
    "Mon, Oct 29 - Fri, Nov 2: 7am - 7pm",
  ],
  "V" => [
    "Mon, Oct 22 - Sat, Oct 27: 7am - 7pm",
    "Sun, Oct 28: noon - 6pm",
    "Mon, Oct 29 - Tue, Oct 30: 7am - 7pm",
    "Wed, Oct 31 - Fri, Nov 2: 7am - 9pm",
  ],
}

INFO_LINK = {
  :EDAY => "http://www.traviscountyclerk.org/eclerk/Content.do?code=E.4",
  :EVFIXED => "http://www.traviscountyclerk.org/eclerk/Content.do?code=E.4",
  :EVMOBILE => "http://www.traviscountyclerk.org/eclerk/Content.do?code=E.4",
}

RANGE_LNG = Range.new(-98.056777, -97.407671)
RANGE_LAT = Range.new(30.088999, 30.571213)

@log = Logger.new($stderr)
@log.level = Logger::INFO
#@log.level = Logger::DEBUG

@db = Sequel.spatialite(DATABASE)

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

# Format time range like: "* Sun, Oct 28: noon - 6pm"
def time_range(t1, t2)
  s1 = t1.strftime("%a, %b %-d: %-l:%M%P").sub(/:00([ap]m)/, "\\1").sub(/12am/, 'midnight').sub(/12pm/, 'noon')
  s2 = t2.strftime("%-l:%M%P").sub(/:00([ap]m)/, "\\1").sub(/12am/, 'midnight').sub(/12pm/, 'noon')
  "#{s1} - #{s2}"
end

# Initialize a list of strings that will be used to create the "notes" field.
def init_notes
  ["", ELECTION_DESCRIPTION].dup
end


def create_tables
  
  @log.info("creating table \"travis_co_tx_us_voting_locations\" ...")
  @db.create_table :travis_co_tx_us_voting_locations do
    primary_key :id
    String :name, :size => 20, :null => false
    String :street, :size => 40, :null => false
    String :city, :size => 20, :null => false
    String :state, :size=> 2, :null => false
    String :zip, :size => 10, :null => false
  end  
  rc = @db.get{AddGeometryColumn('travis_co_tx_us_voting_locations', 'geometry', 4326, 'POINT', 'XY')}
  raise "AddGeometryColumn failed (rc=#{rc})" unless rc == 1
  rc = @db.get{CreateSpatialIndex('travis_co_tx_us_voting_locations', 'geometry')}
  raise "CreateSpatialIndex failed (rc=#{rc})" unless rc == 1
  
  @log.info("creating table \"travis_co_tx_us_voting_eday_places\" ...")
  @db.create_table :travis_co_tx_us_voting_eday_places do
    primary_key :id
    Integer :precinct, :unique => true, :null => false
    foreign_key :location_id, :travis_co_tx_us_voting_locations, :null => false
    String :schedule_type, :size => 1, :null => false
    String :link, :size => 80, :null => false
    Text :notes
  end
  
  @log.info("creating table \"travis_co_tx_us_voting_evfixed_places\" ...")
  @db.create_table :travis_co_tx_us_voting_evfixed_places do
    primary_key :id
    foreign_key :location_id, :travis_co_tx_us_voting_locations, :null => false
    String :schedule_type, :size => 1, :null => false
    String :link, :size => 80, :null => false
    Text :notes
  end

  @log.info("creating table \"travis_co_tx_us_voting_schedules_by_type\" ...")
  @db.create_table :travis_co_tx_us_voting_schedules_by_type do
    primary_key :id
    String :type, :size => 1, :null => false, :index => true
    DateTime :opens, :null => false, :index => true
    DateTime :closes, :null => false, :index => true
  end
  
  add_sched = proc do |type, year, mon, day, hour_opens, min_opens, hour_closes,  min_closes|  
    @db[:travis_co_tx_us_voting_schedules_by_type] <<  {
      :type => type,
      :opens => Time.new(year, mon, day, hour_opens, min_opens),
      :closes => Time.new(year, mon, day, hour_closes, min_closes)
    }
  end
  
  # election day
  add_sched.call(ELECTION_DAY_SCHEDULE_TYPE,
                      2012, 11,  6,  7, 0, 19, 0)  

  # early voting place type "R"
  add_sched.call("R", 2012, 10, 22,  7, 0, 19, 0)
  add_sched.call("R", 2012, 10, 23,  7, 0, 19, 0)
  add_sched.call("R", 2012, 10, 24,  7, 0, 19, 0)
  add_sched.call("R", 2012, 10, 25,  7, 0, 19, 0)
  add_sched.call("R", 2012, 10, 26,  7, 0, 19, 0)
  add_sched.call("R", 2012, 10, 27,  7, 0, 19, 0)
  add_sched.call("R", 2012, 10, 28, 12, 0, 18, 0)
  add_sched.call("R", 2012, 10, 29,  7, 0, 19, 0)
  add_sched.call("R", 2012, 10, 30,  7, 0, 19, 0)
  add_sched.call("R", 2012, 10, 31,  7, 0, 19, 0)
  add_sched.call("R", 2012, 11,  1,  7, 0, 19, 0)
  add_sched.call("R", 2012, 11,  2,  7, 0, 19, 0)

  # early voting place type "R"
  add_sched.call("V", 2012, 10, 22,  7, 0, 19, 0)
  add_sched.call("V", 2012, 10, 23,  7, 0, 19, 0)
  add_sched.call("V", 2012, 10, 24,  7, 0, 19, 0)
  add_sched.call("V", 2012, 10, 25,  7, 0, 19, 0)
  add_sched.call("V", 2012, 10, 26,  7, 0, 19, 0)
  add_sched.call("V", 2012, 10, 27,  7, 0, 19, 0)
  add_sched.call("V", 2012, 10, 28, 12, 0, 18, 0)
  add_sched.call("V", 2012, 10, 29,  7, 0, 19, 0)
  add_sched.call("V", 2012, 10, 30,  7, 0, 19, 0)
  add_sched.call("V", 2012, 10, 31,  7, 0, 21, 0)
  add_sched.call("V", 2012, 11,  1,  7, 0, 21, 0)
  add_sched.call("V", 2012, 11,  2,  7, 0, 21, 0)

  @log.info("creating table \"travis_co_tx_us_voting_evmobile_places\" ...")
  @db.create_table :travis_co_tx_us_voting_evmobile_places do
    primary_key :id
    foreign_key :location_id, :travis_co_tx_us_voting_locations, :null => false
    String :link, :size => 80, :null => false
    Text :notes
  end
  
  @log.info("creating table \"travis_co_tx_us_voting_evmobile_schedules\" ...")
  @db.create_table :travis_co_tx_us_voting_evmobile_schedules do
    primary_key :id
    foreign_key :place_id, :travis_co_tx_us_voting_evmobile_places
    DateTime :opens, :null => false, :index => true
    DateTime :closes, :null => false, :index => true
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
  
  loc = @db[:travis_co_tx_us_voting_locations] \
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
    @db[:travis_co_tx_us_voting_locations].insert(rec)
  end  
  
end


# Process CSV containing day-of-election voting places.
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
def load_eday_places(fname)
  @log.info("reading input file \"#{fname}\" ...")
  CSV.foreach(fname, :headers => true) do |row|  
    
    cleanup_row(row)
    
    precinct = row["Pct."].to_i
    raise "failed to parse precinct from: #{row}" if precinct == 0
    
    location_id = make_location(row)  
  
    notes = init_notes
    
    if ALLOW_ANY_VOTING_PLACE_ON_ELECTION_DAY  
      notes << ""
      notes << "NOTE: For this election, you can vote at your regular home precinct"
      notes << "or ANY OTHER Travis County polling place."
    end
  
    notes << ""
    notes << "Hours of operation: " + time_range(ELECTION_DAY_OPENS, ELECTION_DAY_CLOSES)
    
    unless row["Combined Pcts."].empty?
      a = [precinct] + row["Combined Pcts."].split(",").map {|s| s.to_i}  
      notes << ""
      notes << "Combined precincts " + a.sort.join(", ")
    end
    
    @log.debug("load_eday_places: creating: precinct=#{precinct} location_id=#{location_id}")
    @db[:travis_co_tx_us_voting_eday_places] << {
      :precinct => precinct,
      :location_id => location_id,
      :schedule_type => ELECTION_DAY_SCHEDULE_TYPE,
      :link => INFO_LINK[:EDAY],
      :notes => notes.join("\n"),
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
def load_evfixed_places(fname)
  @log.info("reading input file \"#{fname}\" ...")
  CSV.foreach(fname, :headers => true) do |row|
    
    cleanup_row(row)
        
    location_id = make_location(row)
      
    notes = init_notes 
      
    unless EVFIXED_SCHEDULE.has_key?(row["Hours"])
        raise "unknown \"Hours\" code \"#{row['Hours']}\": #{row}"    
    end  
    notes << ""
    notes << "Hours of operation:"
    notes += EVFIXED_SCHEDULE[row["Hours"]].map {|s| "\u2022 " + s}
  
    @log.debug("places_early_fixed: creating: location_id=#{location_id}")
    @db[:travis_co_tx_us_voting_evfixed_places] << {
      :location_id => location_id,
      :schedule_type => row["Hours"],
      :link => INFO_LINK[:EVFIXED],
      :notes => notes.join("\n"),
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
def load_evmobile_places(fname)
  @log.info("reading input file \"#{fname}\" ...")
  places_evmobile_ungrouped = []
  CSV.foreach(fname, :headers => true) do |row|  
  
    cleanup_row(row)
    row["Address"] = row["Site Address"]    

    location_id = make_location(row)
        
    opens, closes = get_datetimes(row)
    
    place = @db[:travis_co_tx_us_voting_evmobile_places] \
      .filter(:location_id => location_id) \
      .fetch_one
      
    id = if place
      place[:id]
    else
      @db[:travis_co_tx_us_voting_evmobile_places].insert({
        :location_id => location_id,
        :link => INFO_LINK[:EVMOBILE],
      })
    end
    
    @db[:travis_co_tx_us_voting_evmobile_schedules] << {
      :place_id => id,
      :opens => opens,
      :closes => closes,
    }  
    
  end  
  
  @db[:travis_co_tx_us_voting_evmobile_places].each do |place|
    notes = init_notes 
    notes << ""
    notes << "Hours of operation:"    
    @db[:travis_co_tx_us_voting_evmobile_schedules].filter(:place_id => place[:id]).order(:opens).each do |hours|
      notes << "\u2022 " + time_range(hours[:opens], hours[:closes])
    end
    @db[:travis_co_tx_us_voting_evmobile_places].filter(:id => place[:id]).update(:notes => notes.join("\n"))
  end
  
end

create_tables
load_eday_places(INFILE[:EDAY])
load_evfixed_places(INFILE[:EVFIXED])
load_evmobile_places(INFILE[:EVMOBILE])
@log.info("done")

# vim:autoindent:shiftwidth=2:tabstop=2:expandtab
