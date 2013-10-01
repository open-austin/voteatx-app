require 'findit-support'

module VoteATX
  module VotingPlace

    class Base

      attr_reader :origin, :location, :type, :title, :name, :address,
        :city, :state, :zip, :link, :note, :is_open, :marker, :region

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
        @link = p.delete(:link) or raise "required VoteATX::VotingPlace attribute \":link\" not specified"
        @note = p.delete(:note) or raise "required VoteATX::VotingPlace attribute \":note\" not specified"
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
          :link => @link,
          :note => @note,
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
        district = db[:travis_co_tx_us_voting_districts] \
          .select(:p_vtd) \
          .select_append{AsGeoJSON(ST_Transform(:geometry, 4326)).as(:region)} \
          .filter{ST_Contains(:geometry, ST_Transform(MakePoint(origin.lng, origin.lat, 4326), 3081))} \
          .fetch_one
        return nil unless district
        precinct = district[:P_VTD].to_i

        # Find the voting place for this precinct.
        place = db[:travis_co_tx_us_voting_eday_places] \
          .select_all(:travis_co_tx_us_voting_eday_places, :travis_co_tx_us_voting_locations) \
          .join(:travis_co_tx_us_voting_locations, :id => :location_id) \
          .filter(:precinct => precinct) \
          .fetch_one
        raise "cannot find election day voting place for precinct \"#{precinct}\"" unless place
        raise "cannot find election day voting location for precinct \"#{precinct}\"" unless place[:geometry]

        sched = db[:travis_co_tx_us_voting_schedules_by_type][:type => place[:schedule_type]]
        raise "cannot locate entry for schedule type \"#{place[:schedule_type]}\"" unless sched

        now = options[:time] || Time.now

        is_open = db[:travis_co_tx_us_voting_schedules_by_type] \
          .filter(:type => place[:schedule_type]) \
          .filter{opens <= now} \
          .filter{closes > now} \
          .count != 0

        new(:origin => origin,
          :location => FindIt::Location.from_geometry(db, place[:geometry]),
          :type => :ELECTION_DAY,
          :title => "Your voting place (precinct #{precinct})",
          :name => place[:name],
          :address => place[:street],
          :city => place[:city],
          :state => place[:state],
          :zip => place[:zip],
          :link => place[:link],
          :note => place[:notes],
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

        fixed = db[:travis_co_tx_us_voting_evfixed_places] \
            .select_all(:travis_co_tx_us_voting_evfixed_places, :travis_co_tx_us_voting_locations) \
            .select_append{ST_Distance(geometry, MakePoint(origin.lng, origin.lat, 4326)).as(:dist)} \
            .join(:travis_co_tx_us_voting_locations, :id => :location_id) \
            .order(:dist.asc) \
            .first

        raise "no fixed early voting places" unless fixed
        raise "cannot find location for early voting place id #{fixed[:id]}" unless fixed[:geometry]

        is_open = db[:travis_co_tx_us_voting_schedules_by_type] \
          .filter(:type => fixed[:schedule_type]) \
          .filter{opens <= now} \
          .filter{closes > now} \
          .count != 0

        ret << new(:origin => origin,
          :location => FindIt::Location.from_geometry(db, fixed[:geometry]),
          :type => :EARLY_VOTING_FIXED,
          :title => "Early voting location",
          :name => fixed[:name],
          :address => fixed[:street],
          :city => fixed[:city],
          :state => fixed[:state],
          :zip => fixed[:zip],
          :link => fixed[:link],
          :note => fixed[:notes],
          :is_open => is_open,
          :marker => place_marker(:EARLY_VOTING_FIXED, is_open))

        mobiles = db[:travis_co_tx_us_voting_evmobile_places] \
          .select_all(:travis_co_tx_us_voting_evmobile_places, :travis_co_tx_us_voting_locations) \
          .select_append{ST_Distance(geometry, MakePoint(origin.lng, origin.lat, 4326)).as(:dist)} \
          .select_append{((opens <= now) & (closes > now)).as(:is_open)} \
          .distinct \
          .join(:travis_co_tx_us_voting_locations, :id => :travis_co_tx_us_voting_evmobile_places__location_id) \
          .join(:travis_co_tx_us_voting_evmobile_schedules, :place_id => :travis_co_tx_us_voting_evmobile_places__id) \
          .filter{dist < fixed[:dist]} \
          .filter{closes > now} \
          .order(:opens.asc, :dist.asc) \
          .limit(3) \
          .all

        mobiles.each do |place|
          is_open = (place[:is_open] == 1)
          ret << new(:origin => origin,
            :location => FindIt::Location.from_geometry(db, p[:geometry]),
            :type => :EARLY_VOTING_MOBILE,
            :title => "Mobile early voting location",
            :name => place[:name],
            :address => place[:street],
            :city => place[:city],
            :state => place[:state],
            :zip => place[:zip],
            :link => place[:link],
            :note => place[:notes],
            :is_open => is_open,
            :marker => place_marker(:EARLY_VOTING_MOBILE, is_open))
        end

        ret
      end

    end

  end # VotingPlace
end # VoteATX

