require 'findit-support'

require_relative './voting-place.rb'

module VoteATX

  # Implementation of the VoteATX application.
  #
  #    require "voteatx/app"
  #    app = VoteATX::App.new
  #    voting_places = app.search(latitude, longitude))
  #
  class App

    # Default path to the VoteATX database.
    DATABASE = VoteATX::BASEDIR + '/db/voteatx.db'

    # Default max distance (in miles) from current location.
    #
    # Results will include only voting places within this distance.
    #
    MAX_DISTANCE = 12

    # FIXME - this is not properly implemented yet
    #
    MAX_PLACES = 3

    # Construct a new VoteATX app instance.
    #
    # Options:
    # * :database
    # * :max_distance
    # * :max_places
    #
    def initialize(options = {})
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
