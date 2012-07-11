require 'findit/base-feature'
require 'findit/location'

module FindIt
  module Feature
    module Austin_CI_TX_US
      
      #
      # The City of Austin "facilities" GIS dataset contains multiple features
      # of interest. This base class contains the database handling functions.
      # The derived classes contain the code for the specific feature.
      #
      class BaseFacility < FindIt::BaseFeature
        
        def self.facility_title    
          raise "abstract method \"self.facility_title\" must be overriden"
        end   
        
        def self.facility_type
          raise "abstract method \"self.facility_type\" must be overriden"
        end    
        
        def self.closest(origin)

          sth = DB.execute(%q{SELECT *,
            ST_X(ST_Transform(the_geom, 4326)) AS longitude,
            ST_Y(ST_Transform(the_geom, 4326)) AS latitude,
            ST_Distance(ST_Transform(the_geom, 4326), ST_SetSRID(ST_Point(?, ?), 4326)) AS distance
            FROM austin_ci_tx_us_facilities
            WHERE facility = ?
            ORDER BY distance ASC
            LIMIT 1
          }, origin.lng, origin.lat, self.facility_type)
          rec = sth.fetch
          sth.finish

          return nil unless rec  
          
          new(FindIt::Location.new(rec[:latitude], rec[:longitude], :DEG),
            :title => self.facility_title,
            :name => rec[:name].capitalize_words,
            :address => rec[:address].capitalize_words,
            :city => "Austin",
            :state => "TX",
            :origin => origin
          )
          
        end # self.closest
        
      end # class BaseFacility      
    end # module Austin_CI_TX_US
  end # module Feature    
end # module FindIt

