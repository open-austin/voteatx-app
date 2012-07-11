require 'findit/location'
require 'findit'

require 'findit/local/austin.ci.tx.us/feature/library'
require 'findit/local/austin.ci.tx.us/feature/post-office'
require 'findit/local/austin.ci.tx.us/feature/moon-tower'
require 'findit/local/austin.ci.tx.us/feature/fire-station'
require 'findit/local/travis.co.tx.us/feature/voting-place'

require 'dbi'

# DBI connection to the PostGIS "findit" database.
DB = DBI.connect("DBI:Pg:host=localhost;database=findit", "findit", "tRdhxlJiREbg")

module FindIt    
  module Austin_CI_TX_US
    
    #
    # Implementation of FindIt::BaseApp for Austin, TX.
    #
    class App < FindIt::BaseApp
      
      # Features beyond this distance (miles) from the current location will
      # be filtered out from the result set.
      MAX_DISTANCE = 12
      
      # See FindIt::BaseApp::nearby
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
  end # module Austin_CI_TX_US
  

  #
  # The class that implements the FindIt application
  # for the selected local implementation.
  #
  # Typically this is defined in the <i>findit/local.rb</i> file.
  #
  # TODO - Write a document that describes how to
  # setup this program for a different locality.
  #
  App = FindIt::Austin_CI_TX_US::App
  
end # module FindIt
