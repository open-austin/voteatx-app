#!/usr/bin/env -- ruby

BASEDIR = File.dirname(__FILE__) + "/../../../../../.."
$:.insert(0, BASEDIR + "/lib")

require 'logger'
require 'csv'
require 'findit'

@log = Logger.new($stderr)
@log.level = Logger::INFO
#@log.level = Logger::DEBUG

DATABASE = BASEDIR + "/findit.sqlite"
@db = FindIt::Database.connect(DATABASE, :spatialite => "/usr/lib/libspatialite.so.3", :log => @log)

INFILE_EDAY="20121106-chipG12_WEBLoad_FINAL_EDay.csv"
INFILE_EVFIXED="20121106-chipG12_WEBLoad_FINAL_EVPerm.csv"
INFILE_EVMOBILE="20121106-chipG12_WEBLoad_FINAL_EVMobile.csv"

ELECTION_DATE = "For the Nov 6, 2012 general election in Travis County."

ALLOW_ANY_VOTING_PLACE_ON_ELECTION_DAY = true
ELECTION_DAY_HOURS = "Tue, Nov 6: 7am - 7pm"

LINK_INFO_BY_TYPE = {
  :EDAY => "http://www.traviscountyclerk.org/eclerk/Content.do?code=E.4",
  :EVFIXED => "http://www.traviscountyclerk.org/eclerk/Content.do?code=E.4",
  :EVMOBILE => "http://www.traviscountyclerk.org/eclerk/Content.do?code=E.4",
}

FIXED_EV_LOCATION_HOURS_BY_CODE = {
  "R" => [
    "Mon, Oct 22 - Sat, Oct 27: 7am - 7pm",
    "Sun, Oct 28: noon - 6pm",
    "Mon, Oct 29 - Fri, Nov 2: 7am - 7pm",
  ],
  "V" => [
    "Mon, Oct 22 - Sat, Oct 27: 7am - 7pm",
    "Sun, Oct 28: noon - 6pm",
    "Mon, Oct 29: - Tue, Oct 30: 7am - 7pm",
    "Wed, Oct 31 - Fri, Nov 2: 7am - 7pm",
  ],
}


RANGE_LNG = Range.new(-98.056777, -97.407671)
RANGE_LAT = Range.new(30.088999, 30.571213)

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

def get_date(row, col)
  ensure_not_empty(row, col)
  m = row[col].match(%r[^(\d\d)/(\d{1,2})/(\d\d\d\d)$])
  raise "bad #{col} value \"#{row[col]}\": #{row}" unless m && m.length-1 == 3
  m.captures.map {|s| s.to_i}
end

def get_time(row, col)
  ensure_not_empty(row, col)
  m = row[col].match(%r[^(\d{1,2}):(\d\d)$])
  raise "bad #{col} value \"#{row[col]}\": #{row}" unless m && m.length-1 == 2
  m.captures.map {|s| s.to_i}
end

def get_datetimes(row)
  mm, dd, yyyy = get_date(row, "Date")
  start_hh, start_mm = get_time(row, "Start Time")
  end_hh, end_mm = get_time(row, "End Time") 
  [Time.local(yyyy, mm, dd, start_hh, start_mm), Time.local(yyyy, mm, dd, end_hh, end_mm)]
end

def init_notes
  ["", ELECTION_DATE].dup
end

@log.info("creating table \"voting_locations\" ...")
@db.create_table :voting_locations do
  primary_key :id
  String :name, :size => 20, :null => false
  String :street, :size => 40, :null => false
  String :city, :size => 20, :null => false
  String :state, :size=> 2, :null => false
  String :zip, :size => 10, :null => false
  Blob :location, :null => false
end  
rc = @db.get{AddGeometryColumn('voting_locations', 'the_geom', 4326, 'POINT', 'XY')}
raise "AddGeometryColumn failed (rc=#{rc})" unless rc == 1
rc = @db.get{CreateSpatialIndex('voting_locations', 'the_geom')}
raise "CreateSpatialIndex failed (rc=#{rc})" unless rc == 1

@log.info("creating table \"voting_eday_places\" ...")
@db.create_table :voting_eday_places do
  primary_key :id
  Integer :precinct, :unique => true, :null => false
  foreign_key :location_id, :voting_locations, :null => false
  String :link, :size => 80, :null => false
  Text :notes
end

@log.info("creating table \"voting_evfixed_places\" ...")
@db.create_table :voting_evfixed_places do
  primary_key :id
  foreign_key :location_id, :voting_locations, :null => false
  String :link, :size => 80, :null => false
  Text :notes
end

@log.info("creating table \"voting_evmobile_places\" ...")
@db.create_table :voting_evmobile_places do
  primary_key :id
  foreign_key :location_id, :voting_locations, :null => false
  String :link, :size => 80, :null => false
  Text :notes
