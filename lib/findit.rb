require 'location'

require 'findit/feature/austin.ci.tx.us/library'
require 'findit/feature/austin.ci.tx.us/post-office'
require 'findit/feature/austin.ci.tx.us/moon-tower'
require 'findit/feature/austin.ci.tx.us/fire-station'
require 'findit/feature/travis.co.tx.us/voting-place'

require 'dbi'
DB = DBI.connect("DBI:Pg:host=localhost;database=findit", "findit", "tRdhxlJiREbg")

MAX_DISTANCE = 12

module FindIt  
  
  # Find collection of nearby features for a given latitude/longitude.
  def self.nearby(lat, lng)    
    origin = Location.new(lat, lng, :DEG)        
    features = []      
    features << FindIt::Feature::Austin_CI_TX_US::Library.closest(origin)  
    features << FindIt::Feature::Austin_CI_TX_US::PostOffice.closest(origin)
    features << FindIt::Feature::Austin_CI_TX_US::FireStation.closest(origin)
    features << FindIt::Feature::Austin_CI_TX_US::MoonTower.closest(origin) 
    features << FindIt::Feature::Travis_CO_TX_US::VotingPlace.closest(origin)    
    return features.reject {|f| f.nil? || f.distance > MAX_DISTANCE}
  end
  
end

