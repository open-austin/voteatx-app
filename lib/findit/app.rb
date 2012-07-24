require 'findit'
require 'dbi'

# Include all of the local features that we want to support.
require 'findit/feature/austin.ci.tx.us/fire-station'
require 'findit/feature/austin.ci.tx.us/facility'
require 'findit/feature/austin.ci.tx.us/historical'
require 'findit/feature/austin.ci.tx.us/police-station'
require 'findit/feature/travis.co.tx.us/voting-place'


module FindIt

  #
  # Implementation of the FindIt application.
  #
  # Example usage:
  #
  #    require "findit/app"
  #    features = FindIt::App::nearby(latitude, longitude))
  #
  module App
      
    # DBI connection to the PostGIS "findit" database.
    @db = DBI.connect("DBI:Pg:host=localhost;database=findit", "findit", "tRdhxlJiREbg")
    
    # List of classes that implement features (derived from FindIt::BaseFeature).
    @feature_classes = [
      FindIt::Feature::Austin_CI_TX_US::FacilityFactory.create(@db, :POST_OFFICE),
      FindIt::Feature::Austin_CI_TX_US::FacilityFactory.create(@db, :LIBRARY),
      FindIt::Feature::Austin_CI_TX_US::HistoricalFactory.create(@db, :MOON_TOWER),
      FindIt::Feature::Austin_CI_TX_US::FireStation, 
      FindIt::Feature::Austin_CI_TX_US::PoliceStation,
      FindIt::Feature::Travis_CO_TX_US::VotingPlaceFactory.create(@db, "20120512"),
    ]    
  
    # Features beyond this distance (miles) from the current location will
    # be filtered out from the result set.
    MAX_DISTANCE = 12
    
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
      
      @feature_classes.map do |klass|
        # For each class, run the "closest" method to find the
        # closest feature of its type.
        klass.send(:closest, origin)
      end.reject do |feature|
        # Reject results that came back nil or are too far away.
        feature.nil? || feature.distance > MAX_DISTANCE
      end
    end
 
  end # module App
end # module FindIt
