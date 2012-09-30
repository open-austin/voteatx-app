#!/usr/bin/env -- ruby

require "csv"
require "../../../../location.rb"

INFILE_EDAY="20121106-chipG12_WEBLoad_FINAL_EDay.csv"
INFILE_EVFIXED="20121106-chipG12_WEBLoad_FINAL_EVPerm.csv"
INFILE_EVMOBILE="20121106-chipG12_WEBLoad_FINAL_EVMobile.csv"
OUTFILE="Voting_Places_20121106.dat"

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
    

raise "Will not overwrite existing file \"#{OUTFILE}\"" if File.exist?(OUTFILE)

@locations = {}
def make_location(row)  
  ensure_not_empty(row, "Name", "Address", "City", "Zipcode", "Longitude", "Latitude")

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

  id = "#{lat},#{lng}"
  if ! @locations.has_key?(id) || @locations[id][:name] =~ /^combined/i
    @locations[id] = {
      :id => id,
      :name => row["Name"],
      :street => row["Address"],
      :city => row["City"],
      :state => "TX",
      :zip => zip,
      :location => FindIt::Location.new(lat, lng, :DEG),
    }
  end  
  
  id
end

@places_eday = {}
$stderr.puts("Reading input file \"#{INFILE_EDAY}\" ...")
CSV.foreach(INFILE_EDAY, :headers => true) do |row|

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
  
  cleanup_row(row)
  
  pct = row["Pct."].to_i
  if pct == 0
    next if row["Name"] == "Test Vote Center"
    raise "failed to parse precinct from: #{row}"
  end
  
  next if @places_eday[pct]
  
  precincts = [pct]
  if row["Combined Pcts."]
    precincts += row["Combined Pcts."].split(",").map {|s| s.to_i}
  end
  
  location_id = make_location(row)  

  notes = init_notes
  
  if ALLOW_ANY_VOTING_PLACE_ON_ELECTION_DAY  
    notes << ""
    notes << "NOTE: For this election, you can vote at your regular home precinct"
    notes << "or ANY OTHER Travis County polling place."
  end

  notes << ""
  notes << "Hours of operation: #{ELECTION_DAY_HOURS}"
    
  if precincts.length > 1
    notes << ""
    notes << "Combined precincts " + precincts.sort.join(", ")
  end

  precincts.each do |p| 
    raise "nil precinct value in: #{row}" unless p && p > 0
    @places_eday[p] = {
      :precinct => p,
      :location_id => location_id,
      :link => LINK_INFO_BY_TYPE[:EDAY],
      :notes => notes.join("\n"),
    }
  end

end

@places_evfixed = []
$stderr.puts("Reading input file \"#{INFILE_EVFIXED}\" ...")
CSV.foreach(INFILE_EVFIXED, :headers => true) do |row|

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

  cleanup_row(row)
  
  next if row["Name"] =~ /^Mobile\s/ && row["Address"] == ""
    
  notes = init_notes 
    
  unless FIXED_EV_LOCATION_HOURS_BY_CODE.has_key?(row["Hours"])
      raise "unknown \"Hours\" code \"#{row['Hours']}\": #{row}"    
  end  
  notes << ""
  notes << "Hours of operation:"
  notes += FIXED_EV_LOCATION_HOURS_BY_CODE[row["Hours"]].map {|s| "\u2022 " + s}

  @places_evfixed << {
    :location_id => make_location(row),
    :link => LINK_INFO_BY_TYPE[:EVFIXED],
    :notes => notes.join("\n"),
  }
  
end

places_evmobile_ungrouped = []
$stderr.puts("Reading input file \"#{INFILE_EVMOBILE}\" ...")
CSV.foreach(INFILE_EVMOBILE, :headers => true) do |row|

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

  cleanup_row(row)
  row["Address"] = row["Site Address"]

  notes = init_notes 
      
  datetime_open, datetime_close = get_datetimes(row)
  
  places_evmobile_ungrouped << {
    :location_id => make_location(row),
    :datetime_open => datetime_open,
    :datetime_close => datetime_close,
    :link => LINK_INFO_BY_TYPE[:EVMOBILE],
    :notes => notes.join("\n"),
  }
  
end

# group mobile locations that are the same location at different times
places_evmobile_by_location_id = {}
places_evmobile_ungrouped.each do |p|
  id = p[:location_id]
  places_evmobile_by_location_id[id] ||= []
  places_evmobile_by_location_id[id] << p 
end

@places_evmobile = []
places_evmobile_by_location_id.each do |id, places|
  
  places_sorted = places.sort {|a,b| a[:datetime_close] <=> b[:datetime_close]}
  
  notes = [places.first[:notes]]
  
  notes << ""
  notes << "Hours of operation:"
  places_sorted.each do |p|
    # "Mon, Oct 22: 7am - 7pm",
    t1 = p[:datetime_open].strftime("%a, %b %d: %l:%M%P").gsub(/\s+/, ' ').sub(/:00([ap]m)/, "\\1")
    t2 = p[:datetime_close].strftime("%l:%M%P").gsub(/\s+/, ' ').sub(/:00([ap]m)/, "\\1")
    notes << "\u2022 #{t1} - #{t2}"
  end
    
  @places_evmobile << {
    :location_id => id,
    :final_close => places_sorted.last[:datetime_close],
    :link => LINK_INFO_BY_TYPE[:EVMOBILE],
    :notes => notes.join("\n"),
  }  
end


$stderr.puts("Dumping data to \"#{OUTFILE}\"...")
File.open(OUTFILE, "w") do |out|
  out.write Marshal.dump({
    :locations => @locations,
    :places_eday => @places_eday,
    :places_evfixed => @places_evfixed,
    :places_evmobile => @places_evmobile,
  })
end


$stderr.puts("Done.")

# vim:autoindent:shiftwidth=2:tabstop=2:expandtab
