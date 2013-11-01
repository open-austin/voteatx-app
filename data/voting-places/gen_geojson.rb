#!/usr/bin/env -- ruby
#
# Dump voting locations in VoteATX database to GeoJSON format.
#
# This was written to generate dataset for this project:
# https://github.com/spara/texas_voting
#

require 'rubygems'
require 'bundler'
Bundler.setup
require "#{Bundler.root}/lib/voteatx.rb"
require "logger"

DEBUG = true

@log = Logger.new($stderr)
@log.level = DEBUG ? Logger::DEBUG : Logger::INFO 

@database = ENV['APP_DATABASE'] || "#{Bundler.root}/voteatx.db"
@log.info "connecting to database: #{@database}"

@db = Sequel.spatialite(@database)
@db.logger = @log
@db.sql_log_level = :debug

rs = @db[:voting_places] \
	.select_append(:voting_locations__formatted.as(:location_formatted)) \
	.select_append(:voting_schedules__formatted.as(:schedule_formatted)) \
	.select_append{ST_X(:voting_locations__geometry).as(:longitude)} \
	.select_append{ST_Y(:voting_locations__geometry).as(:latitude)} \
	.exclude(:place_type => "ELECTION_DAY") \
	.join(:voting_locations, :id => :location_id) \
	.join(:voting_schedules, :id => :voting_places__schedule_id)

features = []
rs.each do |a|
	features << {
		"type" => "Feature",
		"geometry" => {
			"type" => "Point",
			"coordinates" => [a[:longitude], a[:latitude]],
		},
		"properties" => {
			#"Type" => a[:place_type],	# "EARLY_MOBILE"
			"Type" => a[:title],		# "Mobile Early Voting Location"
			"Name" => a[:name],		# "Westminster Manor"
			"Street" => a[:street],		# "4100 Jackson Avenue"
			"City" => a[:city],		# "Austin"
			"State" => a[:state],		# "TX"
			"Zip" => a[:zip],		# "78731"
			"Formatted" => a[:location_formatted], #  "Westminster Manor\n ...."
			"Schedule" => a[:schedule_formatted], # "Fri, Nov 1: 5pm - 7pm"
			"Notes" => a[:notes],		# nil
		},
	}
end

puts({"type" => "FeatureCollection", "features" => features}.to_json)
@log.info "generated #{features.length} records"
