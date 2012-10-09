require 'findit'

module FindIt
  module Feature
    module Travis_CO_TX_US      

      # Factory class for the application to obtain voting place information.
      #
      # These classes load data from an external file, using the
      # FindIt::Feature::Travis_CO_TX_US::VotingPlaceData class,
      # which must recognize the "election" parameter passed to
      # the factory methods.
      #
      class VotingPlaceFactory
        
        # Construct a concrete instance of FindIt::Feature::Travis_CO_TX_US::AbstractEdayVotingPlace.
        #
        # Parameters:
        # * db -- A DBI handle to the database that has electron district geospatial data.
        # * election -- The election identifier.
        #
        def self.create_eday_voting_place(db, db_old, election)          
          klass = Class.new(AbstractEdayVotingPlace)
          klass.instance_variable_set(:@db, db)
          klass.instance_variable_set(:@db_old, db_old)
          klass.instance_variable_set(:@election, election)
          klass.instance_variable_set(:@type, :VOTING_PLACE)
          klass.instance_variable_set(:@marker, FindIt::Asset::MapMarker.new(
            "/mapicons/vote_icon.png", :shadow => "vote_icon_shadow.png"))
          klass
        end

        # Construct a concrete instance of FindIt::Feature::Travis_CO_TX_US::AbstractEarlyVotingPlace.
        #
        # Parameters:
        # * election -- The election identifier.
        #
        def self.create_early_voting_place(db, election)          
          klass = Class.new(AbstractEarlyVotingPlace)
          klass.instance_variable_set(:@db, db)
          klass.instance_variable_set(:@election, election)
          klass.instance_variable_set(:@type, :EARLY_VOTING_PLACE)
          klass
        end
      
      end  # class VotingPlaceFactory

      
      # Derived class from FindIt::BaseFeature, representing an election day voting place.
      #
      class AbstractEdayVotingPlace < FindIt::BaseFeature    
        
        # class instance variables will be initialized by factory method
        @db = nil
        @db_old = nil
        @election = nil
        @type = nil
        @marker = nil        
                
        # Return the voting place that is closest to the given location.
        #
        def self.closest(origin)
          
          sth = @db_old.execute(%q{SELECT * FROM travis_co_tx_us_voting_districts
            WHERE ST_Contains(the_geom, ST_Transform(ST_SetSRID(ST_Point(?, ?), 4326), 3081))},
            origin.lng, origin.lat)
          ds = sth.fetch_all
          sth.finish          
      
          case ds.count
          when 0
            return nil
          when 1
            rec_pct = ds.first
          else
            raise "overlapping precincts at location lat=#{origin.lat}, lng=#{origin.lng}"
          end          
          
          precinct = rec_pct[:p_vtd]
            
          place = @db[:voting_eday_places] \
            .select_all(:voting_eday_places, :voting_locations) \
            .join(:voting_locations, :id => :location_id) \
            .filter(:precinct => precinct) \
            .fetch_one
          raise "cannot find election day voting place for precinct \"#{precinct}\"" unless place
          raise "cannot find election day voting location for precinct \"#{precinct}\"" unless place[:location]
          
          new(Marshal.load(place[:location]),
            :title => "Your voting place (precinct #{precinct})",
            :name => place[:name],
            :address => place[:street],
            :city => place[:city],
            :state => place[:state],
            :zip => place[:zip],
            :link => place[:link],
            :note => place[:notes],
            :origin => origin
          )
        end        
  
      end # class AbstractEdayVotingPlace
      
      # Derived class from FindIt::BaseFeature, representing early voting places.
      #
      class AbstractEarlyVotingPlace < FindIt::BaseFeature
        
        # class instance variables will be initialized by factory method
        @db = nil
        @election = nil
        
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
        def self.closest(origin)
            
          fixed = @db[:voting_evfixed_places] \
              .select_all(:voting_evfixed_places, :voting_locations) \
              .select_append{ST_Distance(the_geom, MakePoint(origin.lng, origin.lat, 4326)).as(:dist)} \
              .join(:voting_locations, :id => :location_id) \
              .order(:dist.asc) \
              .first
              
          raise "no fixed early voting places" unless fixed
          raise "cannot find location for early voting place id #{fixed[:id]}" unless fixed[:location]         
            
          ret = []
          ret << new(Marshal.load(fixed[:location]),
            :ev_type => :EVFIXED,
            :title => "Early voting location",
            :name => fixed[:name],
            :address => fixed[:street],
            :city => fixed[:city],
            :state => fixed[:state],
            :zip => fixed[:zip],
            :link => fixed[:link],
            :note => fixed[:notes],
            :origin => origin)
              
          mobiles = @db[:voting_evmobile_places] \
            .select_all(:voting_evmobile_places, :voting_locations) \
            .select_append{ST_Distance(the_geom, MakePoint(origin.lng, origin.lat, 4326)).as(:dist)} \
            .select_append{((opens > Time.now) & (closes < Time.now)).as(:open_now)} \
            .distinct \
            .join(:voting_locations, :id => :voting_evmobile_places__location_id) \
            .join(:voting_evmobile_schedules, :place_id => :voting_evmobile_places__id) \
            .filter{dist < fixed[:dist]} \
            .filter{closes > Time.now} \
            .order(:opens.asc, :dist.asc) \
            .limit(3) \
            .all
            
          mobiles.each do |p|  
            ret << new(Marshal.load(p[:location]),
              :ev_type => :EVMOBILE,
              :title => "Mobile early voting location",
              :name => p[:name],
              :address => p[:street],
              :city => p[:city],
              :state => p[:state],
              :zip => p[:zip],
              :link => p[:link],
              :note => p[:notes],
              :open_now => p[:open_now],
              :origin => origin)
          end
                     
          ret           
        end
        
        attr_reader :ev_type
        attr_reader :open_now
        
        def initialize(location, params = {})
          super
          @ev_type = params[:ev_type]
          @open_now = params[:open_now]
        end        

        
        # Select the appropriate marker for this voting place.
        #
        # Chooses between two icons to distinguish between
        # fixed and mobile locations.
        #
        def marker
          case @ev_type
          when :EVFIXED
            icon = "/mapicons/vote_early_icon.png"
          when :EVMOBILE
            icon = "/mapicons/vote_mobile_icon.png"
          else
            raise "unknown EarlyVotingPlace type \"#{@ev_type}\""
          end
          FindIt::Asset::MapMarker.new(icon, :shadow => "vote_icon_shadow.png")
        end
      
      end # class AbstractEarlyVotingPlace

    end # module Travis_CO_TX_US
  end # module Feature
end # module FindIt
