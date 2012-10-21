require 'logger'
require 'findit'
require 'findit/database'

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
  #    findit = FindIt::App.new
  #    features = findit.nearby(latitude, longitude))
  #
  class App
    
    DATABASE = File.dirname(__FILE__) + "/feature/data/findit.sqlite"
    LIBSPATIALITE = "/usr/lib/libspatialite.so.3"
      
    # Features further than this distance (in miles) away from
    # the current location will be filtered out of results.
    #
    # Default value used when constructing a new FindIt::App instance.
    #
    MAX_DISTANCE = 12    

    # Construct a new FindIt app instance.
    #
    # Options:
    # * :db_uri - DBI URI for the FindIt database. (default: DB_URI)
    # * :db_user - Username credential to access the FindIt database.
    #   (default: DB_USER)
    # * :db_password - Password credential to access the FindIt database.
    #   (default: DB_PASSWORD)
    # * :max_distance -  Features further than this distance (in miles)
    #   away from the current location will be filtered out of results.
    #   (default: MAX_DISTANCE)
    #    
    def initialize(options = {})
  
      @log = Logger.new($stderr)
      @log.level = Logger::DEBUG    

      @max_distance = options[:max_distance] || MAX_DISTANCE    
      @database = options[:database] || DATABASE
      @libspatialite = options[:libspatialite]  || LIBSPATIALITE
      
      @db = FindIt::Database.connect(@database, :spatialite => @libspatialite, :log => @log)
      
      # List of classes that implement features (derived from FindIt::BaseFeature).
      @feature_classes = [
        ### FindIt::Feature::Austin_CI_TX_US::FacilityFactory.create(@db_pg, :POST_OFFICE),
        ### FindIt::Feature::Austin_CI_TX_US::FacilityFactory.create(@db_pg, :LIBRARY),
        ### FindIt::Feature::Austin_CI_TX_US::HistoricalFactory.create(@db_pg, :MOON_TOWER),
        ### FindIt::Feature::Austin_CI_TX_US::FireStation, 
        ### FindIt::Feature::Austin_CI_TX_US::PoliceStation,
        FindIt::Feature::Travis_CO_TX_US::VotingPlaceFactory.create_eday_voting_place(@db, "20121106"),
        FindIt::Feature::Travis_CO_TX_US::VotingPlaceFactory.create_early_voting_place(@db, "20121106"),
      ]  
      
    end
    
    
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
    def nearby(lat, lng)
      origin = FindIt::Location.new(lat, lng, :DEG)
      
      @feature_classes.map do |klass|
        # For each class, run the "closest" method to find the
        # closest feature of its type.
        klass.send(:closest, origin)
      end.flatten.reject do |feature|
        # Reject results that came back nil or are too far away.
        feature.nil? || feature.distance > MAX_DISTANCE
      end
    end
 
  end # module App
end # module FindIt
