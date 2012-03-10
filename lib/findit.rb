require 'rubygems'
require 'dbi'

class Coordinate
  
  attr_accessor :latitude_deg, :longitude_deg, :latitude_rad, :longitude_rad
  
  DEG_TO_RAD = Math::PI / 180.0
  
  def initialize(lat, lng, type)
    case type
    when :DEG
      @latitude_deg = lat
      @longitude_deg = lng
      @latitude_rad = lat * DEG_TO_RAD
      @longitude_rad =  lng * DEG_TO_RAD
    when :RAD
      @latitude_rad = lat
      @longitude_rad = lng
      @latitude_deg = lat / DEG_TO_RAD
      @longitude_deg = lng / DEG_TO_RAD
    else
      raise "unknown coordinate type \"#{type}\""
    end      
  end

  EARTH_R = 3963.0 # Earth mean radius, in miles
  
  # Calculate distance (in miles) between two locations (lat/long in radians)
  # Based on equitorial approximation formula at:
  # http://www.movable-type.co.uk/scripts/latlong.html  
  def distance(*args)
    case args.length
    when 1
      p = args[0]
    when 3
      p = Coordinate.new(*args)
    else
      raise "arguments should either be a Coordinate object or (lat,lng,type) values"
    end
    x = (p.longitude_rad-self.longitude_rad) * Math.cos((self.latitude_rad+p.latitude_rad)/2);
    y = (p.latitude_rad-self.latitude_rad);
    Math.sqrt(x*x + y*y) * EARTH_R;
  end  
  
end


class FindIt
  
  DEFAULT_DATABASE = "facilities.db"
  DEFAULT_TABLE = "facilities"
  
  attr_reader :database, :table, :loc, :dbh 
  
  def initialize(lat, lng, opts = {})
    @loc = Coordinate.new(lat, lng, opts[:type] || :DEG)
    @database = opts[:database] || DEFAULT_DATABASE
    @table = opts[:table] || DEFAULT_TABLE
    raise "database file \"#{@database}\" not found" unless File.exist?(@database)
    @dbh = DBI.connect("DBI:SQLite3:#{@database}")
  end
  
  
  def closest_facility(factype, name = nil) 
    
    args = []
      
    sql = "SELECT * FROM #{@table} WHERE type LIKE ?"
    args << factype
    
    if name
      sql += " AND name LIKE ?"
      args << name
    end
    
    closest = nil  
    @dbh.select_all(sql, *args) do |row|
      d = @loc.distance(row['latitude_rad'], row['longitude_rad'], :RAD)
      if closest.nil? || d < closest["distance"]
        closest = row.to_h
        closest["distance"] = d
      end      
    end
    
    closest.delete_if {|k, v| v.nil?} if closest  
    return closest
  end

  
  # Find collection of nearby objects.
  def nearby
    facilities = {}
      
    a = closest_facility("POST_OFFICE")
    facilities[a["type"]] = a if a

    a = closest_facility("LIBRARY")
    facilities[a["type"]] = a if a

    a = closest_facility("FIRE_STATION")
    facilities[a["type"]] = a if a

    a = closest_facility("HISTORICAL_LANDMARK", "Moonlight Towers")
    if a
      a.delete("name")
      facilities["MOON_TOWER"] = a
    end
      
    facilities
  end
  
  # Find collection of nearby objects for a given latitude/longitude.
  def self.nearby(lat, lng)
    new(lat, lng).nearby
  end
  
end

