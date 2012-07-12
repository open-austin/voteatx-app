require 'findit'

# Include all of the local features that we want to support.
require 'findit/local/austin.ci.tx.us/feature/library'
require 'findit/local/austin.ci.tx.us/feature/post-office'
require 'findit/local/austin.ci.tx.us/feature/moon-tower'
require 'findit/local/austin.ci.tx.us/feature/fire-station'
require 'findit/local/travis.co.tx.us/feature/voting-place'

require 'dbi'

# DBI connection to the PostGIS "findit" database.
DB = DBI.connect("DBI:Pg:host=localhost;database=findit", "findit", "tRdhxlJiREbg")

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
             
      features = []      
      features << FindIt::Feature::Austin_CI_TX_US::Library.closest(origin)  
      features << FindIt::Feature::Austin_CI_TX_US::PostOffice.closest(origin)
      features << FindIt::Feature::Austin_CI_TX_US::FireStation.closest(origin)
      features << FindIt::Feature::Austin_CI_TX_US::MoonTower.closest(origin) 
      features << FindIt::Feature::Travis_CO_TX_US::VotingPlace.closest(origin)  
        
      return features.reject {|f| f.nil? || f.distance > MAX_DISTANCE}
    end
 
  end # class App
end # module FindIt
