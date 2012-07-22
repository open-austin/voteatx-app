require 'findit'
require 'dbi'

# Include all of the local features that we want to support.
require 'findit/local/austin.ci.tx.us/feature/fire-station'
require 'findit/local/austin.ci.tx.us/feature/library'
require 'findit/local/austin.ci.tx.us/feature/moon-tower'
require 'findit/local/austin.ci.tx.us/feature/police-station'
require 'findit/local/austin.ci.tx.us/feature/post-office'
require 'findit/local/travis.co.tx.us/feature/voting-place'


module FindIt
    
  # DBI connection to the PostGIS "findit" database.
  DB = DBI.connect("DBI:Pg:host=localhost;database=findit", "findit", "tRdhxlJiREbg")
  
  # List of classes that implement FindIt::BaseFeature.
  FEATURE_CLASSES = [
    FindIt::Feature::Austin_CI_TX_US::FireStation,
    FindIt::Feature::Austin_CI_TX_US::Library,
    FindIt::Feature::Austin_CI_TX_US::MoonTower, 
    FindIt::Feature::Austin_CI_TX_US::PoliceStation,
    FindIt::Feature::Austin_CI_TX_US::PostOffice,
    FindIt::Feature::Travis_CO_TX_US::VotingPlace,
  ]    

  # Features beyond this distance (miles) from the current location will
  # be filtered out from the result set.
  MAX_DISTANCE = 12
  

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
      
      FEATURE_CLASSES.map do |klass|
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
