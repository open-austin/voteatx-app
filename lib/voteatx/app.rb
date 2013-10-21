require 'findit-support'

require_relative './voting-place.rb'

module VoteATX

  # Default path to the VoteATX database.
  DATABASE = "db/voteatx.db"

  # Default maxmum distance (miles) of early voting places to consider.
  MAX_DISTANCE = 12

  # Default maximum number of early voting places to display.
  MAX_PLACES = 4

  # Implementation of the VoteATX application.
  #
  #    require "voteatx/app"
  #    app = VoteATX::App.new
  #    voting_places = app.search(latitude, longitude))
  #
  class App

    # Construct a new VoteATX app instance.
    #
    # Options:
    # * :database
    # * :max_distance
    # * :max_places
    #
    def initialize(options = {})
      @search_opts = {}
      @search__opts[:max_places] = options[:max_places] unless options[:max_places].empty?
      @search__opts[:max_distance] = options[:max_distance] unless options[:max_distance].empty?
      @db = Sequel.spatialite(options[:database] || DATABASE)
      @db.logger = options[:log] if options.has_key?(:log)
      @db.sql_log_level = :debug
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

      search_opts = @search_opts.dup
      unless options[:time].empty?
        begin
	  search_opts[:time] = Time.parse(options[:time])
	rescue ArgumentError
	  # ignore
	end
      end

      places = []
      a = VoteATX::VotingPlace::ElectionDay.search(@db, origin, search_opts)
      places << a if a
      places += VoteATX::VotingPlace::Early.search(@db, origin, search_opts)
      return places
    end

  end # module App
end # module VoteATX
