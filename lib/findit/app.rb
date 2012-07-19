require 'findit'
require 'findit/config'

module FindIt

  #
  # Implementation of the FindIt application.
  #
  # Example usage:
  #
  #    require "findit/app"
  #    features = FindIt::App::nearby(latitude, longitude))
  #
  class App
    
    # Search for features near a given location.
    #
    # Parameters:
    #
    # * lat -- the latitude (degrees) of the location, as a Float.
    #
    # * lng -- the longitude (degrees) of the location, as a Float.
    #
    # Returns: A list of FindIt::BaseFeature instances.
    #
    def self.nearby(lat, lng)
      origin = FindIt::Location.new(lat, lng, :DEG) 
      
      FindIt::FEATURE_CLASSES.map do |klass|
        # For each class, run the "closest" method to find the
        # closest feature of its type.
        klass.send(:closest, origin)
      end.reject do |feature|
        # Reject results that came back nil or are too far away.
        feature.nil? || feature.distance > MAX_DISTANCE
      end
    end
 
  end # class App
end # module FindIt
