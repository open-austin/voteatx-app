require 'findit'
require 'findit/feature/flat-data-set'

module FindIt
  module Feature
    module Travis_CO_TX_US
      
      class VotingPlaceFactory
        def self.create(db, election, options = {})
          klass = Class.new(AbstractVotingPlace)
          klass.instance_variable_set(:@db, db)
          klass.instance_variable_set(:@type, :VOTING_PLACE)
          klass.instance_variable_set(:@marker, FindIt::MapMarker.new(
            "/mapicons/vote_icon.png",
            :height => 32, :width => 32))
          klass.instance_variable_set(:@marker_shadow, FindIt::MapMarker.new(
            "/mapicons/vote_icon_shadow.png",        
            :height => 32, :width => 59))
          klass.set_election(election)
          klass
        end
      end   

      class AbstractVotingPlace < FindIt::BaseFeature    
        
        # class instance variables will be initialized by factory method
        @type = nil
        @marker = nil          
        @marker_shadow = nil
        @db = nil
        @voting_places = nil
                          
        def self.set_election(election)      
          @voting_places = FindIt::Feature::FlatDataSet.load(__FILE__, "voting-places", "Voting_Places_#{election}.csv", :index => :precinct) do |row|

            #
            # Example Row:
            #
            #  <CSV::Row
            #    "precinct":"360"
            #    "name":"Bowie High School"
            #    "street":"4103 West Slaughter Ln"
            #    "city":"Austin"
            #    "state":"TX"
            #    "geo_longitude":"-97.8573487400007"
            #    "geo_latitude":"30.1889148140537"
            #    "geo_accuracy":"house"
            #    "notes":nil>
            #
            
            lng = row["geo_longitude"].to_f
            lat = row["geo_latitude"].to_f
            pct = row["precinct"].to_i  
            note = "precinct #{pct}"
            note += " - #{row["notes"]}" if row["notes"]            
              
            {
              :precinct => pct,
              :name =>  row["name"],
              :street => row["street"],
              :city => row["city"],
              :state => row["state"],
              :note => note,
              :location => FindIt::Location.new(lat, lng, :DEG),
            } 
          end # load_csv_data_set_with_location

        end # self.set_election
                
                
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
            rec = ds.first
          else
            raise "overlapping precincts at location lat=#{lat}, lng=#{lng}"
          end
          
          precinct = rec[:p_vtd].to_i
          rec = @voting_places[precinct] 
          return nil unless rec
                   
          new(rec[:location],
            :title => "Your voting place",
            :name => rec[:name],
            :address => rec[:street],
            :city => rec[:city],
            :state => rec[:state],
            :note => rec[:note],
            :origin => origin
          )
        end        

      end
    end
  end
end