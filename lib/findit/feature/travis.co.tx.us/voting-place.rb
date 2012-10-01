require 'findit'

module FindIt
  module Feature
    module Travis_CO_TX_US      
      
      #
      # This class manages the voting place dataset, created by
      # a "generate" script. It is used to load the dataset, and
      # then generate the classes that access the data.
      #
      # The dataset is located in the file:
      #
      #   <LIBDIR>/findit/feature/travis.co.tx.us/data/voting-places/Voting_Places_<ELECTION>.dat
      #
      # where <ELECTION> is an identifier for the election, typically
      # in "YYYYMMDD" form.
      #
      # The dataset is stored in Marshal format. It is a hash with four items:
      #
      # * :locations -- A table (Hash) of physical location (address,
      #   latitude/longitued, etc.) for each of the voting places, indexed by id.
      # * :places_eday -- A table (Hash) of voting places on election day,
      #   indexed by precinct number.
      # * :places_evfixed -- A list (Array) of "fixed" early voting locations,
      #   that are available during the early voting period.
      # * :places_evmobile -- A list (Array) of "mobile" early voting locations,
      #   that are available only on specified dates during the early voting period.
      #
      class VotingPlaceData
        
        @@cache = {}
          
        # Load the dataset for a given election into a private (internal) form.
        def load_dataset(election)          
          fn = "Voting_Places_#{election}.dat"
          pn = File.dirname(__FILE__) + "/data/voting-places/" + fn
          places = File.open(pn, "r") do |fp|
            Marshal.load(fp)
          end 
          locations = FindIt::Feature::Travis_CO_TX_US::VotingLocations.new(places)
          {
            :election_day => FindIt::Feature::Travis_CO_TX_US::ElectionDayVotingPlaces.new(places, locations),
            :fixed_early_voting => FindIt::Feature::Travis_CO_TX_US::FixedEarlyVotingPlaces.new(places, locations),
            :mobile_early_voting => FindIt::Feature::Travis_CO_TX_US::MobileEarlyVotingPlaces.new(places, locations),
          }         
        end
        protected :load_dataset
        
        # Load the dataset for a given election.
        #
        # The results of the load are cached internally, so it
        # is inexpensive to call this repeatedly for the same
        # election.
        #
        def initialize(election)
          unless @@cache.has_key?(election)
            @@cache[election] = load_dataset(election)
          end
          @places = @@cache[election]
        end
        
        # Return a FindIt::Feature::Travis_CO_TX_US::ElectionDayVotingPlaces
        # instance for this dataset.
        def election_day_factory 
          @places[:election_day]
        end

        # Return a FindIt::Feature::Travis_CO_TX_US::FixedEarlyVotingPlaces
        # instance for this dataset.
        def fixed_early_voting_factory
          @places[:fixed_early_voting]
        end
        
        # Return a FindIt::Feature::Travis_CO_TX_US::MobileEarlyVotingPlaces
        # instance for this dataset
        def mobile_early_voting_factory
          @places[:mobile_early_voting]
        end
        
      end # class VotingPlaceData    

      
      # Manage physical locations (address, latitude/longitued, etc.) for the voting places.
      #
      # This is obtained from the ":locations" table in the voting place dataset.
      #
      # A location is a hash with the following elements (all required):
      #
      # * :id -> String
      # * :name -> String
      # * :street -> String
      # * :city -> String
      # * :state -> String
      # * :zip -> zip,
      # * :location -> FindIt::Location
      #    
      # Typically, this class is not used by an application, but is
      # used internally by other FindIt::Feature::Travis_CO_TX_US
      # classes.      
      #
      class VotingLocations
        
        # Do not call this constructor directly.
        #   
        # This class is used internally by other FindIt::Feature::Travis_CO_TX_US
        # classes.      
        #        
        def initialize(data)
          raise "dataset missing \":locations\" data" unless data.has_key?(:locations)
          @locations = data[:locations]
        end
        
        # Retrieve a location by its id.
        def get_by_id(id)
          raise "location id not specified" if id.empty?
          raise "location id \"#{id}\" not known" unless @locations.has_key?(id)
          @locations[id]
        end
        
      end # VotingLocations
      
      
      # Manage election day voting places.
      #
      # This is obtained from the ":places_eday" table in the voting place dataset.
      #
      # An election day voting place is a hash with the following elements (all required):
      #
      # * :precinct -> Fixnum
      # * :location_id -> String
      # * :name -> String
      # * :street -> String
      # * :city -> String
      # * :state -> String
      # * :zip -> zip,
      # * :location -> FindIt::Location
      # * :link -> String
      # * :notes -> String
      # 
      class ElectionDayVotingPlaces
        
        # Do not call this constructor directly.
        #
        # Use: FindIt::Feature::Travis_CO_TX_US::VotingPlaceData#election_day_factory
        #
        def initialize(data, locations)
          @places = data[:places_eday]
          raise "dataset missing election day voting places information (places_eday)" unless @places
          @locations = locations
        end
        
        # Obtain election day voting place information for the specified precinct.
        def get_by_precinct(precinct)
          raise "precinct \"#{precinct}\" unknown" unless @places.has_key?(precinct)
          place = @places[precinct]
          loc = @locations.get_by_id(place[:location_id])
          place.merge(loc)
        end
        
      end # ElectionDayVotingPlaces
    
      
      # Manage fixed location eary voting places.
      #
      # This is obtained from the ":places_evfixed" table in the voting place dataset.
      #
      # An election day voting place is a hash with the following elements (all required):
      #
      # * :location_id -> String
      # * :name -> String
      # * :street -> String
      # * :city -> String
      # * :state -> String
      # * :zip -> zip,
      # * :location -> FindIt::Location
      # * :distance -> Float
      # * :link -> String
      # * :notes -> String
      # 
      class FixedEarlyVotingPlaces
        
        # Do not call this constructor directly.
        #
        # Use: FindIt::Feature::Travis_CO_TX_US::VotingPlaceData#fixed_early_voting_factory
        #
        def initialize(data, locations)
          @places = data[:places_evfixed]
          raise "dataset missing ealy voting fixed places information (places_evfixed)" unless @places
          @locations = locations
        end

        # Find the closest fixed early voting place closest to the specified location.
        #
        # Parameters:
        # * origin: A FindIt::Location instance.
        #
        def closest(origin)
          place = nil
          distance = nil
          @places.each do |p|
            loc = @locations.get_by_id(p[:location_id])
            d = origin.distance(loc[:location])
            if place.nil? || d < distance
              place = p.merge(loc).merge(:distance => d)
              distance = d
            end
          end
          place
        end    
         
      end # FixedEarlyVotingPlaces
      
      
      # Manage mobile location eary voting places.
      #
      # This is obtained from the ":places_evmobile" table in the voting place dataset.
      #
      # An election day voting place is a hash with the following elements (all required):
      #
      # * :location_id -> String
      # * :name -> String
      # * :street -> String
      # * :city -> String
      # * :state -> String
      # * :zip -> zip,
      # * :location -> FindIt::Location
      # * :distance -> Float
      # * :final_close -> Date
      # * :link -> String
      # * :notes -> String
      # 
      class MobileEarlyVotingPlaces
        
        # Do not call this constructor directly.
        #
        # Use: FindIt::Feature::Travis_CO_TX_US::VotingPlaceData#mobile_early_voting_factory
        #
        def initialize(data, locations)
          @places = data[:places_evmobile]
          raise "dataset missing ealy voting mobile places information (places_evmobile)" unless @places
          @locations = locations
        end       
        
        # Find mobile early voting places within a specified distance of
        # a specified location.
        #
        # Returns a list of mobile early voting places.
        #
        # Parameters:
        # * origin: A FindIt::Location instance.
        # * distance: Distance (in miles) to limit search.
        #
        # The following options are recognized:
        # * :after -- Reject locations that have closed before
        #   this time. Default is now.
        # * :sort -- Possible values are:
        #   * :asc - Sort results, ascending by distance.
        #   * :desc - Sort results, descending by distance.
        #   * true - Same as :asc
        #   * false - Do not sort results. (the default)
        # * :max -- Maximum number of locations to return,
        #   or "nil" for unlimited (the default).
        #
        def find_within(origin, distance, options = {})
          after = options[:after] || Time.now
          ret = []
            
          @places.each do |p|
            next if p[:final_close] <= after
            loc = @locations.get_by_id(p[:location_id])              
            d = origin.distance(loc[:location])
            next if d > distance
            ret << p.merge(loc).merge(:distance => d)
          end
          
          case options[:sort]
          when true, :asc
            ret = ret.sort {|a,b| a[:distance] <=> b[:distance]}
          when :desc
            ret = ret.sort {|a,b| b[:distance] <=> a[:distance]}
          when false, nil
            # nop
          else
            raise "bad :sort specifier \"#{options[:sort]}\""
          end
          
          case options[:max]
          when Fixnum
            ret = ret.slice(0, options[:max])
          when nil
            # nop
          else
            raise "bad :max specifier \"#{options[:max]}\""
          end
          
          ret
        end
        
         
      end # MobileEarlyVotingPlaces
      
      
      # Factory class for the application to obtain voting place information.
      #
      # These classes load data from an external file, using the
      # FindIt::Feature::Travis_CO_TX_US::VotingPlaceData class,
      # which must recognize the "election" parameter passed to
      # the factory methods.
      #
      class VotingPlaceFactory
        
        # Construct a concrete instance of FindIt::Feature::Travis_CO_TX_US::AbstractVotingPlace.
        #
        # Parameters:
        # * db -- A DBI handle to the database that has electron district geospatial data.
        # * election -- The election identifier.
        #
        def self.create_voting_place(db, election)          
          klass = Class.new(AbstractVotingPlace)
          klass.instance_variable_set(:@db, db)
          places = FindIt::Feature::Travis_CO_TX_US::VotingPlaceData.new(election)
          klass.instance_variable_set(:@places, places.election_day_factory)
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
        def self.create_early_voting_place(election)          
          klass = Class.new(AbstractEarlyVotingPlace)
          places = FindIt::Feature::Travis_CO_TX_US::VotingPlaceData.new(election)
          klass.instance_variable_set(:@places_fixed, places.fixed_early_voting_factory)
          klass.instance_variable_set(:@places_mobile, places.mobile_early_voting_factory)
          klass.instance_variable_set(:@type, :EARLY_VOTING_PLACE)
          klass
        end
      
      end  # class VotingPlaceFactory

      
      # Derived class from FindIt::BaseFeature, representing an election day voting place.
      #
      class AbstractVotingPlace < FindIt::BaseFeature    
        
        # class instance variables will be initialized by factory method
        @db = nil
        @places = nil
        @election_date = nil
        @type = nil
        @marker = nil        
                
        # Return the voting place that is closest to the given location.
        #
        def self.closest(origin)
          
          sth = @db.execute(%q{SELECT * FROM travis_co_tx_us_voting_districts
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
          
          precinct = rec_pct[:p_vtd].to_i
          place = @places.get_by_precinct(precinct)
          
          new(place[:location],
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
  
      end # class AbstractVotingPlace
      
      # Derived class from FindIt::BaseFeature, representing early voting places.
      #
      class AbstractEarlyVotingPlace < FindIt::BaseFeature
        
        # class instance variables will be initialized by factory method
        @places_fixed = nil
        @places_mobile = nil
        @election_date = nil
        
        # either :FIXED or :MOBILE
        attr_accessor :ev_type
        
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
          ret = []
                 
          fixed = @places_fixed.closest(origin)
          ret << new(fixed[:location],
            :ev_type => :FIXED,
            :title => "Early voting location",
            :name => fixed[:name],
            :address => fixed[:street],
            :city => fixed[:city],
            :state => fixed[:state],
            :zip => fixed[:zip],
            :link => fixed[:link],
            :note => fixed[:notes],
            :distance => fixed[:distance])
           
          @places_mobile.find_within(origin, fixed[:distance], :sort => :desc).each do |p|
           ret << new(p[:location],
             :ev_type => :MOBILE,
             :title => "Mobile early voting location",
             :name => p[:name],
             :address => p[:street],
             :city => p[:city],
             :state => p[:state],
             :zip => p[:zip],
             :link => p[:link],
             :note => p[:notes],
             :distance => fixed[:distance])
          end 
           
          ret           
        end
        
        def initialize(location, params = {})
          super
          @ev_type = params[:ev_type]
        end
        
        # Select the appropriate marker for this voting place.
        #
        # Chooses between two icons to distinguish between
        # fixed and mobile locations.
        #
        def marker
          case @ev_type
          when :FIXED
            icon = "/mapicons/vote_early_icon.png"
          when :MOBILE
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
