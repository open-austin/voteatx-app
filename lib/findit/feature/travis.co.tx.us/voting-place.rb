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
        @election_date = nil
        @voting_places = nil
                          
        def self.set_election(election)  

          m = election.match(/^(\d\d\d\d)(\d\d)(\d\d)$/)
          raise "cannot parse election date \"#{election}\" into YYYYMMDD" unless m && m.length == 4
          @election_date = Time.mktime(m[1], m[2], m[3])
             
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
                          
            {
              :precinct => row["precinct"].to_i,
              :name =>  row["name"],
              :street => row["street"],
              :city => row["city"],
              :state => row["state"],
              :zip => row["zip"],
              :notes => row["notes"],
              :directions => row["directions"],
              :location => FindIt::Location.new(row["geo_latitude"].to_f, row["geo_longitude"].to_f, :DEG),
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
            rec_pct = ds.first
          else
            raise "overlapping precincts at location lat=#{origin.lat}, lng=#{origin.lng}"
          end
          
          
          precinct = rec_pct[:p_vtd].to_i
          rec_place = @voting_places[precinct] 
          return nil unless rec_place
  
          notes = ["Election date: #{@election_date.strftime('%a, %b %-d, %Y')}"]
          notes << rec_place[:notes] unless rec_place[:notes].empty?
          notes << "Directions: " + rec_place[:directions] unless rec_place[:directions].empty?
          
          new(rec_place[:location],
            :title => "Your voting place (precinct #{precinct})",
            :name => rec_place[:name],
            :address => rec_place[:street],
            :city => rec_place[:city],
            :state => rec_place[:state],
            :zip => rec_place[:zip],
            :note => notes.join("\n"),
            :origin => origin
          )
        end        

      end
    end
  end
end