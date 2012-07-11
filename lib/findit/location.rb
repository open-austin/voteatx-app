module FindIt
  class Location
    
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
    
    def lat
      @latitude_deg
    end
    
    def lng
      @longitude_deg
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
        p = new(*args)
      else
        raise "arguments should either be a Coordinate object or (lat,lng,type) values"
      end
      x = (p.longitude_rad-self.longitude_rad) * Math.cos((self.latitude_rad+p.latitude_rad)/2);
      y = (p.latitude_rad-self.latitude_rad);
      Math.sqrt(x*x + y*y) * EARTH_R;
    end  
    
  end # class Location
end # module FindIt
