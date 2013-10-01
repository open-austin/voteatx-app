require 'logger'
require 'findit-support'

require_relative './voting-place.rb'

module VoteATX

  #
  # Implementation of the VoteATX application.
  #
  # Example usage:
  #
  #    require "findit/app"
  #    findit = VoteATX::App.new
  #    features = findit.nearby(latitude, longitude))
  #
  class App
    
    DATABASE = File.dirname(__FILE__) + "/voteatx.db"
      
    # Features further than this distance (in miles) away from
    # the current location will be filtered out of results.
    #
    # Default value used when constructing a new VoteATX::App instance.
    #
    MAX_DISTANCE = 12    

    # XXX document me
    #
    MAX_PLACES = 3

    # Construct a new VoteATX app instance.
    # Options:
    # * :max_distance
    # * :max_places
    # * :database
    def initialize(options = {})
  
      @log = Logger.new($stderr)
      @log.level = Logger::DEBUG    

      @max_distance = options[:max_distance] || MAX_DISTANCE    
      @max_places = options[:max_places] || MAX_PLACES    
      @database = options[:database] || DATABASE

      @db = Sequel.spatialite(@database)

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
    def search(lat, lng, options = {})
      origin = FindIt::Location.new(lat, lng, :DEG)
      t = options[:time] || Time.now
      ret = []
      a = VoteATX::VotingPlace::ElectionDay.search(@db, origin, :max_distance => @max_distance, :time => t)
      ret << a if a
      ret += VoteATX::VotingPlace::Early.search(@db, origin, :max_distance => @max_distance, :max_places => @max_places, :time => t)
      ret
    end
 
  end # module App
end # module VoteATX
