require 'findit-support'

module VoteATX
  module VotingPlace

    class Base

      attr_reader :origin, :location, :type, :title, :name, :address,
        :city, :state, :zip, :info, :is_open, :marker, :region

      def initialize(params)
        p = params.dup
        @origin = p.delete(:origin) or raise "required VoteATX::VotingPlace attribute \":origin\" not specified"
        @location = p.delete(:location) or raise "required VoteATX::VotingPlace attribute \":location\" not specified"
        @type = p.delete(:type) or raise "required VoteATX::VotingPlace attribute \":type\" not specified"
        @title = p.delete(:title) or raise "required VoteATX::VotingPlace attribute \":title\" not specified"
        @name = p.delete(:name) or raise "required VoteATX::VotingPlace attribute \":name\" not specified"
        @address = p.delete(:address) or raise "required VoteATX::VotingPlace attribute \":address\" not specified"
        @city = p.delete(:city) or raise "required VoteATX::VotingPlace attribute \":city\" not specified"
        @state = p.delete(:state) or raise "required VoteATX::VotingPlace attribute \":state\" not specified"
        @zip = p.delete(:zip) or raise "required VoteATX::VotingPlace attribute \":zip\" not specified"
        @info = p.delete(:info) or raise "required VoteATX::VotingPlace attribute \":info\" not specified"
        @is_open = p.delete(:is_open)
        @marker = p.delete(:marker) or raise "required VoteATX::VotingPlace attribute \":marker\" not specified"
        @region = p.delete(:region)
      end

      def to_h
        h = {
          :latitude => @location.lat,
          :longitude => @location.lng,
          :type => @type,
          :title => @title,
          :name => @name,
          :address => @address,
          :city => @city,
          :state => @state,
          :zip => @zip,
          :info => @info,
          :is_open => @is_open,
          :marker => @marker.marker.to_h,
          :shadow => @marker.shadow.to_h,
        }
        h[:region] = @region.to_h if @region
        h
      end


      def self.place_marker(type, is_open)

        ptype = case type
        when :ELECTION_DAY
          ""
        when :EARLY_VOTING_FIXED
          "_early"
        when :EARLY_VOTING_MOBILE
          "_mobile"
        else
          raise "unknown voting place type \"#{type}\""
        end

        oc = (is_open ? "" : "_closed")

        graphic = "/mapicons/icon_vote#{ptype}#{oc}.png"

        FindIt::Asset::MapMarker.new(graphic, :shadow => "icon_vote_shadow.png")
      end

    end

    class ElectionDay < Base
      def self.search(db, origin, options = {})

        # Find the voting precinct that contains the origin point.
        district = db[:voting_districts] \
          .select(:p_vtd) \
          .select_append{AsGeoJSON(ST_Transform(:geometry, 4326)).as(:region)} \
          .filter{ST_Contains(:geometry, ST_Transform(MakePoint(origin.lng, origin.lat, 4326), 3081))} \
          .first
        return nil unless district
        precinct = district[:P_VTD].to_i

        # Find the voting place for this precinct.
        place = db[:voting_places] \
	  .filter(:place_type => "ELECTION_DAY") \
          .filter(:precinct => precinct) \
          .join(:voting_locations, :id => :location_id) \
	  .join(:voting_schedules, :id => :voting_places__schedule_id) \
	  .join(:voting_schedule_entries, :schedule_id => :id) \
          .first
        raise "cannot find election day voting place for precinct \"#{precinct}\"" unless place
        raise "cannot find election day voting location for precinct \"#{precinct}\"" unless place[:geometry]

        now = options[:time] || Time.now
	is_open = (now >= place[:opens] && now < place[:closes])

        new(:origin => origin,
          :location => FindIt::Location.from_geometry(db, place[:geometry]),
          :type => :ELECTION_DAY,
          :title => "Your voting place (precinct #{precinct})",
          :name => place[:name],
          :address => place[:street],
          :city => place[:city],
          :state => place[:state],
          :zip => place[:zip],
          :info => place[:info],
          :is_open => is_open,
          :marker => place_marker(:ELECTION_DAY, is_open),
          :region => FindIt::Asset::MapRegion.new(district[:region]))
      end  # search

    end # ElectionDay

    class Early < Base


      # Return a list of early voting places for this given location.
      #
      # The list will contain the closest fixed early voting place
      # that is closest to this location, plus zero or more selected
      # mobile early voting locations.
      #
      # The selected mobile early voting locations will all be:
      # 1) closer to the specified location than the nearest fixed
      # early voting location, and 2) has not finally closed for
      # this election.
      #
      def self.search(db, origin, options = {})

        now = options[:time] || Time.now
        ret = []

        fixed = db[:voting_places] \
	    .filter(:place_type => "EARLY_FIXED") \
            .select_all(:voting_places, :voting_locations) \
            .select_append{ST_Distance(geometry, MakePoint(origin.lng, origin.lat, 4326)).as(:dist)} \
	    .join(:voting_locations, :id => :location_id) \
            .order(:dist.asc) \
            .first

        raise "no fixed early voting places" unless fixed
        raise "cannot find location for early voting place id #{fixed[:id]}" unless fixed[:geometry]

        rs = db[:voting_schedule_entries] \
          .filter(:schedule_id => fixed[:schedule_id]) \
          .filter{opens <= now} \
          .filter{closes > now}
	is_open = (rs.count > 0)

        ret << new(:origin => origin,
          :location => FindIt::Location.from_geometry(db, fixed[:geometry]),
          :type => :EARLY_VOTING_FIXED,
          :title => "Early voting location",
          :name => fixed[:name],
          :address => fixed[:street],
          :city => fixed[:city],
          :state => fixed[:state],
          :zip => fixed[:zip],
          :info => fixed[:info],
          :is_open => is_open,
          :marker => place_marker(:EARLY_VOTING_FIXED, is_open))

        mobiles = db[:voting_places] \
	  .filter(:place_type => "EARLY_MOBILE") \
          .select_all(:voting_places, :voting_locations, :voting_schedule_entries) \
          .select_append{ST_Distance(geometry, MakePoint(origin.lng, origin.lat, 4326)).as(:dist)} \
          .join(:voting_locations, :id => :location_id) \
	  .join(:voting_schedules, :id => :voting_places__schedule_id) \
	  .join(:voting_schedule_entries, :schedule_id => :id) \
          .filter{dist < fixed[:dist]} \
          .filter{closes > now} \
          .order(:opens.asc, :dist.asc) \
          .limit(3) \
          .all

        mobiles.each do |place|
	  is_open = (now >= place[:opens])
          ret << new(:origin => origin,
            :location => FindIt::Location.from_geometry(db, p[:geometry]),
            :type => :EARLY_VOTING_MOBILE,
            :title => "Mobile early voting location",
            :name => place[:name],
            :address => place[:street],
            :city => place[:city],
            :state => place[:state],
            :zip => place[:zip],
            :info => place[:info],
            :is_open => is_open,
            :marker => place_marker(:EARLY_VOTING_MOBILE, is_open))
        end

        ret
      end

    end

  end # VotingPlace
end # VoteATX

