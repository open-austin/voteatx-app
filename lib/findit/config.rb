
# Include all of the local features that we want to support.
require 'findit/local/austin.ci.tx.us/feature/library'
require 'findit/local/austin.ci.tx.us/feature/post-office'
require 'findit/local/austin.ci.tx.us/feature/moon-tower'
require 'findit/local/austin.ci.tx.us/feature/fire-station'
require 'findit/local/travis.co.tx.us/feature/voting-place'

require 'dbi'

module FindIt

  # DBI connection to the PostGIS "findit" database.
  DB = DBI.connect("DBI:Pg:host=localhost;database=findit", "findit", "tRdhxlJiREbg")
  
  # List of classes that implement FindIt::BaseFeature.
  FEATURE_CLASSES = [
    FindIt::Feature::Austin_CI_TX_US::Library,
    FindIt::Feature::Austin_CI_TX_US::PostOffice,
    FindIt::Feature::Austin_CI_TX_US::FireStation,
    FindIt::Feature::Austin_CI_TX_US::MoonTower, 
    FindIt::Feature::Travis_CO_TX_US::VotingPlace,
  ]

  # Features beyond this distance (miles) from the current location will
  # be filtered out from the result set.
  MAX_DISTANCE = 12
  
end
