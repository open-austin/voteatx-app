#!/usr/bin/env - ruby
#
# findit-nearby - Find nearby points of interest, proof of concept.
#
# This is very slow because it is querying against Google Fusion Tables. The data
# should be moved local.
#
# Next step would be to convert this to a web service that accepts current lat/long,
# and returns results in a JSON structure.
#

require 'rubygems'
require 'uri'
require 'rest-client'
require 'csv'

class Float
  # convert a value in degrees to radians
  def to_radians
    self * (Math::PI/180.0)
  end
end

class FindIt
  
  attr_reader :current_loc
  
  def initialize(latitude, longitude)
    @current_loc = [latitude.to_f, longitude.to_f]
  end  
  
  EARTH_R = 3963.0 # Earth mean radius, in miles
  
  # Calculate distance (in miles) between two locations (lat/long in degrees)
  # Based on equitorial approximation formula at:
  # http://www.movable-type.co.uk/scripts/latlong.html
  def distance(p1, p2 = current_loc)
    lat1 = p1[0].to_radians
    lon1 = p1[1].to_radians
    lat2 = p2[0].to_radians
    lon2 = p2[1].to_radians
    x = (lon2-lon1) * Math.cos((lat1+lat2)/2);
    y = (lat2-lat1);
    Math.sqrt(x*x + y*y) * EARTH_R;
  end
  
  # Submit a query to a Google Fusion Table which returns CSV text.
  def query_google_fusion_table(table_id, where_clause = '', cols = '*')
    sql = "SELECT #{cols} FROM #{table_id}"
    sql += " WHERE  #{where_clause}" unless where_clause.empty?
    url = "https://www.google.com/fusiontables/api/query?sql=" + URI.escape(sql)
    RestClient.get url
  end
  
  # Some of the CoA datasets have lat/long encoded in an XML blob (ewwww...).
  def parse_geometry(geo)
    if geo.match(%r{<Point><coordinates>(.*),(.*)</coordinates></Point>})
      [$2.to_f, $1.to_f]
    else
      nil
    end
  end
  
  # Find the closest entry in a Google Fusion Table dataset.
  # 
  # Usage: find_closest(response) {|row| extract_latitude_longitude_from_row(row)}
  #
  # Returns: {:location => [LAT,LNG], :distance => MILES, :row => ROW}
  #
  # The "row" is a CSV::Row datatype.
  #
  def find_closest(resp) 
    closest = nil
    CSV.parse(resp, :headers => true) do |row|
      p = yield(row)
      if p
        d = distance(p)
        if closest.nil? || d < closest[:distance]
          closest = {
            :location => p,
            :distance => d,
            :row => row
          }
        end      
      end
    end
    raise "failed to find a location" if closest.nil?
    closest
  end
  
  # Remove excess whitespace, make naive attempt at capitalization.
  def fixup_dirty_string(s)
    s.split.map {|w| w.capitalize}.join(' ')
  end

  def closest_facility(factype)  
    resp = query_google_fusion_table('3046433', "FACILITY='#{factype}'")
    closest = find_closest(resp) do |row|
      parse_geometry(row['geometry'])
    end
    {
      :object_type => factype.downcase.gsub(/\s+/, '_'),
      :name => fixup_dirty_string(closest[:row]['Name']),
      :address => fixup_dirty_string(closest[:row]['ADDRESS']),
      :latitude => closest[:location][0],
      :longitude => closest[:location][1],
      :distance => closest[:distance],
      #:raw_data => closest[:row],
     }
  end
  
  def closest_post_office
    closest_facility("POST OFFICE")
  end
  
  def closest_library
    closest_facility("LIBRARY")
  end
  
  def closest_fire_station
    resp = query_google_fusion_table('2987477')
    closest = find_closest(resp) do |row|
      [row['Latitude'].to_f, row['Longitude'].to_f]
    end
    {
      :object_type => "fire_station",
      :name => nil,
      :address => fixup_dirty_string(closest[:row]['Address']),
      :latitude => closest[:location][0],
      :longitude => closest[:location][1],
      :distance => closest[:distance],
      #:raw_data => closest[:row],
     }
  end

  def closest_moon_tower
    resp = query_google_fusion_table('3046440', "BUILDING_N='MOONLIGHT TOWERS'")
    closest = find_closest(resp) do |row|
      parse_geometry(row['geometry'])
    end
    {
      :object_type => "moon_tower",
      :name => nil,
      :address => fixup_dirty_string(closest[:row]['ADDRESS']),
      :latitude => closest[:location][0],
      :longitude => closest[:location][1],
      :distance => closest[:distance],
      #:raw_data => closest[:row],
     }
  end
  
  # Find collection of nearby objects.
  def nearby
    result = {}
    a = closest_post_office   ; result[a[:object_type]] = a
    a = closest_post_office   ; result[a[:object_type]] = a
    a = closest_library       ; result[a[:object_type]] = a
    a = closest_fire_station  ; result[a[:object_type]] = a
    a =  closest_moon_tower   ; result[a[:object_type]] = a
    result
  end
  
  # Find collection of nearby objects for a given latitude/longitude.
  def self.nearby(lat, lng)
    new(lat, lng).nearby
  end
  
end

