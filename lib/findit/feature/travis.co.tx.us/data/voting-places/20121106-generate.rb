#!/usr/bin/env -- ruby

require "csv"

INFILE="20121106-chipG12_WEBLoad_FINAL_EDay.csv"
OUTFILE="Voting_Places_20121106.csv"

RANGE_LNG = Range.new(-98.056777, -97.407671)
RANGE_LAT = Range.new(30.088999, 30.571213)

OUTPUT_FIELDS = %w(precinct name street city state zip geo_longitude geo_latitude geo_accuracy notes)

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
  def cleanup
    nil
  end
end


@places = {}

$stderr.puts("Reading input file \"#{INFILE}\" ...")
CSV.foreach(INFILE, :headers => true) do |row|

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

  row.each {|k,v| row[k] = v.cleanup}

  pct = row["Pct."].to_i
  next if @places[pct]
  precincts = [pct]
  if row["Combined Pcts."]
    precincts += row["Combined Pcts."].split(",").map {|s| s.to_i}
  end

  notes = if precincts.length > 1
    "Combined precincts " + precincts.sort.join(", ")
  else
    ""
  end

  if pct == 0
    next if row["Name"] == "Test Vote Center"
    raise "failed to parse precinct from: #{row}"
  end

  ["Name", "Address", "City", "Zipcode", "Longitude", "Latitude"].each do |k|
    raise "failed to extract \"#{k}\" field from: #{row}" unless row[k]
  end

  lng =  row["Longitude"].to_f
  raise "longitude \"#{lng}\" outside of expected range (#{RANGE_LNG}): #{row}" unless RANGE_LNG.include?(lng)

  lat =  row["Latitude"].to_f
  raise "latitude \"#{lat}\" outside of expected range (#{RANGE_LAT}): #{row}" unless RANGE_LAT.include?(lat)

  zip = row["Zipcode"]
  raise "bad zip value \"#{zip}\": #{row}" unless zip =~ /^78[67]\d\d$/

  precincts.each do |p| 
    raise "nil precinct value in: #{row}" unless p && p > 0
    @places[p] = [
      p,              # :precinct
      row["Name"],    # name
      row["Address"], # :street
      row["City"],    # :city
      "TX",           # :state 
      zip,            # :zip
      lng,            # :geo_longitude
      lat,            # :geo_latitude
      "house",        # :geo_accuracy
      notes,          # :notes
    ]
  end

end
$stderr.puts("#{@places.length} rows loaded.")

$stderr.puts("Writing output file \"#{OUTFILE}\" ...")
CSV.open(OUTFILE, "w") do |csv|
  csv << OUTPUT_FIELDS
  @places.keys.sort.each do |pct|
    csv << @places[pct]
  end
end
$stderr.puts("Done.")

# vim:autoindent:shiftwidth=2:tabstop=2:expandtab