end

@log.info("creating table \"voting_evmobile_schedules\" ...")
@db.create_table :voting_evmobile_schedules do
  primary_key :id
  foreign_key :place_id, :voting_evmobile_places
  DateTime :opens, :null => false, :index => true
  DateTime :closes, :null => false, :index => true
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
  
  rs = @db[:voting_locations].filter("the_geom = MakePoint(#{lng}, #{lat}, 4326)")
  
  rec = {
    :name => name,
    :street => row["Address"],
    :city => row["City"],
    :state => "TX",
    :zip => zip,
    :the_geom => Sequel.function(:MakePoint, lng, lat, 4326),
    :location => Marshal.dump(FindIt::Location.new(lat, lng, :DEG)),
  }
  
  the_geom = @db.get{MakePoint(lng, lat, 4326)}
    
  case rs.count
  when 0
    @log.debug("voting_locations: creating: #{rec}")
    @db[:voting_locations].insert(rec)
  when 1
    curr = rs.first
    [:name, :street, :city, :state, :zip].each do |field|
      if curr[field] != rec[field]
        @log.warn("voting_locations(id #{curr[:id]}): inconsistent \"#{field}\" values [\"#{curr[field]}\", \"#{rec[field]}\"]")
      end
    end
    curr[:id]
  else
    raise "location #{loc} has #{rs.count} records"
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
    notes << "Hours of operation: #{ELECTION_DAY_HOURS}"
    
    unless row["Combined Pcts."].empty?
      a = [precinct] + row["Combined Pcts."].split(",").map {|s| s.to_i}  
      notes << ""
      notes << "Combined precincts " + a.sort.join(", ")
    end
    
    @log.debug("load_eday_places: creating: precinct=#{precinct} location_id=#{location_id}")
    @db[:voting_eday_places] << {
      :precinct => precinct,
      :location_id => location_id,
      :link => LINK_INFO_BY_TYPE[:EDAY],
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
  @log.info("reading input file \"#{INFILE_EVFIXED}\" ...")
  CSV.foreach(INFILE_EVFIXED, :headers => true) do |row|
    
    cleanup_row(row)
        
    location_id = make_location(row)
      
    notes = init_notes 
      
    unless FIXED_EV_LOCATION_HOURS_BY_CODE.has_key?(row["Hours"])
        raise "unknown \"Hours\" code \"#{row['Hours']}\": #{row}"    
    end  
    notes << ""
    notes << "Hours of operation:"
    notes += FIXED_EV_LOCATION_HOURS_BY_CODE[row["Hours"]].map {|s| "\u2022 " + s}
  
    @log.debug("places_early_fixed: creating: location_id=#{location_id}")
    @db[:voting_evfixed_places] << {
      :location_id => location_id,
      :link => LINK_INFO_BY_TYPE[:EVFIXED],
      :notes => notes.join("\n"),
    }
  
  end
end


# format time range like: "* Sun, Oct 28: noon - 6pm"
def format_schedule_line(t1, t2)
  s1 = t1.strftime("%a, %b %-d: %-l:%M%P").sub(/:00([ap]m)/, "\\1").sub(/12am/, 'midnight').sub(/12pm/, 'noon')
  s2 = t2.strftime("%-l:%M%P").sub(/:00([ap]m)/, "\\1").sub(/12am/, 'midnight').sub(/12pm/, 'noon')
  "\u2022 #{s1} - #{s2}"
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
    
    rs = @db[:voting_evmobile_places].filter(:location_id => location_id)
    id = case rs.count
    when 0
      @db[:voting_evmobile_places].insert({
        :location_id => location_id,
        :link => LINK_INFO_BY_TYPE[:EVMOBILE],
      })
    when 1
      rs.first[:id]
    else
      raise "load_evmobile_places: too many records for location_id=\"#{location_id}\""
    end
    
    @db[:voting_evmobile_schedules] << {
      :place_id => id,
      :opens => opens,
      :closes => closes,
    }  
    
  end  
  
  @db[:voting_evmobile_places].each do |place|
    notes = init_notes 
    notes << ""
    notes << "Hours of operation:"    
    @db[:voting_evmobile_schedules].filter(:place_id => place[:id]).order(:opens).each do |hours|
      notes << format_schedule_line(hours[:opens], hours[:closes])
    end
    @db[:voting_evmobile_places].filter(:id => place[:id]).update(:notes => notes.join("\n"))
  end
  
end


load_eday_places(INFILE_EDAY)
load_evfixed_places(INFILE_EVFIXED)
load_evmobile_places(INFILE_EVMOBILE)
@log.info("done")

# vim:autoindent:shiftwidth=2:tabstop=2:expandtab
